import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete-meal action requests meal-focused diary context', () {
    final dashboard = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final diary = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();
    final mealEntry = File(
      'lib/features/daily_log/daily_log_meal_entry.dart',
    ).readAsStringSync();

    expect(
      dashboard,
      contains(
        "context.go('/daily-log?meal=breakfast&focus=meal&from=%2Fdashboard')",
      ),
    );
    expect(
      router,
      contains("focusMealEntry: state.uri.queryParameters['focus'] == 'meal'"),
    );
    expect(diary, contains('Scrollable.ensureVisible('));
    expect(mealEntry, contains('key: mealEntryKey'));
    expect(diary, contains('this.focusMealEntry = false'));
    expect(diary, contains('if (!widget.focusMealEntry) ...['));
    expect(diary, contains('if (widget.focusMealEntry && !mealFocusApplied)'));
    expect(diary, contains('addPostFrameCallback((_) => _focusMealEntry())'));
  });
}
