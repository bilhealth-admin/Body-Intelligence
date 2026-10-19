import 'package:body_intelligence_log/features/nutrition/services/meal_image_analysis_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:body_intelligence_log/features/nutrition/services/meal_vision_image_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  for (final resize in [false, true]) {
    test('AI image removes GPS and private EXIF, resize=$resize', () async {
      final source = img.Image(width: resize ? 240 : 80, height: 60);
      img.fill(source, color: img.ColorRgb8(40, 120, 180));
      source.exif.gpsIfd.setGpsLocation(latitude: 12.34567, longitude: 45.6789);
      source.exif.imageIfd.imageDescription = 'BIL_SYNTHETIC_PRIVATE_METADATA';
      final original = img.encodeJpg(source);
      final fixture = img.decodeJpg(original)!;
      expect(
        fixture.exif.gpsIfd.hasGPSLatitude,
        isTrue,
        reason: 'The fixture must really contain location metadata.',
      );
      expect(
        fixture.exif.imageIfd.imageDescription,
        'BIL_SYNTHETIC_PRIVATE_METADATA',
      );
      final prepared = await const DefaultMealVisionImagePreprocessor(
        maximumDimension: 128,
      ).prepare(bytes: original, mimeType: 'image/jpeg');
      final output = img.decodeImage(prepared.bytes)!;
      expect(output.exif.gpsIfd.hasGPSLatitude, isFalse);
      expect(output.exif.gpsIfd.hasGPSLongitude, isFalse);
      expect(output.exif.imageIfd.imageDescription, isNull);
      expect(
        latin1.decode(prepared.bytes),
        isNot(contains('BIL_SYNTHETIC_PRIVATE_METADATA')),
      );
      expect(output.width, resize ? 128 : 80);
      expect(output.getPixel(0, 0).b, closeTo(180, 8));
    });
  }

  for (final orientation in [3, 6]) {
    test(
      'private metadata removal preserves orientation $orientation',
      () async {
        final source = img.Image(width: 64, height: 32);
        for (final pixel in source) {
          pixel.setRgb(pixel.x < 32 ? 240 : 10, 20, pixel.x < 32 ? 10 : 240);
        }
        source.exif.imageIfd.orientation = orientation;
        final original = img.encodeJpg(source, quality: 100);
        expect(img.decodeJpgExif(original)!.imageIfd.orientation, orientation);
        final prepared = await const DefaultMealVisionImagePreprocessor()
            .prepare(bytes: original, mimeType: 'image/jpeg');
        final output = img.decodeJpg(prepared.bytes)!;
        expect(prepared.orientationCorrected, isTrue);
        expect(output.exif.imageIfd.orientation, isNull);
        if (orientation == 6) {
          expect((output.width, output.height), (32, 64));
          expect(output.getPixel(16, 8).r, greaterThan(200));
          expect(output.getPixel(16, 56).b, greaterThan(200));
        } else {
          expect((output.width, output.height), (64, 32));
          expect(output.getPixel(8, 16).b, greaterThan(200));
          expect(output.getPixel(56, 16).r, greaterThan(200));
        }
      },
    );
  }

  test(
    'real default gateway payload contains only sanitized PNG pixels',
    () async {
      final source = img.Image(width: 80, height: 60);
      source.textData = {'Author': 'BIL_SYNTHETIC_PRIVATE_METADATA'};
      final original = Uint8List.fromList(img.encodePng(source));
      expect(img.decodePng(original)!.textData, isNotEmpty);
      Map<String, dynamic>? sent;
      final service = MealImageAnalysisService(
        endpoint: 'https://image-privacy.invalid/analyze',
        accessToken: () => 'synthetic-session',
        gatewayPost: ({required uri, required headers, required body}) async {
          sent = jsonDecode(body) as Map<String, dynamic>;
          return const MealImageGatewayResponse(
            statusCode: 200,
            body:
                '{"schema_version":1,"request_id":"synthetic","candidates":[]}',
          );
        },
      );
      await service.analyze(XFile.fromData(original, mimeType: 'image/png'));
      final payload = base64Decode(sent!['image_base64'] as String);
      expect(sent!['mime_type'], 'image/jpeg');
      expect(img.decodeImage(payload)!.textData, anyOf(isNull, isEmpty));
      expect(
        latin1.decode(payload),
        isNot(contains('BIL_SYNTHETIC_PRIVATE_METADATA')),
      );
      expect((sent!['image_width'], sent!['image_height']), (80, 60));
    },
  );

  test('signature-only bytes are not treated as a real photo', () async {
    await expectLater(
      const DefaultMealVisionImagePreprocessor().prepare(
        bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
        mimeType: 'image/jpeg',
      ),
      throwsA(isA<MealImageAnalysisException>()),
    );
  });
}
