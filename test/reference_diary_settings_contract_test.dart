import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reference diary settings expose persisted functional subpages', () {
    final page = [
      'lib/features/settings/reference_preferences_pages.dart',
      'lib/features/settings/reference_preferences_controls.dart',
      'lib/features/settings/reference_preferences_numeric.dart',
      'lib/features/settings/reference_preferences_macros.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    for (final route in const [
      '/settings/diary/search-tab',
      '/settings/diary/sharing',
      '/settings/diary/meal-names',
    ]) {
      expect(router, contains(route));
      expect(page, contains(route));
    }
    for (final locale in const ["'ar'", "'en'", "'fr'", "'es'", "'tr'"]) {
      expect(page, contains(locale));
    }
    expect(page, contains('diary.defaultSearchTab'));
    expect(page, contains('diary.sharingKeySha256'));
    expect(page, contains('sha256.convert'));
    expect(page, contains("'diary.mealName.\$i'"));
  });

  test('new diary truth copy has direct extended-locale entries', () {
    for (final key in const [
      'Diary sharing is not available yet. Your diary remains private.',
      'Customize the four supported meal names. Empty slots are hidden from the diary.',
    ]) {
      final values = ExtendedRuntimeCopy.values[key];
      expect(values, isNotNull, reason: key);
      for (final locale in ExtendedRuntimeCopy.supported) {
        final value = values![locale]?.trim();
        expect(value, isNotNull, reason: '$key [$locale]');
        expect(value, isNotEmpty, reason: '$key [$locale]');
        expect(value, isNot(key), reason: '$key [$locale]');
      }
    }
  });
}
