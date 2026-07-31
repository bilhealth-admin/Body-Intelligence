import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contextual encouragement counts only consecutive local days', () {
    expect(
      consecutiveLoggingDays({
        '2026-07-19',
        '2026-07-18',
        '2026-07-17',
        '2026-07-15',
      }, DateTime(2026, 7, 19)),
      3,
    );
    expect(consecutiveLoggingDays({'2026-07-18'}, DateTime(2026, 7, 19)), 0);
  });
}
