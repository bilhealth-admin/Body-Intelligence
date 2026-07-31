import 'package:flutter/material.dart';

import 'bil_premium_visual_foundation.dart';

/// Backward-compatible dashboard token facade.
///
/// Canonical values are owned by [BilPremiumVisualFoundation]. Existing
/// consumers keep this API so the foundation package causes no visual or
/// behavioral change.
abstract final class PremiumDesignTokens {
  static const double spaceXs = BilPremiumVisualFoundation.spaceXs;
  static const double spaceSm = BilPremiumVisualFoundation.spaceSm;
  static const double spaceMd = BilPremiumVisualFoundation.spaceMd;
  static const double spaceLg = BilPremiumVisualFoundation.spaceLg;
  static const double spaceXl = BilPremiumVisualFoundation.spaceXl;

  static const double radiusMd = BilPremiumVisualFoundation.radiusMd;
  static const double radiusLg = BilPremiumVisualFoundation.radiusLg;
  static const double radiusXl = BilPremiumVisualFoundation.radiusXl;
  static const double elevationNone = BilPremiumVisualFoundation.elevationNone;

  static const double dashboardCardBorderWidth =
      BilPremiumVisualFoundation.dashboardCardBorderWidth;
  static const double dashboardCardHoverScale =
      BilPremiumVisualFoundation.dashboardCardHoverScale;
  static const double dashboardCardPressedScale =
      BilPremiumVisualFoundation.dashboardCardPressedScale;
  static const double dashboardCardShadowBlur =
      BilPremiumVisualFoundation.dashboardCardShadowBlur;
  static const double dashboardCardShadowOffsetY =
      BilPremiumVisualFoundation.dashboardCardShadowOffsetY;
  static const double dashboardCardAccentBlur =
      BilPremiumVisualFoundation.dashboardCardAccentBlur;
  static const double dashboardCardInnerHighlightAlpha =
      BilPremiumVisualFoundation.dashboardCardInnerHighlightAlpha;

  static TextStyle? screenHeading(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall;

  static TextStyle? sectionHeading(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge;

  static TextStyle? cardHeading(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium;

  static const EdgeInsets screenPadding =
      BilPremiumVisualFoundation.screenPadding;
  static const EdgeInsets cardPadding = BilPremiumVisualFoundation.cardPadding;
  static const EdgeInsets cardPaddingLarge =
      BilPremiumVisualFoundation.cardPaddingLarge;

  static final BorderRadius cardRadius = BilPremiumVisualFoundation.cardRadius;
  static final BorderRadius dashboardCardRadius =
      BilPremiumVisualFoundation.dashboardCardRadius;
  static final BorderRadius inputRadius =
      BilPremiumVisualFoundation.inputRadius;
  static final BorderRadius dialogRadius =
      BilPremiumVisualFoundation.dialogRadius;

  static Color cardBorderColor(Brightness brightness) =>
      BilPremiumVisualFoundation.cardBorderColor(brightness);

  static Color dashboardCardBorderColor(
    Brightness brightness, {
    bool hovered = false,
  }) => BilPremiumVisualFoundation.dashboardCardBorderColor(
    brightness,
    hovered: hovered,
  );

  static Color dashboardCardShadowColor(Brightness brightness) =>
      BilPremiumVisualFoundation.dashboardCardShadowColor(brightness);

  static Color dashboardCardAccentShadowColor(
    Brightness brightness, {
    bool hovered = false,
    bool emphasized = false,
  }) => BilPremiumVisualFoundation.dashboardCardAccentShadowColor(
    brightness,
    hovered: hovered,
    emphasized: emphasized,
  );

  static Color inputBorderColor(Brightness brightness) =>
      BilPremiumVisualFoundation.inputBorderColor(brightness);
}
