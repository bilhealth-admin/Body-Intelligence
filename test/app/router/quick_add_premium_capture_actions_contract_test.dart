import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Quick Add voice and meal-photo actions keep flagship treatment', () {
    final source = File(
      'lib/app/router/bil_quick_add_sheet.dart',
    ).readAsStringSync();

    expect(source, contains('BilSemanticIconKind.voice => const <Color>['));
    expect(source, contains('Color(0xFF243B8F)'));
    expect(source, contains('Color(0xFF6D4AE8)'));
    expect(source, contains('BilSemanticIconKind.mealPhoto => const <Color>['));
    expect(source, contains('Color(0xFF075A8C)'));
    expect(source, contains('Color(0xFF0A84FF)'));
    expect(source, contains("Key('quick-add-primary-\$index')"));
    expect(source, contains("Key('quick-add-primary-badge-\$index')"));
    expect(source, contains("Key('quick-add-primary-icon-\$index')"));
    expect(source, contains('excludeFromSemantics: true'));
    expect(source, contains('excludeSemantics: true'));
    expect(source, contains('child: Ink('));
  });
}
