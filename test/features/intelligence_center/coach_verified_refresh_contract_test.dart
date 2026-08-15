import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trusted writes refresh every dependent UI provider', () {
    final source = File(
      'lib/features/intelligence_center/presentation/intelligence_center_page.dart',
    ).readAsStringSync();
    expect(source, contains('ref.invalidate(dailyMealsProvider)'));
    expect(source, contains('ref.invalidate(bodyMeasurementHistoryProvider)'));
    expect(source, contains('ref.invalidate(coachContextSnapshotProvider)'));
    expect(source, contains('ref.invalidate(userProfileProvider)'));
    expect(source, contains('ref.invalidate(activeGoalProvider)'));
  });

  test('model navigation resolves through the fixed registry only', () {
    final source = File(
      'lib/features/intelligence_center/presentation/intelligence_center_page.dart',
    ).readAsStringSync();
    expect(source, contains('BilNavigationRegistry().resolve(target)'));
    expect(source, isNot(contains("context.go(action.payload['route']")));
  });
}
