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

  test('dashboard delegates responsive decisions to one policy', () {
    final source = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();

    for (final contract in <String>[
      'BilPremiumResponsiveLayout.isPhone(',
      'BilPremiumResponsiveLayout.sectionGap(',
      'BilPremiumResponsiveLayout.twinBaseHeight(',
      'BilPremiumResponsiveLayout.usesSplitHero(',
      'BilPremiumResponsiveLayout.pairsDaySections(',
      'BilPremiumResponsiveLayout.dayPairHeight',
    ]) {
      expect(source, contains(contract), reason: contract);
    }

    expect(source, isNot(contains('constraints.maxWidth < 1180')));
    expect(source, isNot(contains('constraints.maxWidth >= 1400')));
  });
}
