import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production weekly provider contains no reference fixture branch', () {
    final source = File(
      'lib/features/analytics/weekly_report_provider.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('BIL_WEEKLY_REFERENCE_FIXTURE')));
    expect(source, isNot(contains('weeklyReportReferenceFixture')));
    expect(source, isNot(contains('loggingStreakDays: 9')));
  });
}
