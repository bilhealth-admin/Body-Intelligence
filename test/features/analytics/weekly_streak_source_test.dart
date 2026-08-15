import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final asOf = DateTime.utc(2026, 8, 13);

  test('empty diary is a zero-day streak', () {
    expect(computeWeeklyLoggingStreak(asOf, const {}), 0);
  });

  test('three consecutive repository days produce three', () {
    expect(
      computeWeeklyLoggingStreak(asOf, {
        for (var offset = 0; offset < 3; offset++)
          dayKeyFor(asOf.subtract(Duration(days: offset))),
      }),
      3,
    );
  });

  test('nine consecutive repository days produce nine', () {
    expect(
      computeWeeklyLoggingStreak(asOf, {
        for (var offset = 0; offset < 9; offset++)
          dayKeyFor(asOf.subtract(Duration(days: offset))),
      }),
      9,
    );
  });

  test('a gap stops the streak instead of counting older activity', () {
    expect(
      computeWeeklyLoggingStreak(asOf, {
        dayKeyFor(asOf),
        dayKeyFor(asOf.subtract(const Duration(days: 2))),
      }),
      1,
    );
  });
}
