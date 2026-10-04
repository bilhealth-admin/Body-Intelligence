import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/catalog_pack.dart';
import 'catalog_file_safety.dart';

typedef CatalogSupportRootResolver = Future<Directory> Function();

class CatalogPackManager {
  CatalogPackManager({
    CatalogSupportRootResolver? rootResolver,
    String? manifestUrlOverride,
    this.allowLoopbackHttpForTesting = false,
    this.transferTimeout = const Duration(minutes: 2),
  }) : _rootResolver = rootResolver ?? getApplicationSupportDirectory,
       _manifestUrl = manifestUrlOverride ?? manifestUrl;

  final CatalogSupportRootResolver _rootResolver;
  final String _manifestUrl;
  @visibleForTesting
  final bool allowLoopbackHttpForTesting;
  final Duration transferTimeout;
  static final _rootMutations = <String, Future<void>>{};
  static const maximumManifestBytes = 1024 * 1024;
  static const productionManifestUrl =
      'https://tgmanzhqulksykhslrzb.supabase.co/storage/v1/object/public/'
      'catalogs/manifest.json';
  static const manifestUrl = String.fromEnvironment(
    'BIL_CATALOG_MANIFEST_URL',
    defaultValue: productionManifestUrl,
  );

  bool get downloadsConfigured => _manifestUrl.trim().isNotEmpty;

  Future<List<CatalogPack>> fetchAvailable() async {
    if (!downloadsConfigured) return const [];
    final json = await _getJson(Uri.parse(_manifestUrl));
    final rawPacks = json['packs'];
    if (rawPacks is! List || rawPacks.length > 200) {
      throw const FormatException('Invalid packs list');
    }
    return rawPacks
        .map((value) {
          if (value is! Map<String, dynamic>) {
            throw const FormatException('Invalid pack entry');
          }
          return CatalogPack.fromJson(value);
        })
        .toList(growable: false);
  }

  Future<List<InstalledCatalogPack>> installed() async {
    final root = await _rootResolver();
    if (!await root.exists()) return const [];
    final File registry;
    try {
      registry = await safeCatalogFile(root, ['catalog_packs.json']);
    } on StateError {
      return const [];
    }
    if (!await registry.exists() ||
        await registry.length() > maximumManifestBytes) {
      return const [];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(await registry.readAsString());
    } on FormatException {
      return const [];
    }
    if (decoded is! Map<String, dynamic> || decoded['packs'] is! List) {
      return const [];
    }
    final entries = decoded['packs'] as List;
    if (entries.length > 200) return const [];
    final packs = <InstalledCatalogPack>[];
    for (final entry in entries) {
      // Invalid optional-pack metadata cannot escape the app root or disable core.
      if (entry is! Map<String, dynamic>) continue;
      try {
        final file = await _packFile(
          root,
          entry['id'] as String,
          entry['version'] as String,
        );
        if (p.normalize(p.absolute(entry['path'] as String)) != file.path) {
          continue;
        }
        final size = entry['size_bytes'] as int;
        if (size <= 0 ||
            size > CatalogPack.maximumInstalledBytes ||
            !await file.exists()) {
          continue;
        }
        packs.add(
          InstalledCatalogPack(
            id: entry['id'] as String,
            version: entry['version'] as String,
            path: file.path,
            sizeBytes: size,
            installedAt: DateTime.parse(entry['installed_at'] as String),
          ),
        );
      } on Object {
        // Preserve untrusted entries on disk; never read or delete their paths.
      }
    }
    return packs;
  }

  Future<T> _mutate<T>(Future<T> Function(Directory root) action) async {
    final root = await _rootResolver();
    final key = p.normalize(p.absolute(root.path));
    final previous = _rootMutations[key] ?? Future<void>.value();
    final result = previous.then((_) => action(root));
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _rootMutations[key] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_rootMutations[key], tail)) _rootMutations.remove(key);
      }),
    );
    return result;
  }

  Future<InstalledCatalogPack> install(CatalogPack pack) =>
      _mutate((root) => _install(pack, root));

  Future<InstalledCatalogPack> _install(
    CatalogPack pack,
    Directory root,
  ) async {
    pack.validate(allowLoopbackHttp: allowLoopbackHttpForTesting);
    final destination = await _packFile(
      root,
      pack.id,
      pack.version,
      createParents: true,
    );
    final temporary = await _packFile(
      root,
      pack.id,
      pack.version,
      suffix: '.download',
    );
    final expanded = await _packFile(
      root,
      pack.id,
      pack.version,
      suffix: '.installing',
    );
    try {
      await _download(pack.downloadUri, temporary, pack.sizeBytes);
      await _verify(temporary, pack.sizeBytes, pack.sha256);
      File ready = temporary;
      if (pack.compression == 'gzip') {
        await _writeBounded(
          gzip.decoder.bind(temporary.openRead()),
          expanded,
          pack.installedSizeBytes!,
        );
        await _verify(expanded, pack.installedSizeBytes!, pack.databaseSha256!);
        ready = expanded;
      }
      await replaceCatalogFile(ready, destination);
      final installedPack = InstalledCatalogPack(
        id: pack.id,
        version: pack.version,
        path: destination.path,
        sizeBytes: await destination.length(),
        installedAt: DateTime.now().toUtc(),
      );
      final packs =
          (await installed()).where((item) => item.id != pack.id).toList()
            ..add(installedPack);
      await _writeRegistry(root, packs);
      return installedPack;
    } finally {
      for (final file in [temporary, expanded]) {
        if (await file.exists()) await file.delete();
      }
    }
  }

  Future<File> _packFile(
    Directory root,
    String id,
    String version, {
    String suffix = '',
    bool createParents = false,
  }) => safeCatalogFile(root, [
    'catalog_packs',
    id,
    version,
    'catalog.sqlite$suffix',
  ], createParents: createParents);

  Future<void> _verify(File file, int size, String expectedHash) async {
    if (await file.length() != size) {
      throw StateError('Catalog size verification failed');
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != expectedHash.toLowerCase()) {
      throw StateError('Catalog integrity verification failed');
    }
  }

  Future<void> remove(InstalledCatalogPack pack) => _mutate((root) async {
    final file = await _packFile(root, pack.id, pack.version);
    if (p.normalize(p.absolute(pack.path)) != file.path) {
      throw StateError('Unsafe installed catalog path');
    }
    final remaining = (await installed())
        .where((item) => item.id != pack.id)
        .toList();
    await _writeRegistry(root, remaining);
    if (await file.exists()) await file.delete();
  });

  Future<HttpClientResponse> _response(HttpClient client, Uri uri) async {
    if (!CatalogPack.isSecureUri(
      uri,
      allowLoopbackHttp: allowLoopbackHttpForTesting,
    )) {
      throw const FormatException('Catalog transport requires HTTPS');
    }
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 20));
    request.followRedirects = false;
    request.headers.set(HttpHeaders.userAgentHeader, 'BIL/1.0 catalog-packs');
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Catalog request failed: ${response.statusCode}');
    }
    return response;
  }

  Future<void> _download(Uri uri, File file, int size) async {
    final client = HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final response = await _response(client, uri);
      if (response.contentLength > size) {
        throw StateError('Catalog response exceeds declared size');
      }
      final transfer = _writeBounded(response, file, size);
      try {
        await transfer.timeout(
          transferTimeout,
          onTimeout: () {
            client.close(force: true);
            throw TimeoutException('Catalog download timed out');
          },
        );
      } catch (_) {
        client.close(force: true);
        // A timeout must finish cancellation before callers remove the file.
        await transfer.catchError((Object _) {});
        rethrow;
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _writeBounded(
    Stream<List<int>> stream,
    File file,
    int limit,
  ) async {
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final bytes in stream.timeout(transferTimeout)) {
        received += bytes.length;
        if (received > limit) {
          throw StateError('Catalog stream exceeds declared size');
        }
        sink.add(bytes);
        await sink.flush();
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final response = await _response(client, uri);
      if (response.contentLength > maximumManifestBytes) {
        throw const FormatException('Catalog manifest too large');
      }
      final builder = BytesBuilder(copy: false);
      await (() async {
        await for (final bytes in response.timeout(transferTimeout)) {
          if (builder.length + bytes.length > maximumManifestBytes) {
            throw const FormatException('Catalog manifest too large');
          }
          builder.add(bytes);
        }
      })().timeout(
        transferTimeout,
        onTimeout: () {
          client.close(force: true);
          throw TimeoutException('Catalog manifest timed out');
        },
      );
      final decoded = jsonDecode(utf8.decode(builder.takeBytes()));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid catalog manifest');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _writeRegistry(
    Directory root,
    List<InstalledCatalogPack> packs,
  ) async {
    final registry = await safeCatalogFile(root, [
      'catalog_packs.json',
    ], createParents: true);
    final temporary = await safeCatalogFile(root, [
      'catalog_packs.json.writing',
    ]);
    await temporary.writeAsString(
      jsonEncode({
        'schema_version': 1,
        'packs': [
          for (final pack in packs)
            {
              'id': pack.id,
              'version': pack.version,
              'path': pack.path,
              'size_bytes': pack.sizeBytes,
              'installed_at': pack.installedAt.toIso8601String(),
            },
        ],
      }),
      flush: true,
    );
    await replaceCatalogFile(temporary, registry);
  }
}
