import 'package:body_intelligence_log/app/localization/runtime_copy_profile_photo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared camera controls have reviewed copy in all 25 locales', () {
    const sources = <String>{
      'Toggle flash',
      'Camera unavailable',
      'Retry',
      'Capture',
    };

    expect(ProfilePhotoRuntimeCopy.supported, hasLength(25));
    for (final source in sources) {
      final translations = ProfilePhotoRuntimeCopy.values[source];
      expect(translations, isNotNull, reason: 'Missing camera copy: $source');
      expect(translations!.keys.toSet(), ProfilePhotoRuntimeCopy.supported);
      expect(
        translations.values.every((value) => value.trim().isNotEmpty),
        isTrue,
      );
    }
  });
}
