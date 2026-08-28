import 'package:body_intelligence_log/engine/bil_engine.dart';
import 'package:body_intelligence_log/engine/body_composition_engine.dart';
import 'package:body_intelligence_log/engine/body_model_engine.dart';
import 'package:body_intelligence_log/engine/body_profile.dart';
import 'package:body_intelligence_log/engine/plan_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = BodyProfile(
    age: 30,
    gender: 'male',
    height: 180,
    weight: 80,
    targetWeight: 80,
    activityLevel: 'moderate',
    exercises: true,
    goalType: 'maintain',
    waistCm: 90,
    neckCm: 38,
  );

  test('canonical model combines real profile inputs deterministically', () {
    final model = BodyModelEngine.calculate(profile);

    expect(model.version, BodyModelEngine.version);
    expect(model.bmrKcal, 1780);
    expect(model.tdeeKcal, 2759);
    expect(model.composition.bodyMassIndex.value, closeTo(24.6914, 0.0001));
    expect(model.composition.waistToHeightRatio.value, 0.5);
    expect(
      model.composition.bodyFatPercentage.method,
      BodyFatEstimateMethod.circumferenceHodgdonBeckett,
    );
    expect(
      model.composition.fatFreeMassKg.value,
      closeTo(
        profile.weight * (1 - model.composition.bodyFatPercentage.value! / 100),
        0.0001,
      ),
    );
    expect(model.targets.calories, greaterThan(0));
    expect(model.targets.protein, greaterThan(0));
  });

  test('plan and live BIL consumers receive the exact canonical model', () {
    final canonical = BodyModelEngine.calculate(profile);
    final plan = PlanEngine.recommend(profile);
    final live = BILEngine.calculate(
      profile: profile,
      eatenCalories: 1000,
      eatenProtein: 50,
      drankWater: 1200,
    );

    expect(plan.bodyModel.version, canonical.version);
    expect(plan.bmr, canonical.bmrKcal);
    expect(plan.tdee, canonical.tdeeKcal);
    expect(plan.targets.calories, canonical.targets.calories);
    expect(
      plan.bodyModel.composition.bodyFatPercentage.value,
      canonical.composition.bodyFatPercentage.value,
    );
    expect(live.bodyModel.version, canonical.version);
    expect(live.targets.protein, canonical.targets.protein);
    expect(
      live.bodyModel.composition.leanBodyMassKg.value,
      canonical.composition.leanBodyMassKg.value,
    );
  });

  test('invalid required body inputs fail instead of fabricating outputs', () {
    expect(
      () => BodyModelEngine.calculate(
        const BodyProfile(
          age: 10,
          gender: 'male',
          height: 180,
          weight: 80,
          targetWeight: 80,
          activityLevel: 'moderate',
          exercises: true,
        ),
      ),
      throwsArgumentError,
    );
  });
}
