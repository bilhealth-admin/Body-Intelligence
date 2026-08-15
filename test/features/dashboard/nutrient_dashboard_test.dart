import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/features/dashboard/domain/nutrient_dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preset names match persisted Diary contract', () {
    expect(
      NutrientDashboardPreset.parse('Heart healthy'),
      NutrientDashboardPreset.heartHealthy,
    );
    expect(
      NutrientDashboardPreset.parse('Low carb'),
      NutrientDashboardPreset.carbConscious,
    );
    expect(
      NutrientDashboardPreset.parse('Custom'),
      NutrientDashboardPreset.custom,
    );
    expect(NutrientDashboardPreset.heartHealthy.evidenceMetrics, [
      TrackedNutrient.sodium,
      TrackedNutrient.fiber,
    ]);
    expect(NutrientDashboardPreset.carbConscious.evidenceMetrics, [
      TrackedNutrient.carbohydrates,
      TrackedNutrient.sugar,
      TrackedNutrient.fiber,
    ]);
    expect(NutrientDashboardPreset.caloriesAndMacros.evidenceMetrics, isEmpty);
  });

  test('a missing nutrient snapshot keeps the aggregate unknown', () {
    final known = NutrientDashboardSample(
      evidenceMask: NutrientEvidenceMask.bit(TrackedNutrient.sodium),
      values: const {TrackedNutrient.sodium: 400},
    );
    const unknown = NutrientDashboardSample(evidenceMask: 0, values: {});
    expect(
      NutrientDashboardEvidence.total([
        known,
        unknown,
      ], TrackedNutrient.sodium).value,
      isNull,
    );
    expect(
      NutrientDashboardEvidence.total([known], TrackedNutrient.sodium).value,
      400,
    );
  });

  test('progress policy distinguishes minimum and upper-limit goals', () {
    expect(
      NutrientProgressPolicy.evaluate(value: 30, goal: 30, minimumGoal: true),
      NutrientProgressState.reached,
    );
    expect(
      NutrientProgressPolicy.evaluate(
        value: 2400,
        goal: 2300,
        minimumGoal: false,
      ),
      NutrientProgressState.exceeded,
    );
    expect(
      NutrientProgressPolicy.evaluate(value: null, goal: 30, minimumGoal: true),
      NutrientProgressState.unknown,
    );
  });
}
