import 'package:flutter/material.dart';

/// Canonical semantic design tokens for Phase 3 Epic 2.
class PremiumDesignTokens {
  const PremiumDesignTokens._();

  // Spacing
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 20;
  static const double spaceXl = 24;

  // Radius
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 24;

  // Elevation
  static const double elevationNone = 0;

  // Premium card system
  static const double dashboardCardBorderWidth = 1;
  static const double dashboardCardHoverScale = 1.004;
  static const double dashboardCardPressedScale = .992;
  static const double dashboardCardShadowBlur = 22;
  static const double dashboardCardShadowOffsetY = 10;
  static const double dashboardCardAccentBlur = 28;
  static const double dashboardCardInnerHighlightAlpha = .72;

  // Type scale aliases (semantic intent)
  static TextStyle? screenHeading(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall;

  static TextStyle? sectionHeading(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge;

  static TextStyle? cardHeading(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium;

  static EdgeInsets screenPadding = const EdgeInsets.all(spaceMd);
  static EdgeInsets cardPadding = const EdgeInsets.all(spaceMd);
  static EdgeInsets cardPaddingLarge = const EdgeInsets.all(spaceLg);

  static BorderRadius cardRadius = BorderRadius.circular(radiusLg);
  static BorderRadius dashboardCardRadius = BorderRadius.circular(radiusXl);
  static BorderRadius inputRadius = BorderRadius.circular(radiusMd);
  static BorderRadius dialogRadius = BorderRadius.circular(radiusXl);

  static Color cardBorderColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFF26364E)
      : const Color(0xFFE3EAF3);

  static Color dashboardCardBorderColor(
    Brightness brightness, {
    bool hovered = false,
  }) => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: hovered ? .22 : .14)
      : const Color(0xFFBFD8F4).withValues(alpha: hovered ? .92 : .68);

  static Color dashboardCardShadowColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? Colors.black.withValues(alpha: .20)
      : const Color(0xFF315D88).withValues(alpha: .14);

  static Color dashboardCardAccentShadowColor(
    Brightness brightness, {
    bool hovered = false,
    bool emphasized = false,
  }) => const Color(0xFF3287D8).withValues(
    alpha: brightness == Brightness.light
        ? (hovered ? .18 : .10)
        : emphasized
        ? (hovered ? .22 : .15)
        : (hovered ? .12 : .07),
  );

  static Color inputBorderColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFF31415A)
      : const Color(0xFFD8E1ED);
}
