import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/services/scoped_media_file_cache.dart';

class _LoopbackPhotoClient implements HttpClient {
  _LoopbackPhotoClient(this.port);
  final int port;
  final HttpClient inner = HttpClient();
  @override
  Future<HttpClientRequest> getUrl(Uri uri) =>
      inner.getUrl(uri.replace(scheme: 'http', host: '127.0.0.1', port: port));
  @override
  set connectionTimeout(Duration? value) => inner.connectionTimeout = value;
  @override
  void close({bool force = false}) => inner.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Delegates every used operation to a real test-owned directory. Only the
/// first native listing is paused, so clear/prune ordering needs no sleeps.
class _GatedRealDirectory implements Directory {
  _GatedRealDirectory(this.inner);
  final Directory inner;
  final listingStarted = Completer<void>();
  final releaseListing = Completer<void>();
  final listingFinished = Completer<void>();
  bool _firstListing = true;
  int deletes = 0;
  bool deletedDuringListing = false;

  @override
  String get path => inner.path;

  @override
  Future<Directory> create({bool recursive = false}) async {
    await inner.create(recursive: recursive);
    return this;
  }

  @override
  Future<bool> exists() => Future<bool>.value(inner.existsSync());

  @override
  Future<Directory> delete({bool recursive = false}) async {
    deletes++;
    deletedDuringListing |= !listingFinished.isCompleted;
    await inner.delete(recursive: recursive);
    return this;
  }

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) async* {
    final gated = _firstListing;
    _firstListing = false;
    var firstEntry = true;
    try {
      await for (final entry in inner.list(
        recursive: recursive,
        followLinks: followLinks,
      )) {
        if (gated && firstEntry) {
          firstEntry = false;
          listingStarted.complete();
          await releaseListing.future;
        }
        yield entry;
      }
    } finally {
      if (gated && !listingFinished.isCompleted) listingFinished.complete();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late ScopedMediaFileCache cache;
  late HttpClient client;
  Uri photo({String token = '', bool private = false}) => Uri.parse(
    '${AppEnvironment.supabaseUrl}/storage/v1/object/${private ? 'sign/community-post-images' : 'public/profile-avatars'}/a/photo.png',
  ).replace(queryParameters: token.isEmpty ? null : {'token': token});
  String token(int epochSeconds) =>
      'header.${base64Url.encode(utf8.encode(jsonEncode({'exp': epochSeconds}))).replaceAll('=', '')}.signature';
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bil-cache-test-');
    client = HttpClient();
    cache = ScopedMediaFileCache(directory: directory, client: client);
    cache.bindViewer('A');
  });
  tearDown(() async {
    await cache.clear();
    cache.dispose();
    client.close(force: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  });
  Future<File> seed(Uri uri, {String viewer = 'A'}) async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final digest = sha256.convert(bytes).toString();
    final key = ScopedMediaFileCache.identity(uri, viewer);
    final file = File('${directory.path}/${key}_$digest.img');
    await file.writeAsBytes(bytes);
    await File('${directory.path}/$key.json').writeAsString(
      jsonEncode({
        'digest': digest,
        'length': bytes.length,
        'saved': DateTime.now().millisecondsSinceEpoch,
        'path': uri.path,
      }),
    );
    return file;
  }

  test(
    'signed token rotation does not change content identity; owner does',
    () {
      final a = photo(token: 'first', private: true),
          b = photo(token: 'second', private: true);
      expect(
        ScopedMediaFileCache.identity(a, 'A'),
        ScopedMediaFileCache.identity(b, 'A'),
      );
      expect(
        ScopedMediaFileCache.identity(a, 'A'),
        isNot(ScopedMediaFileCache.identity(a, 'B')),
      );
      expect(
        ScopedMediaFileCache.identity(
          a.replace(queryParameters: {'token': 'first', 'width': '320'}),
          'A',
        ),
        isNot(ScopedMediaFileCache.identity(a, 'A')),
      );
    },
  );
  test('wrong host, credential URL and cleartext are never cached', () {
    expect(
      ScopedMediaFileCache.supports(photo().replace(host: 'attacker.invalid')),
      isFalse,
    );
    expect(
      ScopedMediaFileCache.supports(photo().replace(userInfo: 'u:p')),
      isFalse,
    );
    expect(
      ScopedMediaFileCache.supports(photo().replace(scheme: 'http')),
      isFalse,
    );
  });
  test(
    'cached fresh bytes survive cache recreation without starting HTTP',
    () async {
      final uri = photo();
      final expected = await seed(uri);
      final second = ScopedMediaFileCache(directory: directory, client: client)
        ..bindViewer('A');
      expect((await second.peek(uri, 'A'))?.path, expected.path);
      expect(
        (await second.resolve(uri, 'A', current: () => true)).path,
        expected.path,
      );
      second.dispose();
    },
  );
  test('corrupt bytes and another viewer never satisfy a local read', () async {
    final uri = photo();
    final file = await seed(uri);
    expect(await cache.peek(uri, 'B'), isNull);
    await file.writeAsBytes([4, 3, 2, 1]);
    expect(await cache.peek(uri, 'A'), isNull);
  });
  test('private cache requires an unexpired capability and a viewer', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final valid = photo(private: true, token: token(now + 60));
    await seed(valid);
    expect(await cache.peek(valid, 'A'), isNotNull);
    expect(
      await cache.peek(photo(private: true, token: token(now - 60)), 'A'),
      isNull,
    );
    expect(await cache.peek(valid, null), isNull);
  });
  test('account retirement purges previous photos', () async {
    final uri = photo();
    await seed(uri);
    cache.bindViewer('B');
    await cache.clear();
    cache.bindViewer('A');
    await cache.clear();
    expect(await cache.peek(uri, 'A'), isNull);
  });
  test(
    'corrupt metadata and crash partial cleanup do not stop bounded LRU eviction',
    () async {
      final retained = await seed(photo());
      await retained.setLastModified(DateTime(2000));
      await cache.peek(
        photo(),
        'A',
      ); // A real read touches the retained content.
      final crash = File('${directory.path}/interrupted.partial');
      await crash.writeAsString('not a completed image');
      await crash.setLastModified(DateTime(2000));
      await File('${directory.path}/bad.json').writeAsString('{broken');
      for (var i = 0; i < ScopedMediaFileCache.maxEntries; i++) {
        final file = File('${directory.path}/old-$i.img');
        await file.writeAsBytes([1]);
        await file.setLastModified(DateTime(2000).add(Duration(seconds: i)));
      }
      await cache.trimForTesting();
      expect(await retained.exists(), isTrue);
      expect(await crash.exists(), isFalse);
      expect(await File('${directory.path}/bad.json').exists(), isFalse);
      final entries = await directory.list().toList();
      expect(
        entries.where((file) => file.path.endsWith('.img')),
        hasLength(ScopedMediaFileCache.maxEntries),
      );
      expect(await File('${directory.path}/old-0.img').exists(), isFalse);
    },
  );
  test(
    'clear waits for an open real directory prune before deleting cache data',
    () async {
      final retained = await seed(photo());
      final root = _GatedRealDirectory(directory);
      final maintenanceCache = ScopedMediaFileCache(
        directory: root,
        client: client,
      )..bindViewer('A');
      final trimming = maintenanceCache.trimForTesting();
      Future<void>? clearing;
      var cleared = false;
      try {
        await root.listingStarted.future;
        clearing = maintenanceCache.clear().then((_) {
          cleared = true;
        });
        // The previous clear and exists probe are completed futures. Drain
        // their microtasks while the real listing remains explicitly blocked.
        for (var turn = 0; turn < 4; turn++) {
          await Future<void>.value();
        }
        expect(root.listingFinished.isCompleted, isFalse);
        expect(cleared, isFalse);
        expect(root.deletes, 0);
        expect(await retained.exists(), isTrue);
        root.releaseListing.complete();
        await trimming;
        await clearing;
        expect(root.listingFinished.isCompleted, isTrue);
        expect(cleared, isTrue);
        expect(root.deletes, 1);
        expect(root.deletedDuringListing, isFalse);
        expect(await directory.exists(), isFalse);
      } finally {
        if (!root.releaseListing.isCompleted) root.releaseListing.complete();
        await trimming;
        if (clearing != null) {
          await clearing;
        } else {
          await maintenanceCache.clear();
        }
        maintenanceCache.dispose();
      }
    },
  );

  test('byte budget is enforced independently from the entry budget', () async {
    for (var i = 0; i < 28; i++) {
      final file = await File(
        '${directory.path}/large-$i.img',
      ).open(mode: FileMode.write);
      await file.truncate(3 * 1024 * 1024);
      await file.close();
    }
    await cache.trimForTesting();
    var bytes = 0;
    await for (final file in directory.list()) {
      if (file is File) bytes += await file.length();
    }
    expect(bytes, lessThanOrEqualTo(ScopedMediaFileCache.maxCacheBytes));
  });
  test(
    'unwritable cache directory rejects without publishing a partial image',
    () async {
      final occupied = File('${directory.path}/not-a-directory');
      await occupied.writeAsString('occupied');
      final broken = ScopedMediaFileCache(
        directory: Directory(occupied.path),
        client: client,
      )..bindViewer('A');
      await expectLater(
        broken.resolve(photo(), 'A', current: () => true),
        throwsA(isA<FileSystemException>()),
      );
      expect(await occupied.readAsString(), 'occupied');
      broken.dispose();
    },
  );
  test(
    'real loopback downloads coalesce, survive first consumer exit and never exceed three',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final transport = _LoopbackPhotoClient(server.port);
      final ioCache = ScopedMediaFileCache(
        directory: directory,
        client: transport,
      )..bindViewer('A');
      final release = Completer<void>(), three = Completer<void>();
      var active = 0, maximum = 0, requests = 0, firstCurrent = true;
      final subscription = server.listen((request) async {
        requests++;
        active++;
        if (active > maximum) maximum = active;
        if (active == 3 && !three.isCompleted) three.complete();
        await release.future;
        request.response.add([
          0x89,
          0x50,
          0x4e,
          0x47,
          13,
          10,
          26,
          10,
          1,
          2,
          3,
          4,
        ]);
        await request.response.close();
        active--;
      });
      try {
        final first = ioCache.resolve(
          photo(),
          'A',
          current: () => firstCurrent,
        );
        final firstError = expectLater(first, throwsStateError);
        final second = ioCache.resolve(photo(), 'A', current: () => true);
        final others = [
          for (var i = 0; i < 5; i++)
            ioCache.resolve(
              photo().replace(
                path:
                    '/storage/v1/object/public/profile-avatars/a/photo-$i.png',
              ),
              'A',
              current: () => true,
            ),
        ];
        await three.future.timeout(const Duration(seconds: 10));
        expect(requests, 3);
        expect(maximum, 3);
        firstCurrent = false;
        release.complete();
        final files = await Future.wait([second, ...others]);
        await firstError;
        expect(files, hasLength(6));
        expect(requests, 6);
        expect(maximum, 3);
        for (final file in files) {
          expect(await file.exists(), isTrue);
        }
        final metadata = await directory
            .list()
            .where((entry) => entry.path.endsWith('.json'))
            .toList();
        for (final entry in metadata.cast<File>()) {
          expect(await entry.readAsString(), isNot(contains('token')));
        }
      } finally {
        if (!release.isCompleted) release.complete();
        await subscription.cancel();
        await server.close(force: true);
        transport.close(force: true);
        await ioCache.clear();
        ioCache.dispose();
      }
    },
  );
}
