import 'dart:io';

import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Epic 3 unified design system', () {
    test('canonical geometry and native typography are stable', () {
      expect(BilFlagshipTokens.radiusSm, 10);
      expect(BilFlagshipTokens.radiusMd, 12);
      expect(BilFlagshipTokens.radiusXl, 16);

      final light = BilFlagshipTheme.light();
      final dark = BilFlagshipTheme.dark();
      final arabic = BilFlagshipTheme.light(isArabic: true);

      final nativeLight = ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
      ).textTheme;
      expect(
        light.textTheme.bodyLarge?.fontFamily,
        nativeLight.bodyLarge?.fontFamily,
      );
      expect(arabic.textTheme.bodyLarge?.fontFamily, 'BILArabic');
      expect(light.textTheme.bodyLarge?.fontWeight, FontWeight.w400);
      expect(light.textTheme.titleLarge?.fontWeight, FontWeight.w600);
      expect(light.textTheme.headlineLarge?.fontWeight, FontWeight.w700);
      expect(light.appBarTheme.centerTitle, isTrue);
      expect(light.scaffoldBackgroundColor, isNot(Colors.white));
      expect(dark.brightness, Brightness.dark);
    });

    test('global component families are configured centrally', () {
      final theme = BilFlagshipTheme.light();

      expect(theme.cardTheme.elevation, 0);
      expect(theme.navigationBarTheme.height, 68);
      expect(
        theme.bottomNavigationBarTheme.type,
        BottomNavigationBarType.fixed,
      );
      expect(theme.dialogTheme.elevation, 0);
      expect(theme.bottomSheetTheme.elevation, 0);
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.iconButtonTheme.style, isNotNull);
      expect(theme.chipTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.tabBarTheme.indicatorColor, theme.colorScheme.primary);
    });

    test('active account flows consume the shared themed surface', () {
      for (final path in <String>[
        'lib/features/auth/register_page.dart',
        'lib/features/auth/verify_email_page.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains('BilAccountSurface('), reason: path);
        expect(source, isNot(contains('0xFFF7F8FB')), reason: path);
        expect(
          source,
          isNot(contains('BorderRadius.circular(32)')),
          reason: path,
        );
      }
    });
  });
}
