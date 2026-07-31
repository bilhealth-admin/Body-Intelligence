import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P8 approved Arabic copy and compact values are present', () {
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();
    final health = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/features/dashboard/widgets/dashboard_body_profile_snapshot.dart',
    ).readAsStringSync();

    expect(
      benchmark,
      contains('title: tr("Today\'s Insights", "رؤى اليوم")'),
      reason: 'Today’s Insights must use the approved Arabic title.',
    );

    expect(profile, contains("tr('Daily energy plan', 'خطة الطاقة اليومية')"));
    expect(profile, contains("tr('Daily metabolism', 'معدل الأيض اليومي')"));
    expect(
      grid,
      contains("calorieTarget: '\${effectiveTargets.calories} kcal'"),
    );
    expect(grid, contains("dailyMetabolism: '\${bil.tdee.round()} kcal'"));
    expect(grid, contains("tr('Daily Requirement', 'الاحتياج اليومي')"));
    expect(grid, isNot(contains("arabic ? 'سعرة/يوم' : 'kcal/day'")));

    expect(health, contains("Key('bil-live-health-watch')"));
    expect(health, contains('CustomPaint('));
  });
}
