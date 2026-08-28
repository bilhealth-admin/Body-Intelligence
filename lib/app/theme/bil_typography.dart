import 'package:flutter/material.dart';

/// Canonical typography for the BIL visual system.
///
/// This class owns the product's typographic hierarchy. Screens and widgets
/// should consume [Theme.of(context).textTheme] instead of constructing
/// ad-hoc [TextStyle] instances.
abstract final class BilTypography {
  static TextTheme build({
    required TextTheme base,
    required Color foreground,
    required bool isArabic,
  }) {
    // Keep the family unset for every locale. This lets iOS use San Francisco
    // and Android use its modern system sans Arabic instead of forcing the
    // editorial Naskh asset across controls, cards, and navigation.
    const String? displayFamily = null;
    const String? bodyFamily = null;

    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontFamily: displayFamily,
            fontSize: 52,
            height: 1.02,
            fontWeight: FontWeight.w700,
            letterSpacing: isArabic ? -0.6 : -2.2,
          ),
          displayMedium: base.displayMedium?.copyWith(
            fontFamily: displayFamily,
            fontSize: 42,
            height: 1.04,
            fontWeight: FontWeight.w700,
            letterSpacing: isArabic ? -0.45 : -1.7,
          ),
          displaySmall: base.displaySmall?.copyWith(
            fontFamily: displayFamily,
            fontSize: 34,
            height: 1.08,
            fontWeight: FontWeight.w700,
            letterSpacing: isArabic ? -0.3 : -1.15,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontFamily: displayFamily,
            fontSize: 30,
            height: 1.12,
            fontWeight: FontWeight.w700,
            letterSpacing: isArabic ? -0.2 : -0.75,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontFamily: displayFamily,
            fontSize: 26,
            height: 1.16,
            fontWeight: FontWeight.w700,
            letterSpacing: isArabic ? -0.1 : -0.5,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontFamily: displayFamily,
            fontSize: 22,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: isArabic ? 0 : -0.25,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontFamily: displayFamily,
            fontSize: 21,
            height: 1.26,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontFamily: displayFamily,
            fontSize: 17,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: base.titleSmall?.copyWith(
            fontFamily: displayFamily,
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: base.bodyLarge?.copyWith(
            fontFamily: bodyFamily,
            fontSize: 17,
            height: 1.55,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            fontFamily: bodyFamily,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: base.bodySmall?.copyWith(
            fontFamily: bodyFamily,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontFamily: bodyFamily,
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: isArabic ? 0 : 0.1,
          ),
          labelMedium: base.labelMedium?.copyWith(
            fontFamily: bodyFamily,
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontFamily: bodyFamily,
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: foreground, displayColor: foreground);
  }

  /// Responsive typography for compact windows and mobile layouts.
  static TextTheme compact({
    required TextTheme base,
    required Color foreground,
    required bool isArabic,
  }) {
    return build(
      base: base,
      foreground: foreground,
      isArabic: isArabic,
    ).copyWith(
      displayLarge: build(
        base: base,
        foreground: foreground,
        isArabic: isArabic,
      ).displayLarge?.copyWith(fontSize: 40),
      displayMedium: build(
        base: base,
        foreground: foreground,
        isArabic: isArabic,
      ).displayMedium?.copyWith(fontSize: 34),
      displaySmall: build(
        base: base,
        foreground: foreground,
        isArabic: isArabic,
      ).displaySmall?.copyWith(fontSize: 30),
      headlineLarge: build(
        base: base,
        foreground: foreground,
        isArabic: isArabic,
      ).headlineLarge?.copyWith(fontSize: 28),
    );
  }
}
