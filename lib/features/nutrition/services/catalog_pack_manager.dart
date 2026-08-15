import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/catalog_pack.dart';

typedef CatalogSupportRootResolver = Future<Directory> Function();

class CatalogPackManager {
  CatalogPackManager({
    CatalogSupportRootResolver? rootResolver,
    String? manifestUrlOverride,
  }) : _rootResolver = rootResolver ?? getApplicationSupportDirectory,
       _manifestUrl = manifestUrlOverride ?? manifestUrl;

  final CatalogSupportRootResolver _rootResolver;
  final String _manifestUrl;

  static const productionManifestUrl =
      'https://tgmanzhqulksykhslrzb.supabase.co/storage/v1/object/public/'
      'catalogs/manifest.json';
  static const manifestUrl = String.fromEnvironment(
    'BIL_CATALOG_MANIFEST_URL',
    defaultValue: productionManifestUrl,
  );

  bool get downloadsConfigured => _manifestUrl.trim().isNotEmpty;

  Future<List<CatalogPack>> fetchAvailable() async {
    if (!downloadsConfigured) return const <CatalogPack>[];
    final json = await _getJson(Uri.parse(_manifestUrl));
    final rawPacks = json['packs'];
    if (rawPacks is! List) throw const FormatException('Missing packs list');
    return rawPacks
        .whereType<Map<String, dynamic>>()
        .map(CatalogPack.fromJson)
        .toList(growable: false);
  }

  Future<List<InstalledCatalogPack>> installed() async {
    final registry = await _registryFile();
    if (!await registry.exists()) return const <InstalledCatalogPack>[];
    final decoded = jsonDecode(await registry.readAsString());
    if (decoded is! Map<String, dynamic> || decoded['packs'] is! List) {
      return const <InstalledCatalogPack>[];
    }
    return (decoded['packs'] as List)
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => InstalledCatalogPack(
            id: json['id'] as String,
            version: json['version'] as String,
            path: json['path'] as String,
            sizeBytes: json['size_bytes'] as int,
            installedAt: DateTime.parse(json['installed_at'] as String),
          ),
        )
        .where((pack) => File(pack.path).existsSync())
        .toList(growable: false);
  }

  Future<InstalledCatalogPack> install(CatalogPack pack) async {
    final root = await _rootResolver();
    final directory = Directory(
      p.join(root.path, 'catalog_packs', pack.id, pack.version),
    );
    await directory.create(recursive: true);
    final destination = File(p.join(directory.path, 'catalog.sqlite'));
    final temporary = File('${destination.path}.download');
    if (await temporary.exists()) await temporary.delete();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(pack.downloadUri);
      request.headers.set(HttpHeaders.userAgentHeader, 'BIL/1.0 catalog-packs');
      final response = await request.close().timeout(
        const Duration(minutes: 2),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Catalog download failed: ${response.statusCode}');
      }
      final sink = temporary.openWrite();
      await response.pipe(sink);
    } finally {
      client.close(force: true);
    }

    final actualSize = await temporary.length();
    if (actualSize != pack.sizeBytes) {
      await temporary.delete();
      throw StateError('Catalog size verification failed');
    }
    final actualHash = await _sha256File(temporary);
    if (actualHash.toLowerCase() != pack.sha256.toLowerCase()) {
      await temporary.delete();
      throw StateError('Catalog integrity verification failed');
    }
    if (await destination.exists()) await destination.delete();
    if (pack.compression == null) {
      await temporary.rename(destination.path);
    } else if (pack.compression == 'gzip') {
      final output = destination.openWrite();
      try {
        await gzip.decoder.bind(temporary.openRead()).pipe(output);
      } catch (_) {
        await output.close();
        if (await destination.exists()) await destination.delete();
        rethrow;
      }
      await temporary.delete();
      final installedSize = await destination.length();
      if (pack.installedSizeBytes != null &&
          installedSize != pack.installedSizeBytes) {
        await destination.delete();
        throw StateError('Installed catalog size verification failed');
      }
      if (pack.databaseSha256 != null) {
        final installedHash = await _sha256File(destination);
        if (installedHash != pack.databaseSha256) {
          await destination.delete();
          throw StateError('Installed catalog integrity verification failed');
        }
      }
    } else {
      await temporary.delete();
      throw StateError('Unsupported catalog compression: ${pack.compression}');
    }

    final installedPack = InstalledCatalogPack(
      id: pack.id,
      version: pack.version,
      path: destination.path,
      sizeBytes: await destination.length(),
      installedAt: DateTime.now().toUtc(),
    );
    await _upsertRegistry(installedPack);
    return installedPack;
  }

  Future<String> _sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }

  Future<void> remove(InstalledCatalogPack pack) async {
    final file = File(pack.path);
    if (await file.exists()) await file.delete();
    final remaining = (await installed()).where((item) => item.id != pack.id);
    await _writeRegistry(remaining.toList(growable: false));
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'BIL/1.0 catalog-packs');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Manifest request failed: ${response.statusCode}');
      }
      final decoded = jsonDecode(await utf8.decoder.bind(response).join());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid catalog manifest');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<File> _registryFile() async {
    final root = await _rootResolver();
    return File(p.join(root.path, 'catalog_packs.json'));
  }

  Future<void> _upsertRegistry(InstalledCatalogPack pack) async {
    final packs =
        (await installed()).where((item) => item.id != pack.id).toList()
          ..add(pack);
    await _writeRegistry(packs);
  }

  Future<void> _writeRegistry(List<InstalledCatalogPack> packs) async {
    final registry = await _registryFile();
    final temporary = File('${registry.path}.writing');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
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
    if (await registry.exists()) await registry.delete();
    await temporary.rename(registry.path);
  }
}
