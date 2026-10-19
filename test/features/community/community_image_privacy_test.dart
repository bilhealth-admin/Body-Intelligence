import 'dart:convert';
import 'dart:typed_data';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:body_intelligence_log/features/profile/services/profile_photo_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List taggedPhoto() {
  final image = img.Image(width: 80, height: 60);
  img.fill(image, color: img.ColorRgb8(40, 120, 180));
  image.exif.gpsIfd.setGpsLocation(latitude: 12.34567, longitude: 45.6789);
  image.exif.imageIfd.imageDescription = 'BIL_SYNTHETIC_PRIVATE_METADATA';
  final bytes = Uint8List.fromList(img.encodeJpg(image));
  expect(img.decodeJpg(bytes)!.exif.gpsIfd.hasGPSLatitude, isTrue);
  return bytes;
}

void expectPrivateMetadataRemoved(Uint8List bytes) {
  final output = img.decodeImage(bytes)!;
  expect(output.exif.gpsIfd.hasGPSLatitude, isFalse);
  expect(output.exif.imageIfd.imageDescription, isNull);
  expect(
    latin1.decode(bytes),
    isNot(contains('BIL_SYNTHETIC_PRIVATE_METADATA')),
  );
}

void main() {
  test('shared Community upload validation removes private image metadata', () {
    final image = validateCommunityPostImage(taggedPhoto());
    expectPrivateMetadataRemoved(image.bytes);
    expect(
      validateCommunityPostImage(image.bytes).bytes,
      orderedEquals(image.bytes),
      reason: 'Repeated validation must preserve a clean media manifest.',
    );
  });
  test(
    'async Community and Circle image validation removes metadata',
    () async {
      final image = await validateCommunityPostImageAsync(taggedPhoto());
      expectPrivateMetadataRemoved(image.bytes);
      final again = await validateCommunityPostImageAsync(image.bytes);
      expect(again.bytes, orderedEquals(image.bytes));
    },
  );
  test(
    'public-avatar preparation removes GPS before local save and upload',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final preferences = PreferencesRepository(database);
      final service = ProfilePhotoService(
        preferences,
        authenticatedOwnerId: () => null,
      );
      final saved = await service.save(
        taggedPhoto(),
        contentType: 'image/jpeg',
      );
      expectPrivateMetadataRemoved(saved.bytes);
      expectPrivateMetadataRemoved(
        base64Decode((await preferences.get('profilePhoto'))!),
      );
    },
  );
  test(
    'draft preview does not retain private EXIF from a legacy original',
    () async {
      final bytes = taggedPhoto();
      final preview = await createCommunityPostImagePreviewAsync(
        bytes,
        expectedMimeType: 'image/jpeg',
        expectedByteLength: bytes.length,
        expectedWidth: 80,
        expectedHeight: 60,
      );
      expectPrivateMetadataRemoved(preview.bytes);
    },
  );
}
