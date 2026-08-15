import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_locale_names.dart';
import 'package:body_intelligence_log/features/settings/language_settings_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('More language entry is explicit and routes to exact selector', () {
    final source = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    expect(source, contains("Key('more-language-entry')"));
    final entry = source.substring(
      source.indexOf("Key('more-language-entry')") - 120,
    );
    expect(
      entry.substring(0, entry.indexOf('),') + 2),
      isNot(contains('leading:')),
    );
    expect(source, contains("'/settings/language'"));
    expect(source, isNot(contains('toLanguageTag()')));
    expect(source, contains('minTileHeight: 58'));
  });

  test('language selector exposes exactly 25 canonical tags', () {
    expect(BilLocaleNames.native.length, 25);
    expect(BilLocaleNames.native.keys, containsAll(['ar', 'ur', 'fa']));
    expect(BilLocaleNames.native.keys, containsAll(['pt-BR', 'pt-PT']));
    expect(BilLocaleNames.native.keys, containsAll(['zh-Hans', 'zh-Hant']));
    expect(BilLocaleNames.native.values.join(), isNot(contains('Ã')));
  });

  test('dedicated selector preserves owner-specified deterministic order', () {
    expect(LanguageSettingsPage.orderedTags.length, 25);
    expect(LanguageSettingsPage.orderedTags.take(6), [
      'ar',
      'en',
      'fr',
      'es',
      'tr',
      'de',
    ]);
    expect(LanguageSettingsPage.orderedTags.toSet().length, 25);
  });
}
