import 'dart:io';

import 'package:body_intelligence_log/app/theme/bil_premium_responsive_layout.dart';
import 'package:body_intelligence_log/app/theme/premium_design_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('responsive boundaries are deterministic at every transition', () {
    expect(BilPremiumResponsiveLayout.isPhone(599), isTrue);
    expect(BilPremiumResponsiveLayout.isPhone(600), isFalse);

    expect(
      BilPremiumResponsiveLayout.sectionGap(899),
      PremiumDesignTokens.spaceMd,
    );
    expect(BilPremiumResponsiveLayout.sectionGap(900), 12);

    expect(BilPremiumResponsiveLayout.usesSplitHero(1179), isFalse);
    expect(BilPremiumResponsiveLayout.usesSplitHero(1180), isTrue);

    expect(BilPremiumResponsiveLayout.pairsDaySections(1399), isFalse);
    expect(BilPremiumResponsiveLayout.pairsDaySections(1400), isTrue);
  });

  test('dashboard keeps one complete adaptive tree at every width', () {
    final source = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();
    final current = File(
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    ).readAsStringSync();

    for (final contract in <String>[
      "Key('dashboard-unified-adaptive-layout')",
      "Key('dashboard-current-content-rail')",
      'constraints: const BoxConstraints(maxWidth: 840)',
    ]) {
      expect(source, contains(contract), reason: contract);
    }

    expect(current, contains("Key('dashboard-ai-coach-slot')"));
    expect(current, contains("Key('dashboard-daily-intelligence-slot')"));
    expect(
      current,
      isNot(contains("Key('dashboard-personal-health-ai-slot')")),
    );
    expect(current, isNot(contains("Key('dashboard-mobile-summary-card')")));
    expect(source, isNot(contains('if (constraints.maxWidth >= 600)')));
    expect(source, isNot(contains('constraints.maxWidth < 1180')));
    expect(source, isNot(contains('constraints.maxWidth >= 1400')));
  });
}
