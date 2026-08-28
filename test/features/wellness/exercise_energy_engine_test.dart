import 'package:body_intelligence_log/features/wellness/domain/exercise_energy_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual MET estimate is explicit and deterministic', () {
    final estimate = ExerciseEnergyEngine.estimate(
      met: 5,
      weightKg: 90,
      durationMinutes: 30,
    );
    expect(estimate, isNotNull);
    expect(estimate!.kcal, 225);
  });

  test('manual estimates never increase remaining calories', () {
    final budget = DailyEnergyBudgetEngine.resolve(
      baseKcal: 2000,
      consumedKcal: 1500,
      records: [
        ExerciseEnergyRecord(
          id: 'manual-1',
          kcal: 300,
          source: ExerciseEnergySource.manualEstimate,
          observedAt: DateTime.utc(2026, 8, 23),
        ),
      ],
      burnedIncreasesAllowance: true,
    );
    expect(budget.estimatedManualKcal, 300);
    expect(budget.verifiedBurnedKcal, 0);
    expect(budget.remainingKcal, 500);
  });

  test(
    'verified active energy is deduped and user policy controls allowance',
    () {
      final records = [
        ExerciseEnergyRecord(
          id: 'health-connect-event-1',
          kcal: 400,
          source: ExerciseEnergySource.connectedActiveEnergy,
          observedAt: DateTime.utc(2026, 8, 23),
          deviceVerified: true,
        ),
        ExerciseEnergyRecord(
          id: 'health-connect-event-1',
          kcal: 400,
          source: ExerciseEnergySource.connectedActiveEnergy,
          observedAt: DateTime.utc(2026, 8, 23),
          deviceVerified: true,
        ),
        ExerciseEnergyRecord(
          id: 'unverified',
          kcal: 999,
          source: ExerciseEnergySource.connectedActiveEnergy,
          observedAt: DateTime.utc(2026, 8, 23),
        ),
      ];
      final fixed = DailyEnergyBudgetEngine.resolve(
        baseKcal: 2000,
        consumedKcal: 1500,
        records: records,
      );
      final adaptive = DailyEnergyBudgetEngine.resolve(
        baseKcal: 2000,
        consumedKcal: 1500,
        records: records,
        burnedIncreasesAllowance: true,
      );

      expect(fixed.verifiedBurnedKcal, 400);
      expect(fixed.netKcal, 1100);
      expect(fixed.remainingKcal, 500);
      expect(adaptive.remainingKcal, 900);
    },
  );
}
