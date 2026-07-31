import 'package:body_intelligence_log/app/theme/app_theme_data.dart';
import 'package:body_intelligence_log/app/theme/premium_design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P3-E2-001 canonical token layer', () {
    test('exposes one semantic token source with stable primitives', () {
      expect(PremiumDesignTokens.spaceXs, 8);
      expect(PremiumDesignTokens.spaceSm, 12);
      expect(PremiumDesignTokens.spaceMd, 16);
      expect(PremiumDesignTokens.spaceLg, 20);
      expect(PremiumDesignTokens.radiusMd, 14);
      expect(PremiumDesignTokens.radiusLg, 20);
      expect(PremiumDesignTokens.radiusXl, 24);
      expect(PremiumDesignTokens.elevationNone, 0);
      expect(PremiumDesignTokens.screenPadding, const EdgeInsets.all(16));
      expect(PremiumDesignTokens.cardPadding, const EdgeInsets.all(16));
      expect(PremiumDesignTokens.cardPaddingLarge, const EdgeInsets.all(20));
    });

    test('exposes semantic color roles for light and dark safely', () {
      expect(
        PremiumDesignTokens.cardBorderColor(Brightness.light),
        const Color(0xFFE3EAF3),
      );
      expect(
        PremiumDesignTokens.cardBorderColor(Brightness.dark),
        const Color(0xFF26364E),
      );
      expect(
        PremiumDesignTokens.inputBorderColor(Brightness.light),
        const Color(0xFFD8E1ED),
      );
      expect(
        PremiumDesignTokens.inputBorderColor(Brightness.dark),
        const Color(0xFF31415A),
      );
    });
  });

  group('P3-E2-001 AppThemeData token consumption', () {
    test(
      'light theme consumes canonical tokenized shape/elevation/color roles',
      () {
        final theme = AppThemeData.lightTheme(Brightness.light);

        expect(
          (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius,
          PremiumDesignTokens.cardRadius,
        );
        expect(theme.cardTheme.elevation, PremiumDesignTokens.elevationNone);
        expect(
          ((theme.cardTheme.shape as RoundedRectangleBorder).side).color,
          PremiumDesignTokens.cardBorderColor(Brightness.light),
        );

        expect(
          (theme.filledButtonTheme.style?.shape?.resolve(<WidgetState>{})
                  as RoundedRectangleBorder)
              .borderRadius,
          PremiumDesignTokens.inputRadius,
        );

        expect(
          (theme.inputDecorationTheme.border as OutlineInputBorder)
              .borderRadius,
          PremiumDesignTokens.inputRadius,
        );
        expect(
          (theme.inputDecorationTheme.enabledBorder as OutlineInputBorder)
              .borderRadius,
          PremiumDesignTokens.inputRadius,
        );
        expect(
          (theme.inputDecorationTheme.enabledBorder as OutlineInputBorder)
              .borderSide
              .color,
          PremiumDesignTokens.inputBorderColor(Brightness.light),
        );

        expect(
          (theme.dialogTheme.shape as RoundedRectangleBorder).borderRadius,
          PremiumDesignTokens.dialogRadius,
        );
      },
    );

    test('dark theme consumes canonical semantic border colors', () {
      final theme = AppThemeData.lightTheme(Brightness.dark);

      expect(
        ((theme.cardTheme.shape as RoundedRectangleBorder).side).color,
        PremiumDesignTokens.cardBorderColor(Brightness.dark),
      );
      expect(
        (theme.inputDecorationTheme.enabledBorder as OutlineInputBorder)
            .borderSide
            .color,
        PremiumDesignTokens.inputBorderColor(Brightness.dark),
      );
    });
  });

  group('P3-E2-001 semantic typography helpers', () {
    testWidgets('semantic heading helpers resolve from active textTheme', (
      tester,
    ) async {
      final textTheme = ThemeData().textTheme.copyWith(
        headlineSmall: const TextStyle(fontSize: 21),
        titleLarge: const TextStyle(fontSize: 19),
        titleMedium: const TextStyle(fontSize: 17),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(textTheme: textTheme),
          home: Builder(
            builder: (context) {
              expect(
                PremiumDesignTokens.screenHeading(context),
                Theme.of(context).textTheme.headlineSmall,
              );
              expect(
                PremiumDesignTokens.sectionHeading(context),
                Theme.of(context).textTheme.titleLarge,
              );
              expect(
                PremiumDesignTokens.cardHeading(context),
                Theme.of(context).textTheme.titleMedium,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}
