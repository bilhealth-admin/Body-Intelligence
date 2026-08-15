import 'dart:convert';
import 'dart:typed_data';

import 'package:body_intelligence_log/features/nutrition/services/meal_image_analysis_service.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_vision_image_preprocessor.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

void main() {
  const preprocessor = DefaultMealVisionImagePreprocessor();

  test('keeps a small bounded image byte-for-byte and records hash', () async {
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 80, height: 60)),
    );
    final result = await preprocessor.prepare(
      bytes: bytes,
      mimeType: 'image/png',
    );
    expect(result.bytes, orderedEquals(bytes));
    expect(result.mimeType, 'image/png');
    expect(result.reencoded, isFalse);
    expect(result.width, 80);
    expect(result.height, 60);
    expect(result.sha256, sha256.convert(bytes).toString());
  });

  test('bounds a large image and emits controlled JPEG', () async {
    final source = img.Image(width: 2400, height: 1200);
    img.fill(source, color: img.ColorRgb8(40, 120, 180));
    final result = await preprocessor.prepare(
      bytes: img.encodePng(source),
      mimeType: 'image/png',
    );
    expect(result.mimeType, 'image/jpeg');
    expect(result.reencoded, isTrue);
    expect(result.width, 1600);
    expect(result.height, 800);
    expect(result.bytes.take(3), orderedEquals(<int>[0xff, 0xd8, 0xff]));
    expect(result.sha256, sha256.convert(result.bytes).toString());
  });

  test('rejects mismatched format and oversized input', () async {
    await expectLater(
      preprocessor.prepare(bytes: <int>[1, 2, 3], mimeType: 'image/jpeg'),
      throwsA(isA<MealImageAnalysisException>()),
    );
    await expectLater(
      preprocessor.prepare(
        bytes: Uint8List(12 * 1024 * 1024 + 1),
        mimeType: 'image/png',
      ),
      throwsA(isA<MealImageAnalysisException>()),
    );
  });

  test(
    'analysis service uses injectable preprocessing output and hash',
    () async {
      Map<String, dynamic>? capturedBody;
      final service = MealImageAnalysisService(
        endpoint: 'https://example.test/vision',
        accessToken: () => 'session',
        imagePreprocessor: const _FixturePreprocessor(),
        gatewayPost: ({required uri, required headers, required body}) async {
          capturedBody = jsonDecode(body) as Map<String, dynamic>;
          return const MealImageGatewayResponse(
            statusCode: 200,
            body: '{"schema_version":1,"request_id":"r","candidates":[]}',
          );
        },
      );
      await service.analyze(
        XFile.fromData(
          Uint8List.fromList(<int>[0xff, 0xd8, 0xff]),
          mimeType: 'image/jpeg',
        ),
      );
      expect(
        capturedBody?['image_base64'],
        base64Encode(<int>[0xff, 0xd8, 0xff, 1]),
      );
      expect(capturedBody?['image_sha256'], 'fixture-hash');
      expect(capturedBody?['image_width'], 900);
      expect(capturedBody?['image_reencoded'], isTrue);
    },
  );
}

class _FixturePreprocessor implements MealVisionImagePreprocessor {
  const _FixturePreprocessor();

  @override
  Future<MealVisionPreparedImage> prepare({
    required List<int> bytes,
    required String mimeType,
  }) async => MealVisionPreparedImage(
    bytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 1]),
    mimeType: 'image/jpeg',
    sha256: 'fixture-hash',
    width: 900,
    height: 600,
    reencoded: true,
    orientationCorrected: true,
  );
}
