import 'dart:convert';
import 'dart:typed_data';
import 'package:body_intelligence_log/shared/media/private_image_pixels.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test(
    'clean JPEG, PNG and WebP stay byte-identical after repeated validation',
    () {
      final source = img.Image(width: 31, height: 17);
      for (final bytes in [
        img.encodeJpg(source),
        img.encodePng(source),
        img.encodeWebP(source),
      ]) {
        expect(imageBytesAreMetadataFree(Uint8List.fromList(bytes)), isTrue);
        final checked = validateCommunityPostImage(Uint8List.fromList(bytes));
        expect(checked.bytes, orderedEquals(bytes));
        expect(
          validateCommunityPostImage(checked.bytes).bytes,
          orderedEquals(bytes),
        );
      }
    },
  );

  test('unparsed JPEG comments and trailing data never pass through', () {
    final original = img.encodeJpg(img.Image(width: 31, height: 17));
    final marker = utf8.encode('BIL_PRIVATE_COMMENT_MARKER');
    final size = marker.length + 2;
    final commented = Uint8List.fromList([
      ...original.take(2),
      0xff,
      0xfe,
      size >> 8,
      size & 255,
      ...marker,
      ...original.skip(2),
    ]);
    final trailing = Uint8List.fromList([...original, ...marker]);
    for (final bytes in [commented, trailing]) {
      expect(
        img.decodeJpg(bytes),
        isNotNull,
        reason: 'A real decodable fixture is required.',
      );
      expect(imageBytesAreMetadataFree(bytes), isFalse);
      final clean = validateCommunityPostImage(bytes);
      expect(
        latin1.decode(clean.bytes),
        isNot(contains('BIL_PRIVATE_COMMENT_MARKER')),
      );
      expect(imageBytesAreMetadataFree(clean.bytes), isTrue);
    }
  });

  test('PNG author text is removed without changing dimensions or alpha', () {
    final source = img.Image(width: 31, height: 17, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(40, 120, 180, 128));
    source.textData = {'Author': 'BIL_PRIVATE_AUTHOR_MARKER'};
    final bytes = Uint8List.fromList(img.encodePng(source));
    expect(
      img.decodePng(bytes)!.textData?['Author'],
      'BIL_PRIVATE_AUTHOR_MARKER',
    );
    expect(imageBytesAreMetadataFree(bytes), isFalse);
    final clean = validateCommunityPostImage(bytes);
    final decoded = img.decodeImage(clean.bytes)!;
    expect(decoded.textData, anyOf(isNull, isEmpty));
    expect((decoded.width, decoded.height), (31, 17));
    expect(decoded.getPixel(0, 0).a, 128);
    expect(imageBytesAreMetadataFree(clean.bytes), isTrue);
  });

  test(
    'pixel copies leave original metadata intact and remove invisible RGB',
    () {
      final source = img.Image(width: 2, height: 2, numChannels: 4);
      img.fill(source, color: img.ColorRgba8(40, 120, 180, 0));
      source.exif.gpsIfd.setGpsLocation(latitude: 12.34567, longitude: 45.6789);
      final transparent = privateImagePixels(source);
      expect(source.exif.gpsIfd.hasGPSLatitude, isTrue);
      expect(transparent.exif.gpsIfd.hasGPSLatitude, isFalse);
      expect(transparent.getPixel(0, 0).r, 0);
      expect(transparent.getPixel(0, 0).a, 0);
      final opaque = privateImagePixels(source, flattenAlpha: true);
      expect(opaque.hasAlpha, isFalse);
      expect(opaque.getPixel(0, 0).r, 255);
      expect(opaque.getPixel(0, 0).g, 255);
      expect(opaque.getPixel(0, 0).b, 255);
    },
  );
}
