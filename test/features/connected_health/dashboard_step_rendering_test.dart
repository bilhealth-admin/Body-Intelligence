import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_step_trend.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scenarios = <({String name, DashboardStepTrend trend, String? value})>[
    (
      name: 'no evidence renders no chart or invented zero',
      trend: const DashboardStepTrend(values: [], today: null, source: null),
      value: null,
    ),
    (
      name: 'historical evidence does not become today',
      trend: DashboardStepTrend(
        values: [...List<double>.filled(28, 0), 8000, 0],
        today: null,
        source: 'Apple Health',
      ),
      value: '—',
    ),
    (
      name: 'a measured zero is displayed as zero',
      trend: DashboardStepTrend(
        values: List<double>.filled(30, 0),
        today: 0,
        source: 'Apple Health',
      ),
      value: '0',
    ),
    (
      name: 'actual count and source reach the card unchanged',
      trend: DashboardStepTrend(
        values: [...List<double>.filled(29, 0), 1234],
        today: 1234,
        source: 'Apple Health',
      ),
      value: '1234',
    ),
  ];
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final scenario in scenarios) {
      testWidgets('${locale.languageCode}: ${scenario.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_harness(locale, scenario.trend));
        await _showSteps(tester);

        final card = find.byKey(const Key('dashboard-step-trend-card'));
        final paints = find.descendant(
          of: card,
          matching: find.byKey(const Key('dashboard-step-bars')),
        );
        final arabic = locale.languageCode == 'ar';
        if (scenario.value == null) {
          expect(paints, findsNothing);
          expect(
            find.text(
              arabic
                  ? 'اربط مصدرًا أو سجل خطواتك لعرض الاتجاه'
                  : 'Connect or log steps to see your trend',
            ),
            findsOneWidget,
          );
          expect(find.text('0 ${arabic ? 'خطوة' : 'steps'}'), findsNothing);
        } else {
          expect(paints, findsOneWidget);
          expect(
            find.text('${scenario.value} ${arabic ? 'خطوة' : 'steps'}'),
            findsOneWidget,
          );
          expect(find.textContaining('Apple Health'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('clearing evidence removes the old bars and source', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const Locale('en'), scenarios.last.trend));
    await _showSteps(tester);
    expect(find.text('1234 steps'), findsOneWidget);
    await tester.pumpWidget(
      _harness(const Locale('en'), scenarios.first.trend),
    );
    await _showSteps(tester);
    expect(find.text('1234 steps'), findsNothing);
    expect(find.textContaining('Apple Health'), findsNothing);
    expect(find.text('Connect or log steps to see your trend'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _showSteps(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final rail = find.byKey(const Key('dashboard-reference-trend-rail'));
  final page = tester.widget<PageView>(
    find.descendant(of: rail, matching: find.byType(PageView)),
  );
  page.controller!.jumpToPage(1);
  await tester.pumpAndSettle();
}

Widget _harness(Locale locale, DashboardStepTrend trend) => ProviderScope(
  child: MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: PremiumDashboardBenchmark(
          arabic: locale.languageCode == 'ar',
          actionTitle: '',
          actionReason: '',
          actionEvidence: '',
          confidence: '',
          onAction: null,
          dailyIntelligence: const SizedBox.shrink(),
          bodyTwinSummary: '',
          bodyTwinEvidence: '',
          nutritionSummary: '',
          nutritionEvidence: '',
          trendSummary: '',
          trendEvidence: '',
          loggingItems: const [],
          stepTrendValues: trend.values,
          todaySteps: trend.today,
          stepSourceName: trend.source,
          visibleSections: const {DashboardSectionIds.activity},
        ),
      ),
    ),
  ),
);
