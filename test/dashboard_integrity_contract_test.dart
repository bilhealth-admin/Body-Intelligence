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
    final source = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    for (final label in const <String>[
      'تقدم اليوم',
      'السعرات',
      'البروتين',
      'الدهون',
      'الألياف',
      'التحليلات',
      'ملف الجسم والخطة',
    ]) {
      expect(source, contains(label), reason: 'Missing Arabic label: $label');
    }
  });

  test('connected health is additive and Personal Health AI stays intact', () {
    final dashboard = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    expect(dashboard, contains('PersonalHealthAiPanel('));
    expect(dashboard, contains('ConnectedHealthCard('));
    expect(dashboard, contains('personalHealthAi: personalHealthAiPanel'));
    expect(dashboard, contains('connectedHealth: ConnectedHealthCard('));

    expect(benchmark, contains('this.personalHealthAi'));
    expect(benchmark, contains('this.connectedHealth'));
    expect(benchmark, contains('final Widget? personalHealthAi;'));
    expect(benchmark, contains('final Widget? connectedHealth;'));
    expect(benchmark, contains('personalHealthAi!'));
    expect(benchmark, contains('connectedHealth!'));

    final personalIndex = benchmark.indexOf('personalHealthAi!');
    final connectedIndex = benchmark.indexOf('connectedHealth!');
    expect(personalIndex, greaterThanOrEqualTo(0));
    expect(connectedIndex, greaterThan(personalIndex));
  });
}
