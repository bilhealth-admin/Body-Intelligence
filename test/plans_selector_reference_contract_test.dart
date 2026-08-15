import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plan selector uses stable BIL labels and selected product prices', () {
    final source = File(
      'lib/features/commerce/presentation/bil_store_plans_page.dart',
    ).readAsStringSync();

    expect(source, contains("const Text('BIL Plus')"));
    expect(source, contains("const Text('BIL Pro')"));
    expect(source, isNot(contains("context.strings.text('Plus')")));
    expect(source, isNot(contains("context.strings.text('Pro')")));
    expect(
      RegExp(r'productFor\(\s*selectedPlan').allMatches(source).length,
      greaterThanOrEqualTo(3),
    );
  });
}
