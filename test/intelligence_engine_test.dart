import 'package:body_intelligence_log/engine/bmr_engine.dart';
import 'package:body_intelligence_log/engine/body_profile.dart';
import 'package:body_intelligence_log/engine/intelligence_engine.dart';
import 'package:body_intelligence_log/engine/plan_engine.dart';
import 'package:body_intelligence_log/engine/share_metrics_engine.dart';
import 'package:body_intelligence_log/engine/nutrition_engine.dart';
import 'package:body_intelligence_log/engine/tdee_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'share metrics use behavior evidence and never require weight values',
    () {
      final result = ShareMetricsEngine.calculate(
        const [
          ShareDayEvidence(
            hasMeal: true,
            hasWeight: false,
            protein: 90,
            waterMl: 2200,
          ),
          ShareDayEvidence(
            hasMeal: false,
            hasWeight: true,
            protein: 0,
            waterMl: 0,
          ),
        ],
        proteinTarget: 100,
        waterTarget: 2500,
      );
      expect(result.consistentDays, 2);
      expect(result.proteinDays, 1);
      expect(result.hydrationDays, 1);
      expect(result.score, 67);
    },
  );
  test('plan recommendation is deterministic and overrides stay separate', () {
    const profile = BodyProfile(
      age: 35,
      gender: 'male',
      height: 180,
      weight: 85,
      targetWeight: 78,
      activityLevel: 'moderate',
      exercises: true,
      goalType: 'lose',
    );
    final recommendation = PlanEngine.recommend(profile);
    final effective = PlanEngine.effective(
      recommendation.targets,
      const PlanOverrides(calories: 2400),
    );
    expect(effective.calories, 2400);
    expect(recommendation.targets.calories, isNot(2400));
    expect(effective.protein, recommendation.targets.protein);
    expect(recommendation.assumptions, isNotEmpty);
  });

  const maintain = BodyProfile(
    age: 30,
    gender: 'male',
    height: 180,
    weight: 80,
    targetWeight: 80,
    activityLevel: 'moderate',
    exercises: true,
  );

  test('Mifflin St Jeor BMR and activity TDEE are deterministic', () {
    final bmr = BMREngine.calculate(maintain);
    expect(bmr, 1780);
    expect(TDEEEngine.calculate(bmr: bmr, activityLevel: 'moderate'), 2759);
  });

  test('calorie target follows lose maintain and gain goals', () {
    DailyTargetsFor goal(String type) {
      final profile = BodyProfile(
        age: maintain.age,
        gender: maintain.gender,
        height: maintain.height,
        weight: maintain.weight,
        targetWeight: type == 'lose'
            ? 70
            : type == 'gain'
            ? 90
            : 80,
        activityLevel: maintain.activityLevel,
        exercises: maintain.exercises,
        goalType: type,
      );
      final targets = NutritionEngine.calculate(profile: profile, tdee: 2500);
      return DailyTargetsFor(targets.calories, targets.protein);
    }

    expect(goal('lose').calories, 2000);
    expect(goal('maintain').calories, 2500);
    expect(goal('gain').calories, 2800);
    expect(goal('maintain').protein, greaterThan(0));
  });

  test('insights contain evidence, action, priority, and confidence', () {
    final report = IntelligenceEngine.evaluate(
      calorieTarget: 2000,
      proteinTarget: 130,
      waterTarget: 2800,
      calories: 1500,
      protein: 60,
      waterMl: 1000,
      chronologicalWeights: const [80, 79.8, 79.6, 79.4],
      goalWeight: 72,
      trackedDays: 4,
    );
    expect(report.score, inInclusiveRange(0, 100));
    expect(report.scoreConfidence, InsightConfidence.medium);
    expect(report.insights.first.evidence, isNotEmpty);
    expect(report.insights.first.suggestedAction, isNotEmpty);
  });

  test('plateau and water retention require sufficient observations', () {
    final plateau = IntelligenceEngine.evaluate(
      calorieTarget: 2000,
      proteinTarget: 100,
      waterTarget: 2500,
      calories: 2000,
      protein: 100,
      waterMl: 2500,
      chronologicalWeights: List<double>.generate(
        14,
        (index) => 80 + index * 0.002,
      ),
      goalWeight: 75,
      trackedDays: 14,
    );
    expect(
      plateau.insights.any((item) => item.title == 'Possible plateau'),
      isTrue,
    );

    final retention = IntelligenceEngine.evaluate(
      calorieTarget: 2000,
      proteinTarget: 100,
      waterTarget: 2500,
      calories: 2000,
      protein: 100,
      waterMl: 2500,
      chronologicalWeights: const [80, 80.2, 80.7, 81.2],
      goalWeight: 75,
      trackedDays: 4,
      sodium: 3000,
    );
    final insight = retention.insights.firstWhere(
      (item) => item.title == 'Possible short-term water retention',
    );
    expect(insight.confidence, InsightConfidence.low);
    expect(insight.explanation, contains('hypothesis'));
  });
}

class DailyTargetsFor {
  const DailyTargetsFor(this.calories, this.protein);
  final int calories;
  final int protein;
}
