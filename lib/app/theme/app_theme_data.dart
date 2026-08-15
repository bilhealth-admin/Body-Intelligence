import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'premium_design_tokens.dart';

class AppThemeData {
  static ThemeData lightTheme(
    Brightness brightness, {
    bool highContrast = false,
  }) {
    final dark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      contrastLevel: highContrast ? 1 : 0,
      surface: dark ? const Color(0xFF121A2A) : const Color(0xFFF8FAFC),
    );

    final divider = dark ? const Color(0xFF273247) : const Color(0xFFE7E7EC);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF09111F)
          : highContrast
          ? Colors.white
          : AppColors.background,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: dark ? const Color(0xFF09111F) : Colors.white,
        foregroundColor: dark ? Colors.white : AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: dark ? Colors.white : AppColors.textPrimary,
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: PremiumDesignTokens.elevationNone,
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: dark ? const Color(0xFF121E31) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: PremiumDesignTokens.cardRadius,
          side: BorderSide(
            color: PremiumDesignTokens.cardBorderColor(brightness),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: PremiumDesignTokens.inputRadius,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF101B2C) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: PremiumDesignTokens.inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PremiumDesignTokens.inputRadius,
          borderSide: BorderSide(
            color: PremiumDesignTokens.inputBorderColor(brightness),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: dark ? const Color(0xFF0E1828) : Colors.white,
        indicatorColor: colorScheme.primary.withValues(alpha: dark ? .18 : .09),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark ? const Color(0xFF0E1828) : Colors.white,
        indicatorColor: colorScheme.primaryContainer,
        useIndicator: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF121E31) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: PremiumDesignTokens.dialogRadius,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: divider,
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        minTileHeight: 54,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        iconColor: dark ? const Color(0xFF9CA9BA) : const Color(0xFF68717D),
        textColor: dark ? Colors.white : AppColors.textPrimary,
        titleTextStyle: TextStyle(
          color: dark ? Colors.white : AppColors.textPrimary,
          fontSize: 16,
          height: 1.25,
          fontWeight: FontWeight.w400,
        ),
        subtitleTextStyle: TextStyle(
          color: dark ? const Color(0xFF9CA9BA) : const Color(0xFF6D727C),
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w400,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? const Color(0xFF101A2A) : Colors.white,
        modalBackgroundColor: dark ? const Color(0xFF101A2A) : Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: divider,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: dark ? Colors.white : AppColors.textPrimary,
        unselectedLabelColor: dark
            ? const Color(0xFF9CA9BA)
            : const Color(0xFF68717D),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      chipTheme: ChipThemeData(
        elevation: 0,
        pressElevation: 0,
        side: BorderSide(color: divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
