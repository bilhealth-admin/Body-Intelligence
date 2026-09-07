import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dashboard composition keeps deterministic non-expansion containment',
    () {
      final source = File(
        'lib/features/dashboard/widgets/dashboard_grid.dart',
      ).readAsStringSync();

      expect(source, contains('PremiumDashboardBenchmark('));
      expect(source, contains('DailyReturnCard('));
      expect(
        source,
        isNot(
          contains(
            'child: ExpansionTile(\n'
            '            initiallyExpanded: false,\n'
            '            leading: const Icon(Icons.insights_outlined)',
          ),
        ),
      );
    },
  );

  test('approved Arabic dashboard labels remain readable', () {
    final grid = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final bodyProfile = File(
      'lib/features/dashboard/widgets/dashboard_body_profile_snapshot.dart',
    ).readAsStringSync();
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_summary_factory.dart',
    ).readAsStringSync();
    final analytics = File(
      'lib/features/analytics/analytics_page.dart',
    ).readAsStringSync();
    final source = '$grid\n$bodyProfile\n$summary\n$analytics';

    for (final label in const <String>[
      'ملخص اليوم',
      'السعرات',
      'البروتين',
      'الدهون',
      'الألياف',
      'التحليلات',
      'هوية الجسم',
    ]) {
      expect(source, contains(label), reason: 'Missing Arabic label: $label');
    }
  });

  test(
    'unified dashboard keeps retired intelligence cards out of active UI',
    () {
      final dashboard = File(
        'lib/features/dashboard/widgets/dashboard_grid.dart',
      ).readAsStringSync();
      final benchmark = File(
        'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
      ).readAsStringSync();

      expect(dashboard, contains('ConnectedHealthCard('));
      expect(dashboard, contains('connectedHealth: ConnectedHealthCard('));

      expect(benchmark, contains('this.personalHealthAi'));
      expect(benchmark, contains('this.connectedHealth'));
      expect(benchmark, contains('final Widget? personalHealthAi;'));
      expect(benchmark, contains('final Widget? connectedHealth;'));
      expect(benchmark, contains('hero: hero'));
      expect(benchmark, contains('aiCoach: aiCoach'));
      expect(benchmark, contains('dailyIntelligence: dailyIntelligence'));
      expect(benchmark, contains('connectedHealth: connectedHealth'));

      final current = File(
        'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
      ).readAsStringSync();
      expect(current, contains('dashboard-ai-coach-slot'));
      expect(current, contains('dashboard-daily-intelligence-slot'));
      expect(current, contains('dashboard-secondary-ai-coach-slot'));
      expect(current, isNot(contains('dashboard-personal-health-ai-slot')));
      expect(current, isNot(contains('dashboard-mobile-summary-card')));
      expect(current, contains('connectedHealth!,'));
    },
  );
}
