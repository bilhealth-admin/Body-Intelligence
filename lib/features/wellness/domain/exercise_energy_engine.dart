import 'dart:math' as math;

/// Provenance of a movement-energy value. Only a connected, device-verified
/// active-energy signal may change the daily allowance.
enum ExerciseEnergySource { manualEstimate, connectedActiveEnergy }

final class ExerciseEnergyRecord {
  const ExerciseEnergyRecord({
    required this.id,
    required this.kcal,
    required this.source,
    required this.observedAt,
    this.deviceVerified = false,
  });

  final String id;
  final double kcal;
  final ExerciseEnergySource source;
  final DateTime observedAt;
  final bool deviceVerified;
}

final class ExerciseCalorieEstimate {
  const ExerciseCalorieEstimate({
    required this.kcal,
    required this.met,
    required this.weightKg,
    required this.durationMinutes,
  });

  final double kcal;
  final double met;
  final double weightKg;
  final int durationMinutes;
}

/// Deterministic manual estimate using MET × kilograms × elapsed hours.
///
/// This is an estimate, never a measured value, and callers must keep
/// [ExerciseEnergySource.manualEstimate] out of the calorie allowance.
abstract final class ExerciseEnergyEngine {
  static ExerciseCalorieEstimate? estimate({
    required double met,
    required double weightKg,
    required int durationMinutes,
  }) {
    if (!met.isFinite ||
        !weightKg.isFinite ||
        met < 1 ||
        met > 25 ||
        weightKg < 20 ||
        weightKg > 500 ||
        durationMinutes < 1 ||
        durationMinutes > 24 * 60) {
      return null;
    }
    final kcal = met * weightKg * (durationMinutes / 60);
    return ExerciseCalorieEstimate(
      kcal: kcal,
      met: met,
      weightKg: weightKg,
      durationMinutes: durationMinutes,
    );
  }

  static double metFor({required String id, required String category}) {
    final known = <String, double>{
      'walk': 4.3,
      'run': 8.3,
      'cycle': 7.5,
      'swim': 6.0,
      'hike': 6.0,
      'stairs': 8.8,
      'row': 7.0,
      'dance': 6.5,
      'strength': 5.0,
      'upper': 5.0,
      'lower': 5.0,
      'core': 4.0,
      'circuit': 6.0,
      'mobility': 2.5,
      'stretch': 2.3,
      'yoga': 2.5,
      'pilates': 3.0,
      'breathing': 1.5,
    };
    return known[id] ??
        switch (category.toLowerCase()) {
          'cardio' => 6.0,
          'strength' => 5.0,
          'recovery' => 2.5,
          _ => 3.5,
        };
  }
}

final class DailyEnergyBudget {
  const DailyEnergyBudget({
    required this.baseKcal,
    required this.consumedKcal,
    required this.verifiedBurnedKcal,
    required this.estimatedManualKcal,
    required this.netKcal,
    required this.remainingKcal,
    required this.burnedIncreasesAllowance,
  });

  final double baseKcal;
  final double consumedKcal;
  final double verifiedBurnedKcal;
  final double estimatedManualKcal;
  final double netKcal;
  final double remainingKcal;
  final bool burnedIncreasesAllowance;
}

abstract final class DailyEnergyBudgetEngine {
  static DailyEnergyBudget resolve({
    required double baseKcal,
    required double consumedKcal,
    required Iterable<ExerciseEnergyRecord> records,
    bool burnedIncreasesAllowance = false,
  }) {
    final safeBase = baseKcal.isFinite ? math.max(0, baseKcal).toDouble() : 0.0;
    final safeConsumed = consumedKcal.isFinite
        ? math.max(0, consumedKcal).toDouble()
        : 0.0;
    final seen = <String>{};
    var verified = 0.0;
    var estimated = 0.0;
    for (final record in records) {
      if (!seen.add(record.id) || !record.kcal.isFinite || record.kcal <= 0) {
        continue;
      }
      if (record.source == ExerciseEnergySource.connectedActiveEnergy &&
          record.deviceVerified) {
        verified += record.kcal;
      } else if (record.source == ExerciseEnergySource.manualEstimate) {
        estimated += record.kcal;
      }
    }
    final net = math.max(0.0, safeConsumed - verified).toDouble();
    final remaining = math
        .max(
          0.0,
          safeBase - safeConsumed + (burnedIncreasesAllowance ? verified : 0),
        )
        .toDouble();
    return DailyEnergyBudget(
      baseKcal: safeBase,
      consumedKcal: safeConsumed,
      verifiedBurnedKcal: verified,
      estimatedManualKcal: estimated,
      netKcal: net,
      remainingKcal: remaining,
      burnedIncreasesAllowance: burnedIncreasesAllowance,
    );
  }
}
