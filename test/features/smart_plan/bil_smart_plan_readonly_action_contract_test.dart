import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an unverified recovered plan cannot be mutated via menu or save', () {
    final source = File(
      'lib/features/smart_plan/presentation/bil_smart_plan_page.dart',
    ).readAsStringSync();
    expect(source, contains('bool get _unverifiedPlanReadOnly'));
    expect(source, contains('enabled: !readOnly'));
    expect(source, contains('if (_unverifiedPlanReadOnly &&'));
    expect(
      source,
      contains("throw StateError('smart_plan_catalog_unavailable');"),
    );
    expect(source, contains("'refresh', 'export', 'report'"));
  });
}
