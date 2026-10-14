import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/app_router.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/nutrition_plans/presentation/nutrition_pathways_page.dart';
import 'package:body_intelligence_log/shared/widgets/bil_feature_entry_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../visual_closure/visual_evidence_font.dart';
import '../../qa_next/feature_splashes_test_support.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final language in ['ar', 'en']) {
    testWidgets(
      'actual production Diet entry prewarms pathways and preserves return $language',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = await openFeatureSplashDatabase(tester);
        // Use the actual production GoRoute object and its actual page builder.
        // The isolated route list avoids mounting startup or mutating auth/store.
        final production = AppRouter.router.configuration.routes
            .whereType<GoRoute>()
            .singleWhere((route) => route.path == '/nutrition-plans');
        final router = GoRouter(
          initialLocation: '/nutrition-plans',
          routes: [
            production,
            GoRoute(
              path: '/dashboard',
              builder: (_, _) =>
                  const Scaffold(body: Text('Returned destination')),
            ),
          ],
        );
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [databaseProvider.overrideWithValue(database)],
              child: MaterialApp.router(
                routerConfig: router,
                theme: featureSplashEvidenceTheme(
                  language: language,
                  dark: false,
                ),
                locale: Locale(language),
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
                  ).copyWith(disableAnimations: true),
                  child: child!,
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.byType(BilFeatureEntrySplashGate), findsOneWidget);
          expect(
            find.byType(NutritionPathwaysPage),
            findsOneWidget,
            reason:
                'catalog presentation and its providers start before the visual hold ends',
          );
          expect(
            find.byKey(const ValueKey('feature-entry-splash-diet')),
            findsOneWidget,
          );
          await tester.pump(const Duration(milliseconds: 2199));
          expect(
            find.byKey(const ValueKey('feature-entry-splash-diet')),
            findsOneWidget,
          );
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump();
          expect(
            find.byKey(const ValueKey('feature-entry-splash-diet')),
            findsNothing,
          );
          expect(find.byType(NutritionPathwaysPage), findsOneWidget);
          final back = find.byKey(const Key('nutrition-pathways-back'));
          expect(back.hitTestable(), findsOneWidget);
          await tester.tap(back);
          await tester.pumpAndSettle();
          expect(find.text('Returned destination'), findsOneWidget);
          expect(router.state.uri.path, '/dashboard');
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
          await closeFeatureSplashDatabase(tester, database);
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  }
}
