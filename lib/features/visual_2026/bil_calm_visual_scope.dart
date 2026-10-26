import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/bil_pearl_finish.dart';
import '../../app/theme/bil_feedback_theme.dart';

/// BIL's 2026 editorial treatment for secondary, non-protected journeys.
///
/// This scope MUST be applied inside an individual allowed route, never to
/// MaterialApp, the shell, Dashboard, Community, or AI Coach. The Builder
/// deliberately supplies a descendant context so Theme.of(context) inside
/// the page is scoped too. No bundled fonts: system sans follows each OS,
/// script, accessibility setting, and installed fallback.
abstract final class BilCalmTokens {
  static const double pageInset = 16;
  static const double rowMinHeight = 52;
  static const double iconSize = 18;
  static const double iconHitTarget = 48;
  static const double cardRadius = 14;
  static const double fieldRadius = 12;
  static const double sectionGap = 20;
  static const double rowGap = 12;

  static const Color lightCanvas = BilPearlFinish.lightCanvas;
  static const Color lightSurface = BilPearlFinish.lightSurface;
  static const Color lightSubtle = BilPearlFinish.lightInset;
  static const Color lightInk = BilPearlFinish.lightInk;
  static const Color lightSecondary = BilPearlFinish.lightSecondary;
  static const Color lightBorder = BilPearlFinish.lightEdge;
  static const Color darkCanvas = BilPearlFinish.darkCanvas;
  static const Color darkSurface = BilPearlFinish.darkSurface;
  static const Color darkSubtle = BilPearlFinish.darkInset;
  static const Color darkInk = BilPearlFinish.darkInk;
  static const Color darkSecondary = BilPearlFinish.darkSecondary;
  static const Color darkBorder = BilPearlFinish.darkEdge;
}

class BilCalmVisualScope extends StatelessWidget {
  const BilCalmVisualScope({
    super.key,
    required this.builder,
    this.enabled = true,
  });

  final WidgetBuilder builder;
  final bool enabled;

  static ThemeData resolve(ThemeData parent, {required bool isArabic}) {
    final dark = parent.brightness == Brightness.dark;
    final canvas = dark ? BilCalmTokens.darkCanvas : BilCalmTokens.lightCanvas;
    final surface = dark
        ? BilCalmTokens.darkSurface
        : BilCalmTokens.lightSurface;
    final subtle = dark ? BilCalmTokens.darkSubtle : BilCalmTokens.lightSubtle;
    final ink = dark ? BilCalmTokens.darkInk : BilCalmTokens.lightInk;
    final secondary = dark
        ? BilCalmTokens.darkSecondary
        : BilCalmTokens.lightSecondary;
    final border = dark ? BilCalmTokens.darkBorder : BilCalmTokens.lightBorder;
    final scheme = parent.colorScheme.copyWith(
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: secondary,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: subtle,
      surfaceContainer: subtle,
      outlineVariant: border,
    );
    // Do not set fontFamily: preserve platform-native Arabic/Latin fallback.
    // Avoid negative letter spacing for Arabic's joined glyphs.
    final tracking = isArabic ? 0.0 : -0.15;
    TextStyle? style(
      TextStyle? source,
      double size,
      FontWeight weight, {
      double height = 1.36,
      double? spacing,
    }) => source?.copyWith(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing ?? tracking,
      color: ink,
    );
    final base = parent.textTheme;
    final typography = base.copyWith(
      headlineSmall: style(
        base.headlineSmall,
        22,
        FontWeight.w600,
        height: 1.24,
      ),
      titleLarge: style(base.titleLarge, 19, FontWeight.w600, height: 1.3),
      titleMedium: style(base.titleMedium, 16, FontWeight.w500),
      titleSmall: style(base.titleSmall, 14, FontWeight.w500),
      bodyLarge: style(base.bodyLarge, 16, FontWeight.w400, height: 1.5),
      bodyMedium: style(base.bodyMedium, 14, FontWeight.w400, height: 1.48),
      bodySmall: style(base.bodySmall, 12.5, FontWeight.w400, height: 1.45),
      labelLarge: style(base.labelLarge, 14, FontWeight.w500, height: 1.32),
      labelMedium: style(base.labelMedium, 12.5, FontWeight.w500),
      labelSmall: style(base.labelSmall, 11.5, FontWeight.w500),
    );
    return parent.copyWith(
      colorScheme: scheme,
      snackBarTheme: BilFeedbackTheme.resolve(scheme),
      // The page-owned opaque backdrop paints this canvas. Transparency here
      // reveals that gradient, never a previous route's text or account data.
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: typography,
      iconTheme: IconThemeData(color: secondary, size: BilCalmTokens.iconSize),
      appBarTheme: parent.appBarTheme.copyWith(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        // The app bar is transparent over a page-owned pearl backdrop. Its
        // alpha cannot determine the system glyph contrast for that surface.
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        foregroundColor: ink,
        centerTitle: true,
        titleTextStyle: typography.titleLarge,
        iconTheme: IconThemeData(
          color: secondary,
          size: BilCalmTokens.iconSize,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        color: surface,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BilCalmTokens.cardRadius),
          side: BorderSide(color: border, width: .75),
        ),
      ),
      dividerColor: border,
      dividerTheme: DividerThemeData(color: border, thickness: .75, space: 1),
      listTileTheme: ListTileThemeData(
        minTileHeight: BilCalmTokens.rowMinHeight,
        iconColor: secondary,
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        titleTextStyle: typography.bodyLarge,
        subtitleTextStyle: typography.bodyMedium?.copyWith(color: secondary),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(BilCalmTokens.iconHitTarget, BilCalmTokens.iconHitTarget),
          ),
          iconSize: const WidgetStatePropertyAll(BilCalmTokens.iconSize),
          foregroundColor: WidgetStatePropertyAll(secondary),
        ),
      ),
      inputDecorationTheme: parent.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 13, 14, 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BilCalmTokens.fieldRadius),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BilCalmTokens.fieldRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.25),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return Builder(builder: builder);
    final locale = Localizations.localeOf(context);
    return Theme(
      data: resolve(Theme.of(context), isArabic: locale.languageCode == 'ar'),
      child: Builder(
        builder: (context) => BilPearlBackdrop(child: builder(context)),
      ),
    );
  }
}
