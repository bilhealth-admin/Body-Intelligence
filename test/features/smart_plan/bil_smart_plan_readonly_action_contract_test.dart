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
    // A stale A→B→A save must not overwrite the current owner's UI.
    expect(source, contains('epoch != _ownerEpoch) return;'));
    // Repository errors must not be echoed to a member.
    expect(source, contains('classifySmartPlanWriteFailure(error)'));
    expect(source, isNot(contains('_error = error.toString();')));
  });
}
