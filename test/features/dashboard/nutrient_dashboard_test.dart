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
      TrackedNutrient.potassium,
    ]);
    expect(NutrientDashboardPreset.carbConscious.evidenceMetrics, [
      TrackedNutrient.carbohydrates,
      TrackedNutrient.sugar,
      TrackedNutrient.fiber,
    ]);
    expect(NutrientDashboardPreset.caloriesAndMacros.evidenceMetrics, isEmpty);
  });

  test('partial nutrient evidence retains only the known subtotal', () {
    final known = NutrientDashboardSample(
      evidenceMask: NutrientEvidenceMask.bit(TrackedNutrient.sodium),
      values: const {TrackedNutrient.sodium: 400},
    );
    const unknown = NutrientDashboardSample(evidenceMask: 0, values: {});
    final partial = NutrientDashboardEvidence.total([
      known,
      unknown,
    ], TrackedNutrient.sodium);
    expect(partial.value, 400);
    expect(partial.complete, isFalse);
    expect(
      NutrientDashboardEvidence.total([unknown], TrackedNutrient.sodium).value,
      isNull,
    );
    final complete = NutrientDashboardEvidence.total([
      known,
    ], TrackedNutrient.sodium);
    expect(complete.value, 400);
    expect(complete.complete, isTrue);
  });

  test(
    'sodium, sugar, fiber and potassium never invent missing quantities',
    () {
      const nutrients = [
        TrackedNutrient.sodium,
        TrackedNutrient.sugar,
        TrackedNutrient.fiber,
        TrackedNutrient.potassium,
      ];
      for (final nutrient in nutrients) {
        final present = NutrientDashboardSample(
          evidenceMask: NutrientEvidenceMask.bit(nutrient),
          values: {nutrient: 37.5},
        );
        final knownZero = NutrientDashboardSample(
          evidenceMask: NutrientEvidenceMask.bit(nutrient),
          values: {nutrient: 0},
        );
        const absent = NutrientDashboardSample(evidenceMask: 0, values: {});
        final partial = NutrientDashboardEvidence.total([
          present,
          absent,
          knownZero,
        ], nutrient);
        expect(partial.value, 37.5);
        expect(partial.complete, isFalse);
        expect(
          NutrientDashboardEvidence.total([
            present,
            knownZero,
          ], nutrient).complete,
          isTrue,
        );
        expect(
          NutrientDashboardEvidence.total([absent], nutrient).value,
          isNull,
        );
      }
    },
  );

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
