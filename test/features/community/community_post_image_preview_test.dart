import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Future<CommunityPostImagePreview> _preview(CommunityPostImageDraft original) =>
    createCommunityPostImagePreviewAsync(
      original.bytes,
      expectedMimeType: original.mimeType,
      expectedByteLength: original.byteLength,
      expectedWidth: original.width,
      expectedHeight: original.height,
    );

void _expectBounded(CommunityPostImagePreview preview) {
  expect(preview.width, inInclusiveRange(1, 256));
  expect(preview.height, inInclusiveRange(1, 256));
  expect(preview.byteLength, inInclusiveRange(1, 64 * 1024));
  final decoded = img.decodeImage(preview.bytes)!;
  expect(decoded.width, preview.width);
  expect(decoded.height, preview.height);
  expect(preview, isNot(isA<CommunityPostImageDraft>()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'large noisy alpha image stays bounded and preserves transparency',
    () async {
      final random = Random(62026);
      final source = img.Image(width: 1024, height: 768, numChannels: 4);
      for (final pixel in source) {
        pixel.setRgba(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
          pixel.x < 40 ? 0 : random.nextInt(256),
        );
      }
      final original = validateCommunityPostImage(
        Uint8List.fromList(img.encodePng(source, level: 0)),
      );
      expect(original.byteLength, greaterThan(1024 * 1024));
      final preview = await _preview(original);
      _expectBounded(preview);
      expect(preview.mimeType, 'image/png');
      final decoded = img.decodePng(preview.bytes)!;
      expect(decoded.hasAlpha, isTrue);
      expect(decoded.getPixel(0, decoded.height ~/ 2).a, 0);
      expect(preview.width / preview.height, closeTo(4 / 3, .02));
      expect(preview.bytes, isNot(original.bytes));
      expect(original.width, 1024);
      expect(original.height, 768);
    },
  );

  test(
    'real JPEG and WebP photos remain decodable with their aspect ratios',
    () async {
      for (final path in [
        'assets/images/professional/recipes/shakshuka.jpg',
        'assets/images/onboarding_2026/bil_onboarding_meal_quick_add_photo_v1.webp',
      ]) {
        final original = validateCommunityPostImage(
          await File(path).readAsBytes(),
        );
        final preview = await _preview(original);
        _expectBounded(preview);
        expect(
          preview.width / preview.height,
          closeTo(original.aspectRatio, .02),
        );
        expect(original.bytes, await File(path).readAsBytes());
      }
    },
  );

  test(
    'small alpha photos are not enlarged and preview bytes are immutable',
    () async {
      final source = img.Image(width: 31, height: 17, numChannels: 4);
      img.fill(source, color: img.ColorRgba8(15, 70, 180, 128));
      final original = validateCommunityPostImage(
        Uint8List.fromList(img.encodePng(source)),
      );
      final preview = await _preview(original);
      _expectBounded(preview);
      expect(preview.width, 31);
      expect(preview.height, 17);
      expect(() => preview.bytes[0] = 0, throwsUnsupportedError);
      expect(img.decodePng(preview.bytes)!.getPixel(0, 0).a, 128);
    },
  );

  test(
    'extreme valid aspect ratios still produce nonzero bounded dimensions',
    () async {
      final source = img.Image(width: 8192, height: 1);
      img.fill(source, color: img.ColorRgb8(30, 80, 160));
      final original = validateCommunityPostImage(
        Uint8List.fromList(img.encodePng(source)),
      );
      final preview = await _preview(original);
      _expectBounded(preview);
      expect(preview.width, 256);
      expect(preview.height, 1);
    },
  );

  test(
    'EXIF orientation matches the validated original before resizing',
    () async {
      final source = img.Image(width: 400, height: 200);
      for (final pixel in source) {
        pixel.setRgb(pixel.x < 200 ? 240 : 10, 20, pixel.x < 200 ? 10 : 240);
      }
      source.exif.imageIfd.orientation = 6;
      final encoded = Uint8List.fromList(img.encodeJpg(source, quality: 100));
      final original = validateCommunityPostImage(encoded);
      expect(original.width, 200);
      expect(original.height, 400);
      final preview = await _preview(original);
      _expectBounded(preview);
      expect(preview.width, 128);
      expect(preview.height, 256);
      final decoded = img.decodeImage(preview.bytes)!;
      expect(decoded.getPixel(64, 20).r, greaterThan(200));
      expect(decoded.getPixel(64, 230).b, greaterThan(200));
      expect(original.bytes, encoded);
    },
  );

  test(
    'wrong original metadata cannot become a successful thumbnail',
    () async {
      final original = validateCommunityPostImage(
        await File(
          'assets/images/professional/recipes/shakshuka.jpg',
        ).readAsBytes(),
      );
      for (final field in ['mime', 'bytes', 'width', 'height']) {
        await expectLater(
          createCommunityPostImagePreviewAsync(
            original.bytes,
            expectedMimeType: field == 'mime' ? 'image/png' : original.mimeType,
            expectedByteLength: field == 'bytes' ? 1 : original.byteLength,
            expectedWidth: field == 'width' ? 1 : original.width,
            expectedHeight: field == 'height' ? 1 : original.height,
          ),
          throwsFormatException,
          reason: field,
        );
      }
    },
  );

  test(
    'empty and oversized encoded inputs fail before worker decoding',
    () async {
      for (final bytes in [Uint8List(0), Uint8List(5 * 1024 * 1024 + 1)]) {
        await expectLater(
          createCommunityPostImagePreviewAsync(
            bytes,
            expectedMimeType: 'image/png',
            expectedByteLength: bytes.length,
            expectedWidth: 1,
            expectedHeight: 1,
          ),
          throwsFormatException,
        );
      }
    },
  );
}
