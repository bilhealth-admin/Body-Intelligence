import 'package:body_intelligence_log/features/analytics/weekly_report_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'weekly report exposes recorded macros and activity without estimates',
    () {
      final report = const WeeklyReportEngine().build(
        asOf: DateTime.utc(2026, 8, 10),
        mealCount: 1,
        nutrition: const [
          WeeklyNutritionObservation(
            dayKey: '2026-08-10',
            calories: 500,
            proteinG: 30,
            carbsG: 50,
            fatG: 20,
            sodiumMg: 400,
            foodName: 'Lentil bowl',
          ),
        ],
        water: const [],
        weights: const [],
        activity: const [
          WeeklyActivityObservation(
            dayKey: '2026-08-10',
            steps: 4321,
            exerciseNotes: 'Walk',
          ),
        ],
        allTimeMealCount: 12,
        allTimeWeightCount: 3,
        allTimeExerciseDays: 4,
        allTimeSteps: 9000,
        dailyCalorieGoal: 2000,
        loggingStreakDays: 3,
      );
      expect(report.totalCarbsG, 50);
      expect(report.totalFatG, 20);
      expect(report.totalSteps, 4321);
      expect(report.exerciseDays, 1);
      expect(report.allTimeMealCount, 12);
      expect(report.dailyCalorieGoal, 2000);
      expect(report.frequentFoods, {'Lentil bowl': 1});
      expect(report.loggingStreakDays, 3);
    },
  );

  test('missing steps remain unavailable rather than becoming zero', () {
    final report = const WeeklyReportEngine().build(
      asOf: DateTime.utc(2026, 8, 10),
      mealCount: 0,
      nutrition: const [],
      water: const [],
      weights: const [],
    );
    expect(report.totalSteps, isNull);
    expect(report.allTimeSteps, isNull);
  });
}
