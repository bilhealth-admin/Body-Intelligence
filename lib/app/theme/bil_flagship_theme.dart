import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'bil_flagship_tokens.dart';
import 'bil_typography.dart';
import 'premium_design_tokens.dart';

abstract final class BilFlagshipTheme {
  static ThemeData light({bool highContrast = false, bool isArabic = false}) {
    return _build(
      brightness: Brightness.light,
      highContrast: highContrast,
      isArabic: isArabic,
    );
  }

  static ThemeData dark({bool highContrast = false, bool isArabic = false}) {
    return _build(
      brightness: Brightness.dark,
      highContrast: highContrast,
      isArabic: isArabic,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required bool highContrast,
    required bool isArabic,
  }) {
    final dark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: BilFlagshipTokens.cyan500,
      onPrimary: Colors.white,
      primaryContainer: dark
          ? BilFlagshipTokens.navy800
          : const Color(0xFFD9F8FD),
      onPrimaryContainer: dark
          ? BilFlagshipTokens.textPrimaryDark
          : BilFlagshipTokens.navy900,
      secondary: BilFlagshipTokens.blue500,
      onSecondary: Colors.white,
      secondaryContainer: dark
          ? const Color(0xFF142A50)
          : const Color(0xFFE4EDFF),
      onSecondaryContainer: dark
          ? BilFlagshipTokens.textPrimaryDark
          : BilFlagshipTokens.navy900,
      tertiary: BilFlagshipTokens.emerald500,
      onTertiary: Colors.white,
      tertiaryContainer: dark
          ? const Color(0xFF10382E)
          : const Color(0xFFD9FBEF),
      onTertiaryContainer: dark
          ? BilFlagshipTokens.textPrimaryDark
          : const Color(0xFF073B2E),
      error: BilFlagshipTokens.red500,
      onError: Colors.white,
      errorContainer: dark ? const Color(0xFF4A1F26) : const Color(0xFFFFE1E5),
      onErrorContainer: dark ? Colors.white : const Color(0xFF5A111A),
      surface: dark
          ? BilFlagshipTokens.surfaceDark
          : BilFlagshipTokens.surfaceLight,
      onSurface: dark
          ? BilFlagshipTokens.textPrimaryDark
          : BilFlagshipTokens.textPrimaryLight,
      surfaceContainerHighest: dark
          ? BilFlagshipTokens.surfaceMutedDark
          : BilFlagshipTokens.surfaceMutedLight,
      onSurfaceVariant: dark
          ? BilFlagshipTokens.textSecondaryDark
          : BilFlagshipTokens.textSecondaryLight,
      outline: dark
          ? BilFlagshipTokens.outlineDark
          : BilFlagshipTokens.outlineLight,
      outlineVariant: dark
          ? BilFlagshipTokens.outlineDark.withValues(alpha: .72)
          : BilFlagshipTokens.outlineLight.withValues(alpha: .82),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: dark
          ? BilFlagshipTokens.surfaceLight
          : BilFlagshipTokens.navy900,
      onInverseSurface: dark
          ? BilFlagshipTokens.textPrimaryLight
          : BilFlagshipTokens.textPrimaryDark,
      inversePrimary: BilFlagshipTokens.cyan400,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? BilFlagshipTokens.canvasDark
          : highContrast
          ? Colors.white
          : BilFlagshipTokens.canvasLight,
      visualDensity: VisualDensity.standard,
      focusColor: scheme.primary.withValues(alpha: .22),
      hoverColor: scheme.primary.withValues(alpha: .08),
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );

    // Use the native platform sans-serif stack for both scripts. iOS receives
    // San Francisco, Android its system sans Arabic, and Windows Segoe UI.
    // This keeps BIL offline while matching the clarity of mature health apps.
    final premiumBase = base.textTheme;

    final platformTextTheme = premiumBase
        .copyWith(
          displayLarge: premiumBase.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: isArabic ? -.5 : -2.1,
            height: isArabic ? 1.10 : 1.02,
          ),
          displayMedium: premiumBase.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: isArabic ? -.35 : -1.55,
            height: isArabic ? 1.12 : 1.04,
          ),
          displaySmall: premiumBase.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: isArabic ? -.22 : -1.05,
            height: isArabic ? 1.14 : 1.08,
          ),
          headlineLarge: premiumBase.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: isArabic ? -.12 : -.65,
            height: isArabic ? 1.20 : 1.14,
          ),
          headlineMedium: premiumBase.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: isArabic ? -.08 : -.4,
            height: isArabic ? 1.22 : 1.16,
          ),
          headlineSmall: premiumBase.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: isArabic ? 0 : -.2,
            height: 1.24,
          ),
          titleLarge: premiumBase.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: isArabic ? 1.24 : 1.20,
          ),
          titleMedium: premiumBase.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: isArabic ? 1.25 : 1.22,
          ),
          titleSmall: premiumBase.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: isArabic ? 1.25 : 1.22,
          ),
          bodyLarge: premiumBase.bodyLarge?.copyWith(
            fontWeight: FontWeight.w400,
            height: isArabic ? 1.42 : 1.38,
            letterSpacing: isArabic ? 0 : -.05,
          ),
          bodyMedium: premiumBase.bodyMedium?.copyWith(
            fontWeight: FontWeight.w400,
            height: isArabic ? 1.38 : 1.34,
          ),
          bodySmall: premiumBase.bodySmall?.copyWith(
            fontWeight: FontWeight.w400,
            height: isArabic ? 1.34 : 1.30,
          ),
          labelLarge: premiumBase.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: isArabic ? 0 : .08,
            height: isArabic ? 1.32 : 1.20,
          ),
          labelMedium: premiumBase.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: isArabic ? 1.24 : 1.18,
          ),
          labelSmall: premiumBase.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: isArabic ? 1.28 : 1.16,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final textTheme = BilTypography.build(
      base: platformTextTheme,
      foreground: scheme.onSurface,
      isArabic: isArabic,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: dark
            ? BilFlagshipTokens.canvasDark
            : BilFlagshipTokens.surfaceLight,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: PremiumDesignTokens.elevationNone,
        margin: EdgeInsets.zero,
        color: dark
            ? BilFlagshipTokens.surfaceDark
            : BilFlagshipTokens.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: dark ? .34 : .10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 54)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: BilFlagshipTokens.space24,
              vertical: BilFlagshipTokens.space16,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
            ),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? Colors.white.withValues(alpha: .12)
                : null,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 54),
          padding: const EdgeInsets.symmetric(
            horizontal: BilFlagshipTokens.space24,
            vertical: BilFlagshipTokens.space16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
          ),
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.square(48)),
          iconSize: const WidgetStatePropertyAll(24),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? BilFlagshipTokens.surfaceMutedDark
            : BilFlagshipTokens.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BilFlagshipTokens.space16,
          vertical: BilFlagshipTokens.space16,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(
            color: BilFlagshipTokens.cyan500,
            width: 1.8,
          ),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: BilFlagshipTokens.red500),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(
            color: BilFlagshipTokens.red500,
            width: 1.8,
          ),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: const TextStyle(
          color: BilFlagshipTokens.cyan500,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: dark
            ? BilFlagshipTokens.surfaceDark
            : BilFlagshipTokens.surfaceLight,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark
            ? BilFlagshipTokens.surfaceDark
            : BilFlagshipTokens.surfaceLight,
        indicatorColor: scheme.primaryContainer,
        useIndicator: true,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: dark
            ? BilFlagshipTokens.surfaceDark
            : BilFlagshipTokens.surfaceLight,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: 56,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        horizontalTitleGap: 0,
        minLeadingWidth: 0,
        minVerticalPadding: 14,
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w400,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w400,
        ),
        shape: const RoundedRectangleBorder(),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: dark
            ? BilFlagshipTokens.surfaceDark
            : BilFlagshipTokens.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusXl),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: dark
            ? BilFlagshipTokens.surfaceDark
            : BilFlagshipTokens.surfaceLight,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BilFlagshipTokens.radiusXl),
          ),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(scheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
              side: BorderSide(color: scheme.outlineVariant),
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
        ),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: BilFlagshipTokens.space12,
          vertical: BilFlagshipTokens.space8,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: scheme.outline),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: scheme.outlineVariant,
        indicatorColor: scheme.primary,
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark
              ? BilFlagshipTokens.surfaceMutedDark
              : BilFlagshipTokens.navy900,
          borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusSm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? BilFlagshipTokens.surfaceMutedDark
            : BilFlagshipTokens.navy900,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BilFlagshipTokens.cyan500,
        linearTrackColor: Colors.transparent,
      ),
      focusColor: BilFlagshipTokens.cyan400.withValues(alpha: .18),
      hoverColor: BilFlagshipTokens.cyan400.withValues(alpha: .08),
      highlightColor: BilFlagshipTokens.cyan400.withValues(alpha: .10),
      extensions: <ThemeExtension<dynamic>>[
        BilFlagshipThemeExtension(
          heroGradient: BilFlagshipTokens.heroGradient,
          brandGradient: BilFlagshipTokens.brandGradient,
          premiumShadow: BilFlagshipTokens.shadowFloating,
          cardShadow: BilFlagshipTokens.shadowCard,
          glassFill: dark
              ? Colors.white.withValues(alpha: .07)
              : Colors.white.withValues(alpha: .76),
          glassBorder: dark
              ? Colors.white.withValues(alpha: .12)
              : BilFlagshipTokens.outlineLight.withValues(alpha: .86),
          success: BilFlagshipTokens.emerald500,
          warning: BilFlagshipTokens.orange500,
          calorie: AppColors.calories,
          protein: AppColors.protein,
          carbs: AppColors.carbs,
        ),
      ],
    );
  }
}

@immutable
class BilFlagshipThemeExtension
    extends ThemeExtension<BilFlagshipThemeExtension> {
  const BilFlagshipThemeExtension({
    required this.heroGradient,
    required this.brandGradient,
    required this.premiumShadow,
    required this.cardShadow,
    required this.glassFill,
    required this.glassBorder,
    required this.success,
    required this.warning,
    required this.calorie,
    required this.protein,
    required this.carbs,
  });

  final Gradient heroGradient;
  final Gradient brandGradient;
  final List<BoxShadow> premiumShadow;
  final List<BoxShadow> cardShadow;
  final Color glassFill;
  final Color glassBorder;
  final Color success;
  final Color warning;
  final Color calorie;
  final Color protein;
  final Color carbs;

  @override
  BilFlagshipThemeExtension copyWith({
    Gradient? heroGradient,
    Gradient? brandGradient,
    List<BoxShadow>? premiumShadow,
    List<BoxShadow>? cardShadow,
    Color? glassFill,
    Color? glassBorder,
    Color? success,
    Color? warning,
    Color? calorie,
    Color? protein,
    Color? carbs,
  }) {
    return BilFlagshipThemeExtension(
      heroGradient: heroGradient ?? this.heroGradient,
      brandGradient: brandGradient ?? this.brandGradient,
      premiumShadow: premiumShadow ?? this.premiumShadow,
      cardShadow: cardShadow ?? this.cardShadow,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      calorie: calorie ?? this.calorie,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
    );
  }

  @override
  BilFlagshipThemeExtension lerp(
    covariant BilFlagshipThemeExtension? other,
    double t,
  ) {
    if (other == null) return this;

    return BilFlagshipThemeExtension(
      heroGradient: t < .5 ? heroGradient : other.heroGradient,
      brandGradient: t < .5 ? brandGradient : other.brandGradient,
      premiumShadow: t < .5 ? premiumShadow : other.premiumShadow,
      cardShadow: t < .5 ? cardShadow : other.cardShadow,
      glassFill: Color.lerp(glassFill, other.glassFill, t) ?? glassFill,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      calorie: Color.lerp(calorie, other.calorie, t) ?? calorie,
      protein: Color.lerp(protein, other.protein, t) ?? protein,
      carbs: Color.lerp(carbs, other.carbs, t) ?? carbs,
    );
  }
}

extension BilFlagshipThemeContext on BuildContext {
  BilFlagshipThemeExtension get bilTheme =>
      Theme.of(this).extension<BilFlagshipThemeExtension>()!;
}
