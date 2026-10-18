import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Quick Add voice and meal-photo actions keep flagship treatment', () {
    final source = File(
      'lib/app/router/bil_quick_add_sheet.dart',
    ).readAsStringSync();

    expect(source, contains('baseTheme.colorScheme.onSurfaceVariant'));
    expect(source, contains('gradient: BilPearlFinish.panel('));
    expect(source, isNot(contains('premiumGradient')));
    expect(source, contains("Key('quick-add-primary-\$index')"));
    expect(source, contains("Key('quick-add-primary-badge-\$index')"));
    expect(source, contains("Key('quick-add-primary-icon-\$index')"));
    expect(source, contains('excludeFromSemantics: true'));
    expect(source, contains('excludeSemantics: true'));
    expect(source, contains('child: Ink('));
  });
}
