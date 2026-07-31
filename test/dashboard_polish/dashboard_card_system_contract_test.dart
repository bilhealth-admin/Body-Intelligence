import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'premium dashboard cards use one semantic geometry and elevation system',
    () {
      final foundation = File(
        'lib/app/theme/bil_premium_visual_foundation.dart',
      ).readAsStringSync();
      final facade = File(
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
        'dashboardCardBorderColor(',
        'dashboardCardShadowColor(',
        'dashboardCardAccentShadowColor(',
      ]) {
        expect(
          foundation,
          contains(contract),
          reason: 'Missing card token: $contract',
        );
      }

      expect(
        foundation,
        contains('dashboardCardRadius = BorderRadius.circular('),
      );
      expect(foundation, contains('radiusXl,'));

      for (final contract in <String>[
        'BilPremiumVisualFoundation.dashboardCardBorderWidth',
        'BilPremiumVisualFoundation.dashboardCardHoverScale',
        'BilPremiumVisualFoundation.dashboardCardPressedScale',
        'BilPremiumVisualFoundation.dashboardCardShadowBlur',
        'BilPremiumVisualFoundation.dashboardCardShadowOffsetY',
        'BilPremiumVisualFoundation.dashboardCardAccentBlur',
        'BilPremiumVisualFoundation.dashboardCardInnerHighlightAlpha',
        'BilPremiumVisualFoundation.dashboardCardRadius',
      ]) {
        expect(
          facade,
          contains(contract),
          reason: 'Compatibility facade does not delegate: $contract',
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
      'lib/app/theme/bil_premium_visual_foundation.dart',
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
