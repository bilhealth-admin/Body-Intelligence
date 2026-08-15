import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/engine/daily_return_engine.dart';
import 'package:body_intelligence_log/engine/data_honesty_engine.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/engine/what_changed_engine.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/daily_return_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final width in <double>[320, 390, 900, 1280]) {
      testWidgets(
        'daily return content stays readable at $width ${locale.languageCode}',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Scaffold(
                backgroundColor: const Color(0xFF01050D),
                body: SingleChildScrollView(
                  child: DailyReturnCard(
                    report: _report(),
                    changedSummary:
                        'The scale changed, but one reading is not enough.',
                    actionTitle: 'Complete one meal',
                    actionReason: 'Meal evidence is incomplete for today.',
                    missingEvidence:
                        'More consistent local observations are needed.',
                    onPrimaryAction: _noop,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);

          expect(find.byType(DailyReturnCard), findsOneWidget);
          expect(find.byIcon(Icons.monitor_weight_outlined), findsOneWidget);
          expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
          expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
          expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
          expect(find.byIcon(Icons.cancel_rounded), findsNWidgets(2));
        },
      );
    }
  }
}

DailyReturnReport _report() => const DailyReturnReport(
  state: DailyReturnState.partial,
  hasWeight: true,
  hasMeals: false,
  hasWater: false,
  bestAction: BestAction(
    type: BestActionType.completeLogging,
    title: 'Complete one meal',
    reason: 'Meal evidence is incomplete for today.',
    evidence: ['Meal log is incomplete'],
  ),
  changed: WhatChangedReport(
    interpretation: ChangeInterpretation.insufficient,
    summary: 'More evidence is needed.',
    evidence: [],
    alternatives: [],
  ),
  honesty: DataHonestyReport(
    score: 20,
    reliability: DataReliability.insufficient,
    strengths: [],
    missing: ['More observations are needed'],
  ),
  daysAway: 0,
);

void _noop() {}
