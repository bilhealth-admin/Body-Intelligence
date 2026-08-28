import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      [
            'intelligence_center_page.dart',
            'intelligence_action_flow.dart',
            'intelligence_query_flow.dart',
          ]
          .map(
            (name) => File(
              'lib/features/intelligence_center/presentation/$name',
            ).readAsStringSync(),
          )
          .join('\n');

  test('trusted writes refresh every dependent UI provider', () {
    expect(source, contains('ref.invalidate(dailyMealsProvider)'));
    expect(source, contains('ref.invalidate(bodyMeasurementHistoryProvider)'));
    expect(source, contains('ref.invalidate(coachContextSnapshotProvider)'));
    expect(source, contains('ref.invalidate(userProfileProvider)'));
    expect(source, contains('ref.invalidate(activeGoalProvider)'));
  });

  test('model navigation resolves through the fixed registry only', () {
    expect(source, contains('BilNavigationRegistry().resolve(target)'));
    expect(source, isNot(contains("context.go(action.payload['route']")));
  });
}
