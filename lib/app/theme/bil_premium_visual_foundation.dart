import 'package:flutter/material.dart';

/// Canonical semantic visual foundation for the Premium UI epic.
///
/// Future premium work should consume these names instead of introducing new
/// local spacing, radius, border, or interaction constants.
abstract final class BilPremiumVisualFoundation {
  // Spacing rhythm.
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 20;
  static const double spaceXl = 24;

  // Surface geometry.
  static const double radiusMd = 12;
  static const double radiusLg = 14;
  static const double radiusXl = 16;
  static const double elevationNone = 0;

  // Interactive dashboard surfaces.
  static const double dashboardCardBorderWidth = 1;
  static const double dashboardCardHighContrastBorderWidth = 2;
  static const double dashboardCardHoverScale = 1.004;
  static const double dashboardCardPressedScale = .992;
  static const double dashboardCardShadowBlur = 12;
  static const double dashboardCardShadowOffsetY = 4;
  static const double dashboardCardAccentBlur = 14;
  static const double dashboardCardInnerHighlightAlpha = .38;

  static const EdgeInsets screenPadding = EdgeInsets.all(spaceMd);
  static const EdgeInsets cardPadding = EdgeInsets.all(spaceMd);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(spaceLg);

  static final BorderRadius cardRadius = BorderRadius.circular(radiusLg);
  static final BorderRadius dashboardCardRadius = BorderRadius.circular(
    radiusXl,
  );
  static final BorderRadius inputRadius = BorderRadius.circular(radiusMd);
  static final BorderRadius dialogRadius = BorderRadius.circular(radiusXl);

  static Color cardBorderColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFF26364E)
      : const Color(0xFFE5E5EA);

  static Color dashboardCardBorderColor(
    Brightness brightness, {
    bool hovered = false,
  }) => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: hovered ? .22 : .14)
      : const Color(0xFFE1E2E7).withValues(alpha: hovered ? 1 : .86);

  static Color dashboardCardShadowColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? Colors.black.withValues(alpha: .20)
      : Colors.black.withValues(alpha: .07);

  static Color dashboardCardAccentShadowColor(
    Brightness brightness, {
    bool hovered = false,
    bool emphasized = false,
  }) => const Color(0xFF0877D1).withValues(
    alpha: brightness == Brightness.light
        ? (hovered ? .08 : .035)
        : emphasized
        ? (hovered ? .18 : .12)
        : (hovered ? .10 : .05),
  );

  static Color inputBorderColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFF31415A)
      : const Color(0xFFD9DAE0);
}
