import 'package:body_intelligence_log/features/analytics/weekly_report_engine.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_page.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  final snapshot = const WeeklyReportEngine().build(
    asOf: DateTime.utc(2026, 8, 4),
    mealCount: 4,
    nutrition: const [
      WeeklyNutritionObservation(
        dayKey: '2026-08-01',
        calories: 1850,
        proteinG: 118,
        sodiumMg: 2100,
      ),
      WeeklyNutritionObservation(
        dayKey: '2026-08-03',
        calories: 1720,
        proteinG: 126,
        sodiumMg: 1900,
      ),
    ],
    water: const [
      WeeklyWaterObservation(dayKey: '2026-08-01', amountMl: 2200),
      WeeklyWaterObservation(dayKey: '2026-08-03', amountMl: 2500),
    ],
    weights: [
      WeeklyWeightObservation(
        dayKey: '2026-08-01',
        observedAt: DateTime.utc(2026, 8, 1),
        weightKg: 93.4,
      ),
      WeeklyWeightObservation(
        dayKey: '2026-08-04',
        observedAt: DateTime.utc(2026, 8, 4),
        weightKg: 92.8,
      ),
    ],
  );

  Future<void> pumpReport(
    WidgetTester tester, {
    required Locale locale,
    required Brightness brightness,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [weeklyReportProvider.overrideWith((ref) async => snapshot)],
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: visualEvidenceTheme(
            ThemeData(brightness: brightness, useMaterial3: true),
            fontFamily: locale.languageCode == 'ar'
                ? 'NotoArabicEvidence'
                : 'RobotoEvidence',
          ),
          builder: (context, child) => visualEvidenceTextSurface(
            child,
            fontFamily: locale.languageCode == 'ar'
                ? 'NotoArabicEvidence'
                : 'RobotoEvidence',
          ),
          home: const WeeklyReportPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('weekly report phone LTR light golden', (tester) async {
    await pumpReport(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
    );
    await expectLater(
      find.byType(WeeklyReportPage),
      matchesGoldenFile('goldens/epic8_weekly_report_phone_ltr_light.png'),
    );
  });

  testWidgets('weekly report phone RTL dark golden', (tester) async {
    await pumpReport(
      tester,
      locale: const Locale('ar'),
      brightness: Brightness.dark,
    );
    await expectLater(
      find.byType(WeeklyReportPage),
      matchesGoldenFile('goldens/epic8_weekly_report_phone_rtl_dark.png'),
    );
  });
}
