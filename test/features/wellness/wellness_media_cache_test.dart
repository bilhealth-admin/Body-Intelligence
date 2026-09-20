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

  test(
    'download sends the current Supabase bearer before verification',
    () async {
      final bytes = utf8.encode('authorized licensed workout bytes');
      final asset = assetFor(
        bytes,
        url: Uri.parse(
          'https://workouts.bilhealth.com/v2/objects/workouts/v1/home/movements/test.mp4',
        ),
      );
      final client = _FakeHttpClient(bytes);
      final cache = WellnessMediaCache(
        client: client,
        directory: directory,
        accessTokenLoader: () => '  signed-session-token  ',
      );

      final result = await cache.resolve(asset, online: true);

      expect(result.isReady, isTrue);
      expect(client.authorization, 'Bearer signed-session-token');
      expect(client.followRedirects, isFalse);
      expect(await result.file!.readAsBytes(), bytes);
    },
  );

  test('download never sends the session bearer to another origin', () async {
    final bytes = utf8.encode('externally hosted verified bytes');
    final asset = assetFor(bytes);
    final client = _FakeHttpClient(bytes);
    final cache = WellnessMediaCache(
      client: client,
      directory: directory,
      accessTokenLoader: () => 'signed-session-token',
    );

    final result = await cache.resolve(asset, online: true);

    expect(result.isReady, isTrue);
    expect(client.authorization, isNull);
    expect(client.followRedirects, isFalse);
  });

  test('public v3 and v4 recipe images never receive the bearer', () async {
    final bytes = utf8.encode('verified public recipe preview');
    final digest = sha256.convert(bytes).toString();
    final cases = <(String, String)>[
      ('/v3/recipes/images/recipe-id/$digest', 'image/jpeg'),
      ('/v4/recipes/thumbnails/recipe-id/$digest.webp', 'image/webp'),
    ];
    for (final (path, mimeType) in cases) {
      final asset = assetFor(
        bytes,
        url: Uri.https('workouts.bilhealth.com', path),
        mimeType: mimeType,
      );
      final client = _FakeHttpClient(bytes);
      final cache = WellnessMediaCache(
        client: client,
        directory: directory,
        accessTokenLoader: () => 'signed-session-token',
      );

      final result = await cache.resolve(asset, online: true);

      expect(result.isReady, isTrue, reason: path);
      expect(client.authorization, isNull, reason: path);
      expect(client.followRedirects, isFalse, reason: path);
      await cache.remove(asset);
    }
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

  test('stalled connection times out and a late request is aborted', () async {
    final bytes = utf8.encode('video bytes');
    final client = _FakeHttpClient(
      bytes,
      connectDelay: const Duration(milliseconds: 250),
    );
    final cache = WellnessMediaCache(
      client: client,
      directory: directory,
      idleTimeout: const Duration(milliseconds: 80),
    );
    await expectLater(
      cache.resolve(assetFor(bytes), online: true),
      throwsA(isA<TimeoutException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 280));
    expect(client.lastRequest?.aborted, isTrue);
    expect(await directory.list().toList(), isEmpty);
  });

  test(
    'stalled headers abort and release the same asset for explicit retry',
    () async {
      final bytes = utf8.encode('retry video bytes');
      final client = _FakeHttpClient(
        bytes,
        responseDelay: const Duration(milliseconds: 250),
      );
      final cache = WellnessMediaCache(
        client: client,
        directory: directory,
        idleTimeout: const Duration(milliseconds: 80),
      );
      final asset = assetFor(bytes);
      await expectLater(
        cache.resolve(asset, online: true),
        throwsA(isA<TimeoutException>()),
      );
      expect(client.lastRequest?.aborted, isTrue);
      expect(await directory.list().toList(), isEmpty);
      client.responseDelay = Duration.zero;
      final retried = await cache.resolve(asset, online: true);
      expect(retried.isReady, isTrue);
      expect(client.requests, 2);
    },
  );

  test(
    'stalled body cancels transport and removes unverified partial bytes',
    () async {
      final bytes = utf8.encode('complete video bytes');
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final client = _FakeHttpClient(bytes, bodyStream: body.stream);
      final cache = WellnessMediaCache(
        client: client,
        directory: directory,
        idleTimeout: const Duration(milliseconds: 100),
      );
      body.add(bytes.take(4).toList());
      await expectLater(
        cache.resolve(assetFor(bytes), online: true),
        throwsA(isA<TimeoutException>()),
      );
      expect(client.lastRequest?.aborted, isTrue);
      expect(cancelled, isTrue);
      expect(await directory.list().toList(), isEmpty);
      await body.close();
    },
  );

  test(
    'slow but progressing body can exceed the idle timeout in total',
    () async {
      final bytes = utf8.encode('verified');
      Stream<List<int>> progressingBody() async* {
        for (final byte in bytes) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          yield [byte];
        }
      }

      final client = _FakeHttpClient(bytes, bodyStream: progressingBody());
      final cache = WellnessMediaCache(
        client: client,
        directory: directory,
        idleTimeout: const Duration(milliseconds: 150),
      );
      final result = await cache.resolve(assetFor(bytes), online: true);
      expect(result.isReady, isTrue);
      expect(await result.file!.readAsBytes(), bytes);
      expect(client.lastRequest?.aborted, isFalse);
    },
  );
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(
    this.bytes, {
    this.statusCode = HttpStatus.ok,
    this.chunks = 1,
    this.connectDelay = Duration.zero,
    this.responseDelay = Duration.zero,
    this.bodyStream,
  });

  final List<int> bytes;
  final int statusCode, chunks;
  final Duration connectDelay;
  Duration responseDelay;
  final Stream<List<int>>? bodyStream;
  int requests = 0;
  _RecordingHttpHeaders? lastRequestHeaders;
  _FakeHttpClientRequest? lastRequest;

  String? get authorization =>
      lastRequestHeaders?.value(HttpHeaders.authorizationHeader);
  bool? get followRedirects => lastRequest?.followRedirects;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests += 1;
    if (connectDelay != Duration.zero) await Future<void>.delayed(connectDelay);
    final headers = _RecordingHttpHeaders();
    lastRequestHeaders = headers;
    final request = _FakeHttpClientRequest(
      _FakeHttpClientResponse(
        bytes,
        statusCode: statusCode,
        chunks: chunks,
        bodyStream: bodyStream,
      ),
      headers,
      responseDelay,
    );
    lastRequest = request;
    return request;
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.response, this.headers, this.responseDelay);

  final HttpClientResponse response;
  final Duration responseDelay;
  bool aborted = false;

  @override
  final HttpHeaders headers;

  @override
  bool followRedirects = true;

  @override
  Future<HttpClientResponse> close() async {
    if (responseDelay != Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }
    return response;
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) => aborted = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingHttpHeaders implements HttpHeaders {
  final Map<String, String> _values = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = value.toString();
  }

  @override
  String? value(String name) => _values[name.toLowerCase()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(
    this.bytes, {
    required this.statusCode,
    required this.chunks,
    this.bodyStream,
  });

  final List<int> bytes;
  final int chunks;
  final Stream<List<int>>? bodyStream;

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
    if (bodyStream != null) {
      return bodyStream!.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
    }
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
