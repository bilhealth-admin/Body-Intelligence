import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _dashboard() => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: PremiumDashboardBenchmark(
    arabic: false,
    actionTitle: '',
    actionReason: '',
    actionEvidence: '',
    confidence: '',
    onAction: null,
    dailyIntelligence: const SizedBox.shrink(),
    connectedHealth: const SizedBox(
      key: Key('reference-connected-device'),
      height: 252,
    ),
    bodyTwinSummary: '',
    bodyTwinEvidence: '',
    nutritionSummary: '',
    nutritionEvidence: '',
    trendSummary: '',
    trendEvidence: '',
    loggingItems: const [],
    caloriesConsumed: 640,
    caloriesGoal: 2100,
    carbohydratesConsumed: 85,
    carbohydratesGoal: 260,
    fatConsumed: 28,
    fatGoal: 70,
    proteinConsumed: 62,
    proteinGoal: 135,
    visibleSections: const {
      DashboardSectionIds.aiCoach,
      DashboardSectionIds.connectedHealth,
      DashboardSectionIds.calories,
      DashboardSectionIds.macros,
    },
    premiumUnlocked: true,
  ),
);

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      '${locale.toLanguageTag()} uses reference calorie and macro rows at 1.6x',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(body: _dashboard()),
            ),
            GoRoute(path: '/plans', builder: (_, _) => const SizedBox.shrink()),
            GoRoute(
              path: '/daily-log',
              builder: (_, _) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/settings/nutrition-goals',
              builder: (_, _) => const SizedBox.shrink(),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(
              locale: locale,
              routerConfig: router,
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
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final coach = find.byKey(const Key('dashboard-mobile-ai-coach-entry'));
        final device = find.byKey(const Key('reference-connected-device'));
        final calories = find.byKey(
          const Key('dashboard-reference-calories-card'),
        );
        final macros = find.byKey(const Key('dashboard-reference-macros-card'));
        expect(coach, findsOneWidget);
        expect(device, findsOneWidget);
        expect(calories, findsOneWidget);
        expect(macros, findsNothing);
        expect(find.byKey(const Key('dashboard-free-ad-slot')), findsOneWidget);
        expect(
          tester.getTopLeft(coach).dy,
          lessThan(tester.getTopLeft(device).dy),
        );
        expect(
          tester.getTopLeft(device).dy,
          lessThan(tester.getTopLeft(calories).dy),
        );
        final calorieCardSize = tester.getSize(calories);
        expect(
          find.byKey(const Key('dashboard-calories-macros-horizontal')),
          findsOneWidget,
        );

        expect(
          find.descendant(
            of: calories,
            matching: find.byType(LinearProgressIndicator),
          ),
          findsOneWidget,
        );
        final consumedValue = tester.widget<Text>(
          find.byKey(const Key('dashboard-reference-calorie-consumed-value')),
        );
        expect(consumedValue.textSpan?.toPlainText(), '640 / 2100');
        expect(consumedValue.textDirection, TextDirection.ltr);
        final remainingValue = tester.widget<Text>(
          find.byKey(const Key('dashboard-reference-calorie-remaining-value')),
        );
        expect(remainingValue.textSpan?.toPlainText(), '1460');
        expect(remainingValue.textDirection, TextDirection.ltr);

        final carousel = find.byKey(
          const Key('dashboard-calories-macros-horizontal'),
        );
        final pageView = tester.widget<PageView>(carousel);
        pageView.controller!.jumpToPage(1);
        await tester.pumpAndSettle();
        expect(calories, findsNothing);
        expect(macros, findsOneWidget);
        expect(
          tester.getSize(macros).height,
          moreOrLessEquals(calorieCardSize.height, epsilon: 0.5),
        );
        expect(
          find.descendant(
            of: macros,
            matching: find.byType(LinearProgressIndicator),
          ),
          findsNWidgets(3),
        );
        expect(
          find.descendant(
            of: calories,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: macros,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        expect(find.text('85 g / 260'), findsOneWidget);
        expect(find.text('28 g / 70'), findsOneWidget);
        expect(find.text('62 g / 135'), findsOneWidget);
        if (!const {
          'ar',
          'en',
          'fr',
          'es',
          'tr',
        }.contains(locale.languageCode)) {
          for (final source in const {
            'Calories',
            'consumed',
            'left',
            'Edit goal',
            'Macros',
            'Carbs',
            'Fat',
            'Protein',
            'Premium nutrient goals',
            'See protein, carbs, and fat progress at a glance.',
          }) {
            expect(
              RuntimeCopy.resolve(source, locale.toLanguageTag()),
              isNotNull,
              reason: '${locale.toLanguageTag()} must review $source',
            );
          }
        }
        final rtl = const {'ar', 'fa', 'ur'}.contains(locale.languageCode);
        expect(
          Directionality.of(tester.element(macros)),
          rtl ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(
          find.descendant(
            of: macros,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Directionality &&
                  widget.textDirection == TextDirection.ltr,
            ),
          ),
          findsAtLeastNWidgets(3),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
