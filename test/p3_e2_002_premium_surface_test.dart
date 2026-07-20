import 'package:body_intelligence_log/app/theme/app_theme_data.dart';
import 'package:body_intelligence_log/app/theme/premium_design_tokens.dart';
import 'package:body_intelligence_log/shared/widgets/app_card.dart';
import 'package:body_intelligence_log/shared/widgets/premium_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P3-E2-002 premium surface primitive', () {
    testWidgets(
      'PremiumSurface uses semantic container and tokenized defaults',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemeData.lightTheme(Brightness.light),
            home: const Scaffold(body: PremiumSurface(child: Text('content'))),
          ),
        );

        expect(find.byType(PremiumSurface), findsOneWidget);
        expect(find.byType(Semantics), findsWidgets);
        expect(find.byType(Card), findsOneWidget);

        final padding = tester.widget<Padding>(
          find.descendant(
            of: find.byType(PremiumSurface),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Padding &&
                  widget.padding == PremiumDesignTokens.cardPadding,
            ),
          ),
        );
        expect(padding.padding, PremiumDesignTokens.cardPadding);
      },
    );

    testWidgets('PremiumSurface applies tap behavior when onTap is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemeData.lightTheme(Brightness.light),
          home: Scaffold(
            body: PremiumSurface(onTap: () {}, child: const Text('content')),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(PremiumSurface),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });

    testWidgets('AppCard delegates to PremiumSurface for shared chrome', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemeData.lightTheme(Brightness.light),
          home: const Scaffold(body: AppCard(child: Text('card body'))),
        ),
      );

      expect(find.byType(AppCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(PremiumSurface),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AppCard), matching: find.byType(Card)),
        findsOneWidget,
      );
    });
  });
}
