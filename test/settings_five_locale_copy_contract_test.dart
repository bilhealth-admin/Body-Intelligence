import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('location settings owns complete five-locale copy', () {
    final source = File(
      'lib/features/settings/location_settings_page.dart',
    ).readAsStringSync();

    for (final locale in const ['ar', 'en', 'fr', 'es', 'tr']) {
      expect(source, contains("'$locale': {"), reason: locale);
    }
    expect(source, isNot(contains('bool get arabic')));
    expect(source, isNot(contains('arabic ?')));
    expect(source, isNot(contains('? (arabic')));
  });

  test('all three legal documents have authored copy in five locales', () {
    final source = File(
      'lib/features/settings/legal_document_page.dart',
    ).readAsStringSync();

    for (final locale in const ['ar', 'en', 'fr', 'es', 'tr']) {
      expect(source, contains("'$locale': _LegalPageCopy("), reason: locale);
    }
    for (final suffix in const ['', 'Ar', 'Fr', 'Es', 'Tr']) {
      expect(source, contains('_privacySections$suffix'));
      expect(source, contains('_termsSections$suffix'));
      expect(source, contains('_healthDisclaimerSections$suffix'));
    }
    expect(source, isNot(contains('final arabic =')));
  });
}
