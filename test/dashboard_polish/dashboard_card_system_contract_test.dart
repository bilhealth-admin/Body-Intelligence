import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'premium dashboard cards use one semantic geometry and elevation system',
    () {
      final tokens = File(
        'lib/app/theme/premium_design_tokens.dart',
      ).readAsStringSync();
      final surface = File(
        'lib/shared/widgets/premium_surface.dart',
      ).readAsStringSync();

      for (final contract in <String>[
        'dashboardCardBorderWidth = 1',
        'dashboardCardHoverScale = 1.004',
        'dashboardCardPressedScale = .992',
        'dashboardCardShadowBlur = 22',
        'dashboardCardShadowOffsetY = 10',
        'dashboardCardAccentBlur = 28',
        'dashboardCardInnerHighlightAlpha = .72',
        'dashboardCardRadius = BorderRadius.circular(radiusXl)',
        'dashboardCardBorderColor(',
        'dashboardCardShadowColor(',
        'dashboardCardAccentShadowColor(',
      ]) {
        expect(
          tokens,
          contains(contract),
          reason: 'Missing card token: $contract',
        );
      }

      for (final contract in <String>[
        'PremiumDesignTokens.dashboardCardRadius',
        'PremiumDesignTokens.dashboardCardPressedScale',
        'PremiumDesignTokens.dashboardCardHoverScale',
        'PremiumDesignTokens.dashboardCardBorderColor(',
        'PremiumDesignTokens.dashboardCardBorderWidth',
        'PremiumDesignTokens.dashboardCardAccentShadowColor(',
        'PremiumDesignTokens.dashboardCardAccentBlur',
        'PremiumDesignTokens.dashboardCardShadowColor(',
        'PremiumDesignTokens.dashboardCardShadowBlur',
        'PremiumDesignTokens.dashboardCardShadowOffsetY',
        'dashboardCardInnerHighlightAlpha',
      ]) {
        expect(
          surface,
          contains(contract),
          reason: 'Surface does not use: $contract',
        );
      }
    },
  );

  test('P5 stays inside presentation-level card primitives', () {
    final files = <String>[
      'lib/app/theme/premium_design_tokens.dart',
      'lib/shared/widgets/premium_surface.dart',
    ];
    final combined = files
        .map((path) => File(path).readAsStringSync())
        .join('\n');

    for (final forbidden in <String>[
      'Repository',
      'ProviderScope',
      'ref.watch',
      'ref.read',
      'Supabase',
      'DecisionEngine',
      'TruthEngine',
    ]) {
      expect(combined, isNot(contains(forbidden)));
    }
  });
}
