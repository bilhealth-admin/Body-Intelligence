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
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      benchmark,
      contains('title: tr("Today\'s Insights", "رؤى اليوم")'),
      reason: 'Today’s Insights must use the approved Arabic title.',
    );

    expect(
      grid,
      isNot(contains("tr('Unavailable', 'غير متاح')")),
      reason: 'The visible generic unavailable phrase must be removed.',
    );
    expect(
      grid,
      contains("null => '—'"),
      reason: 'Unavailable body-composition fallback must be a dash.',
    );

    expect(grid, contains("tr('Daily energy plan', 'خطة الطاقة اليومية')"));
    expect(grid, contains("tr('Daily metabolism', 'معدل الأيض اليومي')"));
    expect(
      grid,
      contains('calorieTarget: effectiveTargets.calories.toString()'),
    );
    expect(grid, contains('dailyMetabolism: bil.tdee.round().toString()'));

    final dailyRequirementMetric = RegExp(
      r"tr\('Daily Requirement', 'الاحتياج اليومي'\),\s*bil\.tdee\.round\(\)\.toString\(\),\s*''",
      multiLine: true,
    );
    expect(
      grid,
      matches(dailyRequirementMetric),
      reason:
          'Daily requirement must show the number without kcal/day wording.',
    );
    expect(grid, isNot(contains("arabic ? 'سعرة/يوم' : 'kcal/day'")));

    expect(health, contains('bil_health_hub_watch.webp'));
    expect(
      pubspec,
      contains('assets/images/dashboard/bil_health_hub_watch.webp'),
    );
  });
}
