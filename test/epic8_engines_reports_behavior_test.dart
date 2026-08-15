import 'dart:convert';

import 'package:body_intelligence_log/features/analytics/weekly_report_engine.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_page.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_provider.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/global_platform/reports/scientific_reports_platform.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Epic 8 measured weekly report', () {
    const engine = WeeklyReportEngine();
    final asOf = DateTime.utc(2026, 8, 4);

    test('preserves missing days and aggregates only saved observations', () {
      final report = engine.build(
        asOf: asOf,
        mealCount: 2,
        nutrition: const [
          WeeklyNutritionObservation(
            dayKey: '2026-08-02',
            calories: 500,
            proteinG: 40,
            sodiumMg: 700,
          ),
          WeeklyNutritionObservation(
            dayKey: '2026-08-04',
            calories: 650,
            proteinG: 55,
            sodiumMg: 850,
          ),
        ],
        water: const [
          WeeklyWaterObservation(dayKey: '2026-08-04', amountMl: 750),
        ],
        weights: [
          WeeklyWeightObservation(
            dayKey: '2026-08-02',
            observedAt: DateTime.utc(2026, 8, 2),
            weightKg: 93.4,
          ),
          WeeklyWeightObservation(
            dayKey: '2026-08-04',
            observedAt: DateTime.utc(2026, 8, 4),
            weightKg: 92.8,
          ),
        ],
      );

      expect(report.days, hasLength(7));
      expect(report.trackedDays, 2);
      expect(report.missingDays, 5);
      expect(report.totalCalories, 1150);
      expect(report.totalProteinG, 95);
      expect(report.totalWaterMl, 750);
      expect(report.weightDirectionKg, closeTo(-0.6, 0.0001));
      expect(report.sources, everyElement(startsWith('local.')));
      expect(
        report.limitations,
        contains(
          'Weight direction alone cannot identify fat or muscle change.',
        ),
      );
    });

    test('abstains honestly when the saved window is empty', () {
      final report = engine.build(
        asOf: asOf,
        mealCount: 0,
        nutrition: const [],
        water: const [],
        weights: const [],
      );

      expect(report.isEmpty, isTrue);
      expect(report.confidence, WeeklyReportConfidence.insufficient);
      expect(report.latestWeightKg, isNull);
      expect(report.weightDirectionKg, isNull);
      expect(report.totalCalories, 0);
    });

    test('rejects impossible or non-finite observations', () {
      expect(
        () => engine.build(
          asOf: asOf,
          mealCount: 1,
          nutrition: const [
            WeeklyNutritionObservation(
              dayKey: '2026-08-04',
              calories: double.nan,
              proteinG: 1,
              sodiumMg: 1,
            ),
          ],
          water: const [],
          weights: const [],
        ),
        throwsArgumentError,
      );
    });
  });

  group('Epic 8 evidence exports', () {
    test('retains title, source and confidence in machine-readable output', () {
      final report = ScientificReport(
        id: 'weekly-2026-08-04',
        locale: 'en',
        from: DateTime.utc(2026, 7, 29),
        to: DateTime.utc(2026, 8, 4),
        sections: const [
          ReportSection(
            id: 'weight',
            title: 'Measured weight',
            facts: ['92.8 kg'],
            estimates: [],
            confidence: .8,
            provenance: 'local.weight_entries',
          ),
        ],
      );
      final decoded =
          jsonDecode(utf8.decode(ScientificReportRuntime().json(report)))
              as Map<String, dynamic>;
      final section = (decoded['sections'] as List).single as Map;
      expect(section['title'], 'Measured weight');
      expect(section['provenance'], 'local.weight_entries');
      expect(section['confidence'], .8);
    });

    test('fails closed when provenance or confidence is invalid', () {
      final report = ScientificReport(
        id: 'invalid',
        locale: 'en',
        from: DateTime.utc(2026),
        to: DateTime.utc(2026, 1, 7),
        sections: const [
          ReportSection(
            id: 'claim',
            title: 'Claim',
            facts: ['invented'],
            estimates: [],
            confidence: 1.2,
            provenance: '',
          ),
        ],
      );
      expect(() => ScientificReportRuntime().json(report), throwsArgumentError);
    });
  });

  group('Epic 8 weekly report surface', () {
    testWidgets('repository failure is visible and does not expose internals', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weeklyReportProvider.overrideWith(
              (ref) => Future.error(StateError('private database detail')),
            ),
          ],
          child: const MaterialApp(home: WeeklyReportPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(find.textContaining('private database detail'), findsNothing);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'empty and missing-data state works on phone ${locale.languageCode} ${brightness.name}',
          (tester) async {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  allMealsProvider.overrideWith(
                    (ref) => Stream.value(const []),
                  ),
                  allWaterProvider.overrideWith(
                    (ref) => Stream.value(const []),
                  ),
                  weightHistoryProvider.overrideWith(
                    (ref) => Stream.value(const []),
                  ),
                ],
                child: MaterialApp(
                  locale: locale,
                  theme: ThemeData(brightness: brightness),
                  home: const WeeklyReportPage(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(WeeklyReportPage), findsOneWidget);
            expect(find.textContaining('0/7'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
