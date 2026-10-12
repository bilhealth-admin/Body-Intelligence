import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_label_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../../visual_closure/closure_surface_capture.dart';
import '../daily_log/meal_platform_evidence_font.dart';

void main() {
  setUpAll(loadMealPlatformEvidenceFont);
  testWidgets('uses a compact gold Premium word without lock icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: Center(child: PremiumLabelBadge())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Premium'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);
    final badge = find.byType(PremiumLabelBadge);
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: badge,
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    final ink = tester.widget<Text>(find.text('Premium')).style!.color!;
    for (final color in gradient.colors) {
      expect(
        (color.computeLuminance() + .05) / (ink.computeLuminance() + .05),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        color.r,
        greaterThan(color.b),
        reason: 'A warm metallic gold surface.',
      );
    }
  });
  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      testWidgets(
        'gold Premium actual Plans action $language dark=$dark at 2x',
        (tester) async {
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final capture = GlobalKey();
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => RepaintBoundary(
                  key: capture,
                  child: Scaffold(
                    body: Center(
                      child: PremiumLabelBadge(
                        large: true,
                        onTap: () => context.push('/plans'),
                      ),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/plans',
                builder: (_, _) =>
                    const Scaffold(body: Text('Actual Plans destination')),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              locale: Locale(language),
              theme: mealPlatformEvidenceTheme(
                ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
              ),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final badge = find.byType(PremiumLabelBadge);
          expect(tester.getSize(badge).height, greaterThanOrEqualTo(48));
          expect(badge.hitTestable(), findsOneWidget);
          await captureClosureSurface(
            tester,
            find.byKey(capture),
            'gold-premium-$language-$dark-2x',
          );
          await tester.tap(badge);
          await tester.pumpAndSettle();
          expect(find.text('Actual Plans destination'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
