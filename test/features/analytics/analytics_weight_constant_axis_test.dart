import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/app_theme_data.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/analytics/widgets/analytics_weight_trend_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  WeightEntry measurement(double value, int index) {
    final date = DateTime(2026, 10, 26).subtract(Duration(days: index));
    return WeightEntry(
      id: index + 1,
      uuid: 'axis-qa-$index',
      date: date,
      dayKey: date.toIso8601String().split('T').first,
      weight: value,
      measurementContext: 'morning',
      createdAt: date,
      updatedAt: date,
      revision: 1,
      syncStatus: 'synced',
    );
  }

  for (final repeated in [false, true]) {
    testWidgets(
      '${repeated ? 'Repeated constant' : 'Single'} measurement has an ordered axis containing the measured value',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            home: Scaffold(
              body: AnalyticsWeightTrendChart(
                weights: [measurement(80, 0), if (repeated) measurement(80, 1)],
                system: MeasurementSystem.metric,
                rangeLabel: 'Last 30 days',
                targetWeightKg: 80,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final upper = find.text('80.5 kg');
        final lower = find.text('79.5 kg');
        expect(upper, findsOneWidget);
        expect(lower, findsOneWidget);
        expect(
          tester.getCenter(upper).dy,
          lessThan(tester.getCenter(lower).dy),
        );
        expect(find.text('Current'), findsOneWidget);
        expect(find.text('+0.0 kg'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Distinct measurements retain their actual axis bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
          body: AnalyticsWeightTrendChart(
            weights: [measurement(79, 1), measurement(81, 0)],
            system: MeasurementSystem.metric,
            rangeLabel: 'Last 30 days',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('80.0 kg'), findsOneWidget);
    expect(find.text('79.5 kg'), findsNothing);
    expect(find.text('80.5 kg'), findsNothing);
    expect(find.text('+2.0 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A single imperial measurement has a valid pound axis', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
          body: AnalyticsWeightTrendChart(
            weights: [measurement(80, 0)],
            system: MeasurementSystem.imperial,
            rangeLabel: 'Last 30 days',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final top = find.text('176.9 lb');
    final bottom = find.text('175.9 lb');
    expect(top, findsOneWidget);
    expect(bottom, findsOneWidget);
    expect(tester.getCenter(top).dy, lessThan(tester.getCenter(bottom).dy));
    expect(find.text('+0.0 lb'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets('Narrow measured range renders $language dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: visualEvidenceTheme(
              AppThemeData.lightTheme(
                dark ? Brightness.dark : Brightness.light,
              ),
              fontFamily: language == 'ar'
                  ? 'NotoArabicEvidence'
                  : 'RobotoEvidence',
            ),
            home: Scaffold(
              body: RepaintBoundary(
                key: const ValueKey('axis-capture'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AnalyticsWeightTrendChart(
                    weights: [measurement(80, 1), measurement(80.001, 0)],
                    system: MeasurementSystem.metric,
                    rangeLabel: language == 'ar'
                        ? 'آخر 30 يومًا'
                        : 'Last 30 days',
                    targetWeightKg: 80,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('80.5 kg'), findsOneWidget);
        expect(find.text('79.5 kg'), findsOneWidget);
        expect(
          Directionality.of(
            tester.element(find.byType(AnalyticsWeightTrendChart)),
          ),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
        const captureDirectory = String.fromEnvironment('BIL_QA_CAPTURE_DIR');
        if (captureDirectory.isNotEmpty) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('axis-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(captureDirectory).create(recursive: true);
            await File(
              '$captureDirectory/weight-axis-$language-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
