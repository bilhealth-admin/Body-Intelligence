import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_media_cache.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_video_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sizeBytes = 2048;
  final digest = List<String>.filled(64, 'a').join();
  final canonicalUri = Uri.parse(
    'https://workouts.bilhealth.com/v2/objects/workouts/v1/home/'
    'movements/push-up.mp4',
  );

  WellnessMediaAsset asset({
    Uri? uri,
    String mimeType = 'video/mp4',
    String? sha256,
    int size = sizeBytes,
  }) => WellnessMediaAsset(
    url: uri ?? canonicalUri,
    mimeType: mimeType,
    sha256: sha256 ?? digest,
    sizeBytes: size,
  );

  _FakeResponse validResponse({
    int statusCode = HttpStatus.ok,
    int contentLength = sizeBytes,
    String? contentType = 'video/mp4',
    String? acceptRanges = 'bytes',
    String? etag = '"movement-v1"',
  }) => _FakeResponse(
    statusCode: statusCode,
    contentLength: contentLength,
    contentType: contentType,
    acceptRanges: acceptRanges,
    etag: etag,
  );

  test('returns a pinned canonical stream with the trusted bearer', () async {
    final response = validResponse();
    final client = _FakeHttpClient(response);
    final resolver = WellnessVideoStreamResolver(
      client: client,
      accessTokenLoader: () => '  signed-session-token  ',
    );

    final stream = await resolver.resolve(asset());

    expect(stream, isNotNull);
    expect(stream!.uri, canonicalUri);
    expect(stream.httpHeaders, {
      HttpHeaders.ifMatchHeader: '"movement-v1"',
      HttpHeaders.authorizationHeader: 'Bearer signed-session-token',
    });
    expect(client.requestedUri, canonicalUri);
    expect(client.lastRequest?.followRedirects, isFalse);
    expect(client.lastRequest?.authorization, 'Bearer signed-session-token');
    expect(response.canceled, isTrue);
    expect(
      () => stream.httpHeaders['another'] = 'value',
      throwsUnsupportedError,
    );
  });

  test('omits authorization when no current session exists', () async {
    final client = _FakeHttpClient(validResponse());
    final resolver = WellnessVideoStreamResolver(
      client: client,
      accessTokenLoader: () => null,
    );

    final stream = await resolver.resolve(asset());

    expect(stream?.httpHeaders, {HttpHeaders.ifMatchHeader: '"movement-v1"'});
    expect(client.lastRequest?.authorization, isNull);
  });

  test('valid non-first-party media returns null without a request', () async {
    var tokenReads = 0;
    final client = _FakeHttpClient(validResponse());
    final resolver = WellnessVideoStreamResolver(
      client: client,
      accessTokenLoader: () {
        tokenReads += 1;
        return 'must-not-leak';
      },
    );
    final externalUris = [
      Uri.parse('https://cdn.example.test/workouts/push-up.mp4?version=1'),
      Uri.parse(
        'https://workouts.bilhealth.com.evil.test/v2/objects/workouts/v1/'
        'home/movements/push-up.mp4',
      ),
      Uri.parse(
        'https://workouts.bilhealth.com@evil.test/v2/objects/workouts/v1/'
        'home/movements/push-up.mp4',
      ),
    ];

    for (final uri in externalUris) {
      expect(await resolver.resolve(asset(uri: uri)), isNull, reason: '$uri');
    }
    expect(
      await resolver.resolve(
        asset(
          uri: Uri.parse('https://cdn.example.test/workout.webm'),
          mimeType: 'video/webm',
        ),
      ),
      isNull,
    );
    expect(client.requests, 0);
    expect(tokenReads, 0);
  });

  test('rejects malformed metadata before external fallback', () async {
    final client = _FakeHttpClient(validResponse());
    final resolver = WellnessVideoStreamResolver(client: client);
    final cases = [
      asset(uri: Uri.parse('http://cdn.example.test/video.mp4')),
      asset(mimeType: 'video/avi'),
      asset(sha256: 'not-a-digest'),
      asset(size: 0),
    ];

    for (final candidate in cases) {
      await expectLater(resolver.resolve(candidate), throwsFormatException);
    }
    expect(client.requests, 0);
  });

  test('rejects every noncanonical first-party URL before auth', () async {
    var tokenReads = 0;
    final client = _FakeHttpClient(validResponse());
    final resolver = WellnessVideoStreamResolver(
      client: client,
      accessTokenLoader: () {
        tokenReads += 1;
        return 'must-not-leak';
      },
    );
    final invalidUris = [
      Uri.parse('$canonicalUri?download=1'),
      Uri.parse('$canonicalUri#fragment'),
      Uri.parse(
        'https://workouts.bilhealth.com:444/v2/objects/workouts/v1/home/'
        'movements/push-up.mp4',
      ),
      Uri.parse(
        'https://user@workouts.bilhealth.com/v2/objects/workouts/v1/home/'
        'movements/push-up.mp4',
      ),
      Uri.parse(
        'https://workouts.bilhealth.com/v2/objects/workouts/v1/home/'
        'movements/push%2Fup.mp4',
      ),
      Uri.parse(
        'https://workouts.bilhealth.com/v2/objects/workouts/v2/home/'
        'movements/push-up.mp4',
      ),
      Uri.parse(
        'https://workouts.bilhealth.com/v2/objects/workouts/v1/home/'
        'movements/Push-Up.mp4',
      ),
      Uri.parse(
        'https://workouts.bilhealth.com/v2/objects/workouts/v1/home/'
        'previews/push-up.mp4',
      ),
    ];

    for (final uri in invalidUris) {
      await expectLater(
        resolver.resolve(asset(uri: uri)),
        throwsFormatException,
        reason: '$uri',
      );
    }
    expect(client.requests, 0);
    expect(tokenReads, 0);
  });

  test('first-party streaming rejects otherwise valid WebM metadata', () async {
    final client = _FakeHttpClient(validResponse());

    await expectLater(
      WellnessVideoStreamResolver(
        client: client,
      ).resolve(asset(mimeType: 'video/webm')),
      throwsFormatException,
    );
    expect(client.requests, 0);
  });

  test('allows the canonical gym path and explicit HTTPS port', () async {
    final uri = Uri.parse(
      'https://workouts.bilhealth.com:443/v2/objects/workouts/v1/'
      'gym-six-month/movements/cable-row.mp4',
    );
    final client = _FakeHttpClient(validResponse());

    final stream = await WellnessVideoStreamResolver(
      client: client,
    ).resolve(asset(uri: uri));

    expect(stream?.uri, uri);
    expect(client.requests, 1);
  });

  test('rejects redirects, auth failures, and server errors', () async {
    for (final status in [
      HttpStatus.found,
      HttpStatus.unauthorized,
      HttpStatus.forbidden,
      HttpStatus.internalServerError,
      HttpStatus.serviceUnavailable,
    ]) {
      final response = validResponse(statusCode: status);
      final client = _FakeHttpClient(response);
      await expectLater(
        WellnessVideoStreamResolver(client: client).resolve(asset()),
        throwsA(
          isA<HttpException>().having(
            (error) => error.message,
            'message',
            contains('$status'),
          ),
        ),
        reason: '$status',
      );
      expect(client.lastRequest?.followRedirects, isFalse);
      expect(client.lastRequest?.aborted, isTrue);
      expect(response.canceled, isTrue);
    }
  });

  test('requires exact catalog length and MP4 response MIME', () async {
    final responses = [
      validResponse(contentLength: sizeBytes - 1),
      validResponse(contentLength: -1),
      validResponse(contentType: 'video/webm'),
      validResponse(contentType: null),
    ];

    for (final response in responses) {
      final client = _FakeHttpClient(response);
      await expectLater(
        WellnessVideoStreamResolver(client: client).resolve(asset()),
        throwsFormatException,
      );
      expect(response.canceled, isTrue);
    }
  });

  test('requires Accept-Ranges bytes', () async {
    for (final value in <String?>[null, 'none', 'bytes, none']) {
      final response = validResponse(acceptRanges: value);
      await expectLater(
        WellnessVideoStreamResolver(
          client: _FakeHttpClient(response),
        ).resolve(asset()),
        throwsFormatException,
        reason: '$value',
      );
      expect(response.canceled, isTrue);
    }
  });

  test('requires a strong quoted ETag and returns it unchanged', () async {
    for (final value in <String?>[
      null,
      '',
      'movement-v1',
      'W/"movement-v1"',
      '""',
      '"contains space"',
      '"nested"quote"',
    ]) {
      final response = validResponse(etag: value);
      await expectLater(
        WellnessVideoStreamResolver(
          client: _FakeHttpClient(response),
        ).resolve(asset()),
        throwsFormatException,
        reason: '$value',
      );
      expect(response.canceled, isTrue);
    }

    final response = validResponse(etag: '"opaque-v2"');
    final result = await WellnessVideoStreamResolver(
      client: _FakeHttpClient(response),
    ).resolve(asset());
    expect(result?.httpHeaders[HttpHeaders.ifMatchHeader], '"opaque-v2"');
  });

  test('stalled connection times out and aborts a late request', () async {
    final client = _FakeHttpClient(
      validResponse(),
      connectDelay: const Duration(milliseconds: 120),
    );
    final resolver = WellnessVideoStreamResolver(
      client: client,
      idleTimeout: const Duration(milliseconds: 30),
    );

    await expectLater(
      resolver.resolve(asset()),
      throwsA(isA<TimeoutException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 140));
    expect(client.lastRequest?.aborted, isTrue);
    expect(client.response.canceled, isFalse);
  });

  test('stalled headers abort request and cancel a late response', () async {
    final response = validResponse();
    final client = _FakeHttpClient(
      response,
      responseDelay: const Duration(milliseconds: 120),
    );
    final resolver = WellnessVideoStreamResolver(
      client: client,
      idleTimeout: const Duration(milliseconds: 30),
    );

    await expectLater(
      resolver.resolve(asset()),
      throwsA(isA<TimeoutException>()),
    );
    expect(client.lastRequest?.aborted, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    expect(response.canceled, isTrue);
  });

  test(
    'media cache forwards its configured idle timeout to streaming',
    () async {
      final response = validResponse();
      final client = _FakeHttpClient(
        response,
        responseDelay: const Duration(milliseconds: 120),
      );
      final cache = WellnessMediaCache(
        client: client,
        idleTimeout: const Duration(milliseconds: 30),
      );

      await expectLater(
        cache.resolveStream(asset(), online: true),
        throwsA(isA<TimeoutException>()),
      );
      expect(client.lastRequest?.aborted, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(response.canceled, isTrue);
    },
  );

  test('idle timeout must be positive', () {
    expect(
      () => WellnessVideoStreamResolver(idleTimeout: Duration.zero),
      throwsArgumentError,
    );
  });
}

final class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(
    this.response, {
    this.connectDelay = Duration.zero,
    this.responseDelay = Duration.zero,
  });

  final _FakeResponse response;
  final Duration connectDelay;
  final Duration responseDelay;
  int requests = 0;
  Uri? requestedUri;
  _FakeRequest? lastRequest;

  @override
  Future<HttpClientRequest> headUrl(Uri url) async {
    requests += 1;
    requestedUri = url;
    final request = _FakeRequest(response, responseDelay);
    lastRequest = request;
    if (connectDelay > Duration.zero) {
      await Future<void>.delayed(connectDelay);
    }
    return request;
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.response, this.responseDelay);

  final _FakeResponse response;
  final Duration responseDelay;
  bool aborted = false;

  String? get authorization => headers.value(HttpHeaders.authorizationHeader);

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  bool followRedirects = true;

  @override
  Future<HttpClientResponse> close() async {
    if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }
    return response;
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) => aborted = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeResponse({
    required this.statusCode,
    required this.contentLength,
    required String? contentType,
    required String? acceptRanges,
    required String? etag,
  }) : headers = _FakeHeaders({
         HttpHeaders.contentTypeHeader: ?contentType,
         HttpHeaders.acceptRangesHeader: ?acceptRanges,
         HttpHeaders.etagHeader: ?etag,
       });

  @override
  final int statusCode;

  @override
  final int contentLength;

  @override
  final HttpHeaders headers;

  bool canceled = false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _FakeSubscription(() => canceled = true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeHeaders implements HttpHeaders {
  _FakeHeaders([Map<String, String> values = const {}]) {
    for (final entry in values.entries) {
      _values[entry.key.toLowerCase()] = entry.value;
    }
  }

  final Map<String, String> _values = {};

  @override
  ContentType? get contentType {
    final raw = value(HttpHeaders.contentTypeHeader);
    return raw == null ? null : ContentType.parse(raw);
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = value.toString();
  }

  @override
  String? value(String name) => _values[name.toLowerCase()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeSubscription implements StreamSubscription<List<int>> {
  _FakeSubscription(this.onCancel);

  final void Function() onCancel;

  @override
  Future<void> cancel() async => onCancel();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
