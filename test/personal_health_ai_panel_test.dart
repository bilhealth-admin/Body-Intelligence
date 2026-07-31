import 'package:body_intelligence_log/features/ai_platform/domain/personal_health_ai.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/personal_health_ai_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('panel is responsive and exposes honest learning states', (
    tester,
  ) async {
    final trend = WeightTrendEstimate(
      state: HealthAiLearningState.initial,
      observedChangeKg: -0.2,
      kgPerDay: -0.1,
      lowerKgPerDay: -0.3,
      upperKgPerDay: 0.1,
      confidence: 0.2,
      observationCount: 2,
      evidence: const ['two valid weights'],
      missingEvidence: const ['more comparable measurements'],
    );
    final snapshot = PersonalHealthAiSnapshot(
      asOf: DateTime(2026, 7, 25, 12),
      fullJourney: trend,
      currentPhase: trend,
      tdee: AdaptiveTdeeEstimate(
        state: HealthAiLearningState.initial,
        kcal: 2200,
        lowerKcal: 1760,
        upperKcal: 2640,
        confidence: 0.25,
        formulaPriorKcal: 2200,
        evidence: const ['formula prior'],
        missingEvidence: const ['calorie evidence'],
      ),
      tissueFluid: TissueFluidEstimate(
        observedChangeKg: -0.2,
        probableTissueChangeKg: null,
        probableFluidChangeKg: null,
        unexplainedChangeKg: -0.2,
        confidence: 0.2,
        evidence: const ['scale change'],
        missingEvidence: const ['calorie evidence'],
      ),
      plateauState: HealthAiLearningState.initial,
      goalForecastState: HealthAiLearningState.learning,
    );
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 520,
            child: PersonalHealthAiPanel(
              snapshot: snapshot,
              arabic: false,
              todayHasMeals: false,
              decisionCount: 0,
              compact: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('personal-health-ai-panel')), findsOneWidget);
    expect(find.text('Bio Intelligence'), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      await tester.drag(
        find.byKey(const Key('dashboard-twin-deck-carousel')),
        const Offset(-340, 0),
      );
      await tester.pumpAndSettle();
    }
    expect(
      find.text('Too early for a reliable plateau assessment'),
      findsOneWidget,
    );
    expect(find.textContaining('No confidence yet'), findsWidgets);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('personal-health-ai-panel')),
      matchesGoldenFile('goldens/personal_health_ai_panel_phone.png'),
    );
  });
}
