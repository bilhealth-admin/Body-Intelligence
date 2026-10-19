import 'package:body_intelligence_log/app/theme/app_theme_data.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/app/theme/bil_pearl_finish.dart';
import 'package:body_intelligence_log/app/theme/bil_navigation_press_style.dart';
import 'package:body_intelligence_log/features/onboarding/widgets/modern_onboarding_scaffold.dart';
import 'package:body_intelligence_log/features/visual_2026/bil_calm_visual_scope.dart';
import 'package:body_intelligence_log/shared/widgets/bil_premium_trust_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    final flagship = dark ? BilFlagshipTheme.dark() : BilFlagshipTheme.light();
    testWidgets(
      'navigation bubble ignores page accent and keeps disabled action dark=$dark',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: flagship.copyWith(
              colorScheme: flagship.colorScheme.copyWith(
                secondaryContainer: Colors.green,
              ),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    IconButton.filledTonal(
                      key: const Key('neutral-navigation'),
                      style: BilNavigationPressStyle.neutralBubble(context),
                      onPressed: () => taps++,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    IconButton.filledTonal(
                      key: const Key('neutral-disabled-navigation'),
                      style: BilNavigationPressStyle.neutralBubble(context),
                      onPressed: null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final enabled = tester.widget<IconButton>(
          find.byKey(const Key('neutral-navigation')),
        );
        expect(
          enabled.style!.backgroundColor!.resolve({}),
          dark ? BilPearlFinish.darkInset : BilPearlFinish.lightInset,
        );
        final disabled = tester.widget<IconButton>(
          find.byKey(const Key('neutral-disabled-navigation')),
        );
        expect(
          disabled.style!.backgroundColor!.resolve({WidgetState.disabled}),
          dark ? BilPearlFinish.darkSurface : BilPearlFinish.lightSurface,
        );
        await tester.tap(find.byKey(const Key('neutral-navigation')));
        await tester.tap(find.byKey(const Key('neutral-disabled-navigation')));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
    final themes = [
      flagship,
      AppThemeData.lightTheme(dark ? Brightness.dark : Brightness.light),
      BilCalmVisualScope.resolve(flagship, isArabic: true),
    ];
    for (var index = 0; index < themes.length; index++) {
      testWidgets(
        'feedback keeps readable shared surface dark=$dark scope=$index',
        (tester) async {
          final theme = themes[index];
          var actions = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('اكتملت المزامنة وتم إرسال البلاغ'),
                        action: SnackBarAction(
                          label: 'تراجع',
                          onPressed: () => actions++,
                        ),
                      ),
                    ),
                    child: const Text('عرض'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('عرض'));
          await tester.pumpAndSettle();
          final feedback = themes[index].snackBarTheme;
          expect(
            feedback.backgroundColor,
            theme.colorScheme.surfaceContainerHighest,
          );
          expect(feedback.contentTextStyle?.color, theme.colorScheme.onSurface);
          final surface = tester
              .widgetList<Material>(
                find.descendant(
                  of: find.byType(SnackBar),
                  matching: find.byType(Material),
                ),
              )
              .first;
          expect(surface.color, feedback.backgroundColor);
          expect(find.text('اكتملت المزامنة وتم إرسال البلاغ'), findsOneWidget);
          await tester.tap(find.text('تراجع'));
          await tester.pumpAndSettle();
          expect(actions, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'setup and consent cards share pearl while selection still works dark=$dark',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: flagship,
            home: Scaffold(
              body: ListView(
                children: [
                  OnboardingChoiceCard(
                    title: 'اختيار الهدف',
                    selected: true,
                    onTap: () => taps++,
                  ),
                  const BilPremiumTrustSurface(
                    icon: Icons.verified_user_outlined,
                    title: 'مراجعة الإعداد',
                    body: 'بياناتك وموافقاتك محفوظة.',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final selected = find.byType(OnboardingChoiceCard);
        final trust = find.byType(BilPremiumTrustSurface);
        for (final card in [selected, trust]) {
          final ink = tester.widget<Ink>(
            find.descendant(of: card, matching: find.byType(Ink)).first,
          );
          final decoration = ink.decoration! as BoxDecoration;
          final context = tester.element(card);
          expect(decoration.gradient, BilPearlFinish.panel(context).gradient);
        }
        await tester.tap(find.text('اختيار الهدف'));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
