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
  static BorderRadius inputRadius = BorderRadius.circular(radiusMd);
  static BorderRadius dialogRadius = BorderRadius.circular(radiusXl);

  static Color cardBorderColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFF26364E)
      : const Color(0xFFE3EAF3);

  static Color inputBorderColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFF31415A)
      : const Color(0xFFD8E1ED);
}
