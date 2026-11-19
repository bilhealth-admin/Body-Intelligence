import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/dart_library_source.dart';

void main() {
  test('an unverified recovered plan cannot be mutated via menu or save', () {
    final entrypoint = File(
      'lib/features/smart_plan/presentation/bil_smart_plan_page.dart',
    ).readAsStringSync();
    expect(
      entrypoint,
      contains("part 'bil_smart_plan_creation_validation.dart';"),
    );
    final source = readDartLibrarySource(
      'lib/features/smart_plan/presentation/bil_smart_plan_page.dart',
    );
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
    expect(entrypoint, contains('classifySmartPlanWriteFailure(error)'));
    expect(entrypoint, contains('_failureText(),'));
    expect(source, contains('return smartPlanLoadFailureMessage(code, _t);'));
    expect(entrypoint, isNot(contains('_error = error.toString();')));
  });
}
