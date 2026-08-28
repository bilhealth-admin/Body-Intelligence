import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/wellness_content_pack.dart';
import 'wellness_access_token.dart';

enum WellnessMediaCacheStatus { ready, unavailableOffline }

class WellnessMediaCacheResult {
  const WellnessMediaCacheResult._({
    required this.status,
    this.file,
    this.fromCache = false,
  });

  const WellnessMediaCacheResult.ready(File file, {required bool fromCache})
    : this._(
        status: WellnessMediaCacheStatus.ready,
        file: file,
        fromCache: fromCache,
      );

  const WellnessMediaCacheResult.unavailableOffline()
    : this._(status: WellnessMediaCacheStatus.unavailableOffline);

  final WellnessMediaCacheStatus status;
  final File? file;
  final bool fromCache;

  bool get isReady => status == WellnessMediaCacheStatus.ready;
}

/// Verifies licensed wellness media before exposing a local playback file.
///
/// Cache names are content-addressed SHA-256 digests plus a MIME-derived safe
/// extension required by native media players. Downloads remain in a sibling
/// temporary file until HTTPS transfer, exact length, and digest have passed;
/// corrupt cache entries fail closed and are removed.
class WellnessMediaCache {
  WellnessMediaCache({
    HttpClient? client,
    Directory? directory,
    WellnessAccessTokenLoader? accessTokenLoader,
  }) : _client = client ?? HttpClient(),
       _ownsClient = client == null,
       _injectedDirectory = directory,
       _accessTokenLoader = accessTokenLoader ?? loadCurrentWellnessAccessToken;

  final HttpClient _client;
  final bool _ownsClient;
  final Directory? _injectedDirectory;
  final WellnessAccessTokenLoader _accessTokenLoader;
  final Map<String, Future<WellnessMediaCacheResult>> _inFlight = {};

  Future<WellnessMediaCacheResult> resolve(
    WellnessMediaAsset asset, {
    required bool online,
  }) {
    _validateAsset(asset);
    final identity = _operationIdentity(asset);
    return _inFlight.putIfAbsent(identity, () {
      final operation = _resolve(asset, online: online);
      return operation.whenComplete(() {
        _inFlight.remove(identity);
      });
    });
  }

  Future<WellnessMediaCacheResult> _resolve(
    WellnessMediaAsset asset, {
    required bool online,
  }) async {
    final directory = await _directory();
    final target = _fileFor(directory, asset);
    final temporary = _temporaryFor(directory, asset);
    if (await _isVerified(target, asset)) {
      return WellnessMediaCacheResult.ready(target, fromCache: true);
    }
    await _safeDelete(target, directory);
    await _safeDelete(temporary, directory);
    if (!online) return const WellnessMediaCacheResult.unavailableOffline();

    try {
      final request = await _client.getUrl(asset.url);
      request.followRedirects = false;
      applyWellnessBearer(request, _accessTokenLoader, asset.url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Wellness media returned ${response.statusCode}.',
          uri: asset.url,
        );
      }
      for (final redirect in response.redirects) {
        if (redirect.location.scheme != 'https') {
          throw const FormatException(
            'Wellness media redirect must preserve HTTPS.',
          );
        }
      }
      await _writeExact(response, temporary, asset.sizeBytes);
      if (!await _isVerified(temporary, asset)) {
        throw const FormatException(
          'Wellness media integrity verification failed.',
        );
      }
      await temporary.rename(target.path);
      if (!await _isVerified(target, asset)) {
        throw const FormatException(
          'Wellness media cache verification failed after install.',
        );
      }
      return WellnessMediaCacheResult.ready(target, fromCache: false);
    } catch (_) {
      await _safeDelete(temporary, directory);
      await _safeDelete(target, directory);
      rethrow;
    }
  }

  Future<void> remove(WellnessMediaAsset asset) async {
    _validateAsset(asset);
    final active = _inFlight[_operationIdentity(asset)];
    if (active != null) {
      try {
        await active;
      } catch (_) {
        // The failed operation cleans its own temporary and target files.
      }
    }
    final directory = await _directory();
    await _safeDelete(_fileFor(directory, asset), directory);
    await _safeDelete(_temporaryFor(directory, asset), directory);
  }

  void dispose() {
    if (_ownsClient) _client.close(force: false);
  }

  Future<Directory> _directory() async {
    final directory =
        _injectedDirectory ??
        Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            'wellness_media_cache',
          ),
        );
    await directory.create(recursive: true);
    return directory;
  }

  static void _validateAsset(WellnessMediaAsset asset) {
    if (asset.url.scheme != 'https' || asset.url.host.isEmpty) {
      throw const FormatException('Wellness media URL must use HTTPS.');
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(asset.sha256) ||
        asset.sizeBytes <= 0) {
      throw const FormatException('Invalid wellness media cache identity.');
    }
    _extensionFor(asset.mimeType);
  }

  static File _fileFor(Directory directory, WellnessMediaAsset asset) {
    final file = File(
      p.join(
        directory.absolute.path,
        '${asset.sha256}${_extensionFor(asset.mimeType)}',
      ),
    );
    _assertWithin(directory, file.path);
    return file;
  }

  static File _temporaryFor(Directory directory, WellnessMediaAsset asset) {
    final file = File(
      p.join(
        directory.absolute.path,
        '${asset.sha256}${_extensionFor(asset.mimeType)}.download',
      ),
    );
    _assertWithin(directory, file.path);
    return file;
  }

  static String _extensionFor(String mimeType) => switch (mimeType
      .toLowerCase()) {
    'video/mp4' => '.mp4',
    'video/webm' => '.webm',
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    'image/webp' => '.webp',
    _ => throw const FormatException('Unsupported wellness media MIME type.'),
  };

  static String _operationIdentity(WellnessMediaAsset asset) =>
      '${asset.sha256}:${_extensionFor(asset.mimeType)}';

  static void _assertWithin(Directory directory, String path) {
    final root = p.normalize(directory.absolute.path);
    final candidate = p.normalize(File(path).absolute.path);
    if (!p.isWithin(root, candidate)) {
      throw StateError('Unsafe wellness media cache path.');
    }
  }

  static Future<void> _safeDelete(File file, Directory directory) async {
    _assertWithin(directory, file.path);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.file ||
        type == FileSystemEntityType.link) {
      await file.delete();
    }
  }

  static Future<bool> _isVerified(File file, WellnessMediaAsset asset) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.file) return false;
    if (await file.length() != asset.sizeBytes) return false;
    return (await sha256.bind(file.openRead()).first).toString() ==
        asset.sha256;
  }

  static Future<void> _writeExact(
    Stream<List<int>> source,
    File target,
    int expectedBytes,
  ) async {
    final sink = target.openWrite(mode: FileMode.writeOnly);
    var received = 0;
    try {
      await for (final chunk in source) {
        received += chunk.length;
        if (received > expectedBytes) {
          throw const FormatException('Wellness media exceeds declared size.');
        }
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (received != expectedBytes) {
      throw const FormatException(
        'Wellness media size does not match catalog.',
      );
    }
  }
}
