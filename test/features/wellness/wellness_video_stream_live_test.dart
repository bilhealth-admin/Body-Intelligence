import 'dart:io';

import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_video_stream.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opt-in public read-only smoke check. It never authenticates, downloads a
/// complete video, or claims native iPhone/Android decoder evidence.
void main() {
  const enabled = bool.fromEnvironment('BIL_LIVE_WORKOUT_STREAM_CHECK');

  test(
    'live public BIL stream supports pinned native range delivery',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final asset = WellnessMediaAsset(
          url: Uri.parse(
            'https://workouts.bilhealth.com/v2/objects/workouts/v1/'
            'gym-six-month/movements/'
            'mobility-flexibility-adductor-rock-back-gentle-flow.mp4',
          ),
          mimeType: 'video/mp4',
          sha256:
              '66f1f2888ecc59829562c01de7016582a65fd3b0de3c7108cfb2ea6588384439',
          sizeBytes: 18669598,
        );
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);
        final resolver = WellnessVideoStreamResolver(
          client: client,
          accessTokenLoader: () => null,
        );
        try {
          final stream = await resolver.resolve(asset);
          expect(stream, isNotNull);
          expect(stream!.uri, asset.url);
          expect(stream.httpHeaders.containsKey('authorization'), isFalse);
          final request = await client
              .getUrl(stream.uri)
              .timeout(const Duration(seconds: 10));
          request.followRedirects = false;
          stream.httpHeaders.forEach(request.headers.set);
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-31');
          final response = await request.close().timeout(
            const Duration(seconds: 10),
          );
          expect(response.statusCode, HttpStatus.partialContent);
          expect(
            response.headers.value(HttpHeaders.contentRangeHeader),
            'bytes 0-31/${asset.sizeBytes}',
          );
          final bytes = await response
              .timeout(const Duration(seconds: 10))
              .fold<List<int>>([], (bytes, part) => bytes..addAll(part));
          expect(bytes, hasLength(32));
          expect(String.fromCharCodes(bytes.skip(4).take(4)), 'ftyp');
        } finally {
          client.close(force: true);
        }
      }, _UnmockedPublicNetwork());
    },
    skip: enabled
        ? false
        : 'Explicit BIL_LIVE_WORKOUT_STREAM_CHECK opt-in required.',
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

class _UnmockedPublicNetwork extends HttpOverrides {}
