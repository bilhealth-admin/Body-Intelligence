import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_media_cache.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bil-media-cache-test-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  WellnessMediaAsset assetFor(
    List<int> bytes, {
    Uri? url,
    String mimeType = 'video/mp4',
    String? digest,
    int? size,
  }) => WellnessMediaAsset(
    url: url ?? Uri.parse('https://cdn.example.test/workout.mp4'),
    mimeType: mimeType,
    sha256: digest ?? sha256.convert(bytes).toString(),
    sizeBytes: size ?? bytes.length,
  );

  test('verified cached media is reusable while explicitly offline', () async {
    final bytes = utf8.encode('verified workout video');
    final asset = assetFor(bytes);
    final cached = File(p.join(directory.path, '${asset.sha256}.mp4'));
    await cached.writeAsBytes(bytes, flush: true);
    final client = _FakeHttpClient(bytes);
    final cache = WellnessMediaCache(client: client, directory: directory);

    final result = await cache.resolve(asset, online: false);

    expect(result.status, WellnessMediaCacheStatus.ready);
    expect(result.fromCache, isTrue);
    expect(result.file?.path, cached.path);
    expect(client.requests, 0);
  });

  test('corrupt cached media is removed and unavailable offline', () async {
    final bytes = utf8.encode('verified workout video');
    final asset = assetFor(bytes);
    final cached = File(p.join(directory.path, '${asset.sha256}.mp4'));
    await cached.writeAsBytes(List<int>.filled(bytes.length, 1), flush: true);
    final client = _FakeHttpClient(bytes);
    final cache = WellnessMediaCache(client: client, directory: directory);

    final result = await cache.resolve(asset, online: false);

    expect(result.status, WellnessMediaCacheStatus.unavailableOffline);
    expect(result.file, isNull);
    expect(await cached.exists(), isFalse);
    expect(client.requests, 0);
  });

  test('download is verified then atomically promoted by digest', () async {
    final bytes = utf8.encode('licensed workout video bytes');
    final asset = assetFor(bytes);
    final client = _FakeHttpClient(bytes, chunks: 3);
    final cache = WellnessMediaCache(client: client, directory: directory);

    final result = await cache.resolve(asset, online: true);

    expect(result.status, WellnessMediaCacheStatus.ready);
    expect(result.fromCache, isFalse);
    expect(p.basename(result.file!.path), '${asset.sha256}.mp4');
    expect(await result.file!.readAsBytes(), bytes);
    expect(
      await File(
        p.join(directory.path, '${asset.sha256}.mp4.download'),
      ).exists(),
      isFalse,
    );
    expect(client.requests, 1);
  });

  test('wrong size or digest never becomes playable cache', () async {
    final bytes = utf8.encode('licensed workout video bytes');
    final invalidAssets = <WellnessMediaAsset>[
      assetFor(bytes, size: bytes.length - 1),
      assetFor(bytes, digest: List<String>.filled(64, 'a').join()),
    ];

    for (final asset in invalidAssets) {
      final cache = WellnessMediaCache(
        client: _FakeHttpClient(bytes),
        directory: directory,
      );
      await expectLater(
        cache.resolve(asset, online: true),
        throwsFormatException,
      );
      expect(
        await File(p.join(directory.path, '${asset.sha256}.mp4')).exists(),
        isFalse,
      );
      expect(
        await File(
          p.join(directory.path, '${asset.sha256}.mp4.download'),
        ).exists(),
        isFalse,
      );
    }
  });

  test('non-HTTPS media is rejected before opening a request', () async {
    final bytes = utf8.encode('video');
    final client = _FakeHttpClient(bytes);
    final cache = WellnessMediaCache(client: client, directory: directory);

    expect(
      () => cache.resolve(
        assetFor(bytes, url: Uri.parse('http://example.test/video.mp4')),
        online: true,
      ),
      throwsFormatException,
    );
    expect(client.requests, 0);
  });

  test('non-success response is never cached', () async {
    final bytes = utf8.encode('missing video');
    final asset = assetFor(bytes);
    final cache = WellnessMediaCache(
      client: _FakeHttpClient(bytes, statusCode: HttpStatus.notFound),
      directory: directory,
    );

    await expectLater(
      cache.resolve(asset, online: true),
      throwsA(isA<HttpException>()),
    );
    expect(
      await File(p.join(directory.path, '${asset.sha256}.mp4')).exists(),
      isFalse,
    );
  });

  test('cache uses only approved MIME-derived player extensions', () async {
    final bytes = utf8.encode('media bytes');
    final cases = <(String, String, String)>[
      ('video/webm', 'https://example.test/video.webm', '.webm'),
      ('image/jpeg', 'https://example.test/image.jpg', '.jpg'),
      ('image/png', 'https://example.test/image.png', '.png'),
      ('image/webp', 'https://example.test/image.webp', '.webp'),
    ];
    for (final (mimeType, url, extension) in cases) {
      final asset = assetFor(bytes, url: Uri.parse(url), mimeType: mimeType);
      final cache = WellnessMediaCache(
        client: _FakeHttpClient(bytes),
        directory: directory,
      );
      final result = await cache.resolve(asset, online: true);
      expect(p.basename(result.file!.path), '${asset.sha256}$extension');
      await cache.remove(asset);
    }

    final unsupported = assetFor(
      bytes,
      url: Uri.parse('https://example.test/image.gif'),
      mimeType: 'image/gif',
    );
    expect(
      () => WellnessMediaCache(
        client: _FakeHttpClient(bytes),
        directory: directory,
      ).resolve(unsupported, online: true),
      throwsFormatException,
    );
  });

  test('safe remove deletes only the digest and its temporary file', () async {
    final bytes = utf8.encode('video');
    final asset = assetFor(bytes);
    final target = File(p.join(directory.path, '${asset.sha256}.mp4'));
    final temporary = File(
      p.join(directory.path, '${asset.sha256}.mp4.download'),
    );
    final unrelated = File(p.join(directory.path, 'keep-me'));
    await target.writeAsBytes(bytes);
    await temporary.writeAsBytes(bytes);
    await unrelated.writeAsString('safe');
    final cache = WellnessMediaCache(
      client: _FakeHttpClient(bytes),
      directory: directory,
    );

    await cache.remove(asset);

    expect(await target.exists(), isFalse);
    expect(await temporary.exists(), isFalse);
    expect(await unrelated.readAsString(), 'safe');
  });

  test('concurrent requests for one digest share one download', () async {
    final bytes = utf8.encode('video shared once');
    final asset = assetFor(bytes);
    final client = _FakeHttpClient(bytes, chunks: 2);
    final cache = WellnessMediaCache(client: client, directory: directory);

    final results = await Future.wait([
      cache.resolve(asset, online: true),
      cache.resolve(asset, online: true),
    ]);

    expect(results.every((result) => result.isReady), isTrue);
    expect(client.requests, 1);
  });
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(
    this.bytes, {
    this.statusCode = HttpStatus.ok,
    this.chunks = 1,
  });

  final List<int> bytes;
  final int statusCode, chunks;
  int requests = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests += 1;
    return _FakeHttpClientRequest(
      _FakeHttpClientResponse(bytes, statusCode: statusCode, chunks: chunks),
    );
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.response);

  final HttpClientResponse response;

  @override
  Future<HttpClientResponse> close() async => response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(
    this.bytes, {
    required this.statusCode,
    required this.chunks,
  });

  final List<int> bytes;
  final int chunks;

  @override
  final int statusCode;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final size = (bytes.length / chunks).ceil();
    final data = <List<int>>[];
    for (var offset = 0; offset < bytes.length; offset += size) {
      final end = offset + size > bytes.length ? bytes.length : offset + size;
      data.add(bytes.sublist(offset, end));
    }
    return Stream<List<int>>.fromIterable(data).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
