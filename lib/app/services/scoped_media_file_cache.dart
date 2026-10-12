import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../environment/app_environment.dart';

String _photoDigest(Uint8List bytes) => sha256.convert(bytes).toString();

/// Bounded, account-namespaced cache for BIL Storage photos. Signed tokens are
/// transport capabilities, not cache keys. A private caller must still hold an
/// authorized visible post and an unexpired URL; this is not a visibility cache.
/// Credentials/URLs are never persisted. Content digests are verified off-isolate.
class ScopedMediaFileCache extends ChangeNotifier {
  ScopedMediaFileCache({Directory? directory, HttpClient? client})
    : _root = directory,
      _client = client ?? HttpClient();

  static final instance = ScopedMediaFileCache();
  static const maxImageBytes = 5 * 1024 * 1024;
  static const maxCacheBytes = 80 * 1024 * 1024;
  static const maxEntries = 256;
  final Directory? _root;
  final HttpClient _client;
  final Map<String, Future<File>> _inFlight = {};
  final Map<String, Future<File?>> _reads = {};
  final Map<
    String,
    ({int size, DateTime modified, DateTime metadataModified, String digest})
  >
  _verified = {};
  final List<Completer<void>> _queue = [];
  final Set<String> _deletedPosts = {};
  int _active = 0, _epoch = 0;
  bool _viewerInitialized = false;
  String? _viewer;
  String? _invalidatedPost;
  Future<void> _clearing = Future<void>.value();

  /// Null denotes a global invalidation. Otherwise only this post was removed.
  String? get invalidatedPost => _invalidatedPost;

  /// Idempotent across many mounted images observing the same auth event.
  /// Even A -> B -> A retires all operations from the first A session.
  void bindViewer(String? viewer) {
    if (!_viewerInitialized) {
      _viewerInitialized = true;
      _viewer = viewer;
      return;
    }
    if (_viewer == viewer) return;
    _viewer = viewer;
    unawaited(clear());
  }

  Future<Directory> _directory() async {
    await _clearing;
    final root =
        _root ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}/bil_scoped_photos_v1',
        );
    await root.create(recursive: true);
    return root;
  }

  static bool supports(Uri uri) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.port == 443 &&
      uri.host == Uri.parse(AppEnvironment.supabaseUrl).host &&
      (uri.path.startsWith('/storage/v1/object/public/profile-avatars/') ||
          uri.path.startsWith(
            '/storage/v1/object/sign/community-post-images/',
          ));
  static bool isPrivate(Uri uri) => uri.path.contains('/object/sign/');

  static DateTime? capabilityExpiry(Uri uri) {
    // Decoding the expiry only rejects stale capabilities. It does not validate
    // their signatures or grant access; the authorized server supplies the URL.
    try {
      final segments = (uri.queryParameters['token'] ?? '').split('.');
      if (segments.length != 3) return null;
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      final exp = decoded is Map ? decoded['exp'] : null;
      if (exp is! num || !exp.isFinite || exp <= 0 || exp > 8640000000000) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(
        (exp * 1000).floor(),
        isUtc: true,
      );
    } on Object {
      return null;
    }
  }

  static bool authorizationCurrent(Uri uri, String? viewer) {
    if (!isPrivate(uri)) return true;
    final expiry = capabilityExpiry(uri);
    return viewer != null &&
        viewer.isNotEmpty &&
        expiry != null &&
        DateTime.now().isBefore(expiry);
  }

  bool _permitted(Uri uri, String? viewer) =>
      supports(uri) &&
      authorizationCurrent(uri, viewer) &&
      (!_viewerInitialized || viewer == _viewer) &&
      !_deletedPosts.any((id) => uri.path.contains('/$id/'));

  static String identity(Uri uri, String? viewer) {
    final query = {...uri.queryParameters}..remove('token');
    final keys = query.keys.toList()..sort();
    final canonical = uri.replace(
      queryParameters: {for (final key in keys) key: query[key]!},
      fragment: '',
    );
    return sha256
        .convert(utf8.encode('${viewer ?? 'guest'}|$canonical'))
        .toString();
  }

  /// Cache-only read: never waits for, starts, or cancels a network download.
  Future<File?> peek(Uri uri, String? viewer) {
    final key = '$_epoch:${identity(uri, viewer)}';
    return _reads.putIfAbsent(
      key,
      () => _peek(uri, viewer).whenComplete(() {
        _reads.remove(key);
      }),
    );
  }

  Future<File?> _peek(Uri uri, String? viewer) async {
    if (!_permitted(uri, viewer)) return null;
    final epoch = _epoch;
    final root = await _directory();
    final key = identity(uri, viewer);
    try {
      final metadataFile = File('${root.path}/$key.json');
      final metadata = jsonDecode(await metadataFile.readAsString());
      if (metadata is! Map) return null;
      final digest = metadata['digest'],
          length = metadata['length'],
          saved = metadata['saved'];
      if (digest is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
          length is! int ||
          length <= 0 ||
          length > maxImageBytes ||
          saved is! int ||
          DateTime.now().millisecondsSinceEpoch - saved >
              const Duration(days: 7).inMilliseconds) {
        return null;
      }
      final file = File('${root.path}/${key}_$digest.img');
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
              FileSystemEntityType.file ||
          await file.length() != length) {
        return null;
      }
      final stamp = await file.stat(),
          metadataStamp = await metadataFile.stat();
      final previous = _verified[key];
      final alreadyVerified =
          previous != null &&
          previous.digest == digest &&
          previous.size == stamp.size &&
          previous.modified == stamp.modified &&
          previous.metadataModified == metadataStamp.modified;
      if ((!alreadyVerified &&
              await compute(_photoDigest, await file.readAsBytes()) !=
                  digest) ||
          epoch != _epoch ||
          !_permitted(uri, viewer)) {
        return null;
      }
      _verified[key] = (
        size: stamp.size,
        modified: stamp.modified,
        metadataModified: metadataStamp.modified,
        digest: digest,
      );
      // Access time, rather than the first download, owns the disk LRU.
      final touched = DateTime.now();
      await file.setLastModified(touched);
      final actualModified = (await file.stat()).modified;
      _verified[key] = (
        size: stamp.size,
        modified: actualModified,
        metadataModified: metadataStamp.modified,
        digest: digest,
      );
      while (_verified.length > maxEntries) {
        _verified.remove(_verified.keys.first);
      }
      return file;
    } on Object {
      return null;
    }
  }

  Future<File> resolve(
    Uri uri,
    String? viewer, {
    required bool Function() current,
  }) {
    if (!current() || !_permitted(uri, viewer)) {
      return Future<File>.error(
        const FormatException('Photo access is unavailable.'),
      );
    }
    final key = identity(uri, viewer), epoch = _epoch;
    final operationKey = '$epoch:$key';
    // A shared request is independent of its first widget's lifetime. Each
    // consumer checks its own generation after completion; auth uses the epoch.
    final future = _inFlight.putIfAbsent(
      operationKey,
      () => _resolve(uri, viewer, key, epoch).whenComplete(() {
        _inFlight.remove(operationKey);
      }),
    );
    return future.then((file) {
      if (!current() || epoch != _epoch || !_permitted(uri, viewer)) {
        throw StateError('Photo request retired.');
      }
      return file;
    });
  }

  Future<File> _resolve(Uri uri, String? viewer, String key, int epoch) async {
    bool current() => epoch == _epoch && _permitted(uri, viewer);
    final cached = await peek(uri, viewer);
    final root = await _directory();
    final metadata = File('${root.path}/$key.json');
    if (cached != null &&
        current() &&
        await metadata.exists() &&
        DateTime.now().difference(await metadata.lastModified()) <
            const Duration(minutes: 5)) {
      return cached;
    }
    await _acquire();
    HttpClientRequest? request;
    File? temporary;
    try {
      if (!current()) throw StateError('Photo request retired.');
      _client.connectionTimeout = const Duration(seconds: 8);
      var abandoned = false;
      request = await _client
          .getUrl(uri)
          .then((value) {
            if (abandoned || !current()) value.abort();
            return value;
          })
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              abandoned = true;
              throw TimeoutException('Photo connection timed out.');
            },
          );
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200 ||
          response.contentLength > maxImageBytes) {
        // Do not keep showing stale private pixels after an explicit denial.
        if (isPrivate(uri) &&
            (response.statusCode == 401 ||
                response.statusCode == 403 ||
                response.statusCode == 404)) {
          await remove(uri, viewer);
          throw const _PrivatePhotoDenied();
        }
        throw const FormatException('Photo download failed.');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final part in response.timeout(const Duration(seconds: 10))) {
        if (!current() || bytes.length + part.length > maxImageBytes) {
          throw StateError('Photo request retired or oversized.');
        }
        bytes.add(part);
      }
      final data = bytes.takeBytes();
      if (!_imageSignature(data)) {
        throw const FormatException('Unsupported image bytes.');
      }
      final digest = await compute(_photoDigest, data);
      final target = File('${root.path}/${key}_$digest.img');
      temporary = File('${target.path}.$epoch.partial');
      await temporary.writeAsBytes(data, flush: true);
      if (!current()) throw StateError('Photo request retired.');
      if (await target.exists()) {
        await temporary.delete();
      } else {
        await temporary.rename(target.path);
      }
      temporary = File('${metadata.path}.$epoch.partial');
      await temporary.writeAsString(
        jsonEncode({
          'digest': digest,
          'length': data.length,
          'path': uri.path,
          'saved': DateTime.now().millisecondsSinceEpoch,
        }),
        flush: true,
      );
      if (!current()) throw StateError('Photo request retired.');
      await temporary.rename(metadata.path);
      temporary = null;
      if (!current()) throw StateError('Photo request retired.');
      unawaited(_prune(root, target.path));
      return target;
    } on Object catch (error) {
      request?.abort();
      try {
        if (temporary != null && await temporary.exists()) {
          await temporary.delete();
        }
      } on Object {
        /* best effort */
      }
      if (error is! _PrivatePhotoDenied && cached != null && current()) {
        return cached;
      }
      rethrow;
    } finally {
      _release();
    }
  }

  static bool _imageSignature(Uint8List b) =>
      b.length >= 12 &&
      ((b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) ||
          (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4e && b[3] == 0x47) ||
          (ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
              ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP'));
  Future<void> _acquire() async {
    if (_active < 3) {
      _active++;
      return;
    }
    final gate = Completer<void>();
    _queue.add(gate);
    await gate.future;
  }

  void _release() {
    if (_queue.isEmpty) {
      _active--;
    } else {
      _queue.removeAt(0).complete();
    }
  }

  Future<void> remove(Uri uri, String? viewer) async {
    _verified.remove(identity(uri, viewer));
    try {
      final root = await _directory(), key = identity(uri, viewer);
      await for (final file in root.list(followLinks: false)) {
        final name = file.uri.pathSegments.last;
        if (file is File &&
            (name == '$key.json' || name.startsWith('${key}_'))) {
          await file.delete();
        }
      }
    } on Object {
      /* A cache failure must not change the durable source. */
    }
  }

  Future<void> invalidatePost(String id) async {
    if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(id)) return;
    _deletedPosts.add(id);
    _invalidatedPost = id;
    notifyListeners();
    try {
      final root = await _directory();
      await for (final entry in root.list(followLinks: false)) {
        if (entry is! File || !entry.path.endsWith('.json')) continue;
        Object? metadata;
        try {
          metadata = jsonDecode(await entry.readAsString());
        } on FormatException {
          await entry.delete();
          continue;
        }
        if (metadata is Map &&
            metadata['path'] is String &&
            (metadata['path'] as String).contains('/$id/')) {
          final key = entry.uri.pathSegments.last.replaceFirst('.json', '');
          final digest = metadata['digest'];
          if (digest is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
            final file = File('${root.path}/${key}_$digest.img');
            if (await file.exists()) await file.delete();
          }
          await entry.delete();
        }
      }
    } on Object {
      /* The tombstone still blocks future reads/writes. */
    }
  }

  Future<void> _prune(Directory root, String keep) async {
    try {
      final rows = <({File file, FileStat stat})>[];
      await for (final entry in root.list(followLinks: false)) {
        if (entry is File && entry.path.endsWith('.img')) {
          rows.add((file: entry, stat: await entry.stat()));
        }
      }
      rows.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
      var size = rows.fold<int>(0, (total, row) => total + row.stat.size),
          count = rows.length;
      for (final row in rows) {
        if (size <= maxCacheBytes && count <= maxEntries) break;
        if (row.file.path == keep) continue;
        await row.file.delete();
        size -= row.stat.size;
        count--;
      }
      // Remove metadata whose content was evicted; do not accumulate sidecars.
      await for (final entry in root.list(followLinks: false)) {
        if (entry is File &&
            entry.path.endsWith('.partial') &&
            DateTime.now().difference(await entry.lastModified()) >
                const Duration(days: 1)) {
          await entry.delete();
          continue;
        }
        if (entry is! File || !entry.path.endsWith('.json')) continue;
        Object? metadata;
        try {
          metadata = jsonDecode(await entry.readAsString());
        } on FormatException {
          await entry.delete();
          continue;
        }
        final key = entry.uri.pathSegments.last.replaceFirst('.json', '');
        final digest = metadata is Map ? metadata['digest'] : null;
        if (digest is! String ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
            !await File('${root.path}/${key}_$digest.img').exists()) {
          await entry.delete();
        }
      }
    } on Object {
      /* Cache cleanup must not interrupt photo display. */
    }
  }

  @visibleForTesting
  Future<void> trimForTesting() async => _prune(await _directory(), '');

  /// Logout/account change retires queued writers before deleting account data.
  Future<void> clear() {
    _epoch++;
    _verified.clear();
    _invalidatedPost = null;
    notifyListeners();
    final previous = _clearing;
    _clearing = () async {
      await previous;
      final root =
          _root ??
          Directory(
            '${(await getApplicationSupportDirectory()).path}/bil_scoped_photos_v1',
          );
      if (await root.exists()) await root.delete(recursive: true);
    }().catchError((Object _) {});
    return _clearing;
  }
}

class _PrivatePhotoDenied implements Exception {
  const _PrivatePhotoDenied();
}
