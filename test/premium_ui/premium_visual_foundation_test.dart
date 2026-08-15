import 'package:body_intelligence_log/app/theme/bil_premium_visual_foundation.dart';
import 'package:body_intelligence_log/app/theme/premium_design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premium compatibility tokens preserve accepted geometry', () {
    expect(PremiumDesignTokens.spaceXs, 8);
    expect(PremiumDesignTokens.spaceSm, 12);
    expect(PremiumDesignTokens.spaceMd, 16);
    expect(PremiumDesignTokens.spaceLg, 20);
    expect(PremiumDesignTokens.spaceXl, 24);
    expect(PremiumDesignTokens.radiusMd, 12);
    expect(PremiumDesignTokens.radiusLg, 14);
    expect(PremiumDesignTokens.radiusXl, 16);
    expect(PremiumDesignTokens.cardPadding, const EdgeInsets.all(16));
    expect(PremiumDesignTokens.cardPaddingLarge, const EdgeInsets.all(20));
  });

  test('premium facade delegates to one canonical visual foundation', () {
    expect(
      PremiumDesignTokens.dashboardCardPressedScale,
      BilPremiumVisualFoundation.dashboardCardPressedScale,
    );
    expect(
      PremiumDesignTokens.dashboardCardHoverScale,
      BilPremiumVisualFoundation.dashboardCardHoverScale,
    );
    expect(
      PremiumDesignTokens.dashboardCardRadius,
      BilPremiumVisualFoundation.dashboardCardRadius,
    );

    for (final brightness in Brightness.values) {
      expect(
        PremiumDesignTokens.cardBorderColor(brightness),
        BilPremiumVisualFoundation.cardBorderColor(brightness),
      );
      expect(
        PremiumDesignTokens.inputBorderColor(brightness),
        BilPremiumVisualFoundation.inputBorderColor(brightness),
      );
      expect(
        PremiumDesignTokens.dashboardCardShadowColor(brightness),
        BilPremiumVisualFoundation.dashboardCardShadowColor(brightness),
      );
    }
  });
}
