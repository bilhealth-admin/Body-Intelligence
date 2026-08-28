import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress history uses one complete five-locale copy contract', () {
    final page = File(
      'lib/features/history/history_page.dart',
    ).readAsStringSync();
    final components = File(
      'lib/features/history/widgets/history_page_components.dart',
    ).readAsStringSync();

    for (final locale in const ['ar', 'en', 'fr', 'es', 'tr']) {
      expect(page, contains("'$locale': {"), reason: locale);
    }
    expect(page, isNot(contains('final arabic =')));
    expect(page, isNot(contains('bool arabic')));
    expect(components, isNot(contains('final arabic =')));
    expect(components, isNot(contains('bool arabic')));
    expect(components, contains("_historyText(locale, 'goalTitle')"));
    expect(components, contains("_historyText(locale, 'showRaw')"));
  });

  test('global quick add has no binary locale escape hatch', () {
    final sheet = File(
      'lib/app/router/bil_quick_add_sheet.dart',
    ).readAsStringSync();
    final copy = File(
      'lib/app/router/bil_quick_add_locale_copy.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();

    expect(sheet, isNot(contains('final bool arabic')));
    expect(copy, contains("'Daily notes': {"));
    expect(copy, contains("'Search or create food': {"));
    expect(shell, isNot(contains('arabic: arabic')));
  });
}
