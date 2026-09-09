import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P8 keeps approved components but omits retired production cards', () {
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();
    final current = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    ).readAsStringSync();
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_summary_factory.dart',
    ).readAsStringSync();
    final health = <String>[
      'lib/features/connected_health/widgets/connected_health_card.dart',
      'lib/features/connected_health/widgets/health_hub_empty_state.dart',
      'lib/features/connected_health/widgets/live_health_watch.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final profile = File(
      'lib/features/dashboard/widgets/dashboard_body_profile_snapshot.dart',
    ).readAsStringSync();

    expect(
      '$benchmark\n$current\n$summary',
      contains("tr('Daily Summary', 'ملخص اليوم')"),
      reason: 'Today Summary must use the approved Arabic title.',
    );
    expect(current, isNot(contains("Key('dashboard-mobile-summary-card')")));
    expect(grid, isNot(contains('DashboardSummaryFactory.build(')));
    expect(grid, isNot(contains('PersonalHealthAiPanel(')));
    expect(grid, isNot(contains('progressSection:')));
    expect(grid, isNot(contains('personalHealthAi:')));

    expect(profile, contains("tr('Daily energy plan', 'خطة الطاقة اليومية')"));
    expect(profile, contains("tr('Daily metabolism', 'معدل الأيض اليومي')"));
    expect(summary, contains("tr('Daily Requirement', 'الاحتياج اليومي')"));
    expect(grid, isNot(contains("arabic ? 'سعرة/يوم' : 'kcal/day'")));

    expect(health, contains("Key('bil-live-health-watch')"));
    expect(health, contains('CustomPaint('));
  });
}
