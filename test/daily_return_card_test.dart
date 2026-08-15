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
  testWidgets('Arabic missed-day return has one calm primary action', (
    tester,
  ) async {
    var actions = 0;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        DailyReturnCard(
          report: _report(DailyReturnState.gentleReturn, primary: true),
          changedSummary: 'نحتاج قياسًا آخر لوصف التغير.',
          actionTitle: 'سجّل وزن اليوم',
          actionReason: 'القياس المتقارب يحسن ثقة الاتجاه.',
          missingEvidence: 'نحتاج أيامًا متقاربة أكثر.',
          onPrimaryAction: () => actions++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.monitor_weight_outlined), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
    expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsNWidgets(3));
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(DailyReturnCard), findsOneWidget);
    expect(actions, 0);
  });

  testWidgets('completed day presents no-action state without a button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        DailyReturnCard(
          report: _report(DailyReturnState.complete, primary: false),
          changedSummary: 'No meaningful change can be concluded.',
          actionTitle: 'Unused',
          actionReason: 'Unused',
          missingEvidence: 'More comparable days improve confidence.',
          onPrimaryAction: () {},
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Meals'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('daily return remains a presentation-only logging path', (
    tester,
  ) async {
    var dismissed = 0;
    var corrected = 0;
    var feedback = 0;

    await tester.pumpWidget(
      _app(
        DailyReturnCard(
          report: _report(DailyReturnState.partial, primary: true),
          changedSummary: 'Weight rose while meal timing shifted.',
          actionTitle: 'Log today\'s weight',
          actionReason:
              'A comparable morning measurement improves direction confidence.',
          missingEvidence: 'Two additional comparable days are missing.',
          recommendationTimeHorizon: 'Reassess over the next 3 days.',
          alternativeExplanation:
              'Temporary fluid retention remains plausible from recent sodium intake.',
          onPrimaryAction: () {},
          onDismissRecommendation: () => dismissed++,
          onCorrectRecommendation: () => corrected++,
          onRecommendationFeedback: () => feedback++,
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Meals'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.byIcon(Icons.cancel_rounded), findsNWidgets(3));
    expect(find.text('Why this action appears'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(dismissed, 0);
    expect(corrected, 0);
    expect(feedback, 0);
  });
}

DailyReturnReport _report(DailyReturnState state, {required bool primary}) =>
    DailyReturnReport(
      state: state,
      hasWeight: state == DailyReturnState.complete,
      hasMeals: state == DailyReturnState.complete,
      hasWater: state == DailyReturnState.complete,
      bestAction: BestAction(
        type: primary ? BestActionType.weighIn : BestActionType.none,
        title: 'Action',
        reason: 'Reason',
        evidence: const ['Evidence'],
      ),
      changed: const WhatChangedReport(
        interpretation: ChangeInterpretation.insufficient,
        summary: 'Insufficient',
        evidence: [],
        alternatives: [],
      ),
      honesty: const DataHonestyReport(
        score: 20,
        reliability: DataReliability.insufficient,
        strengths: [],
        missing: ['Missing'],
      ),
      daysAway: state == DailyReturnState.gentleReturn ? 6 : 0,
    );

Widget _app(Widget home, {Locale locale = const Locale('ar')}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: SingleChildScrollView(child: home)),
);
