import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/goal_repository.dart';
import 'package:body_intelligence_log/data/repositories/plan_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/engine/daily_targets.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late UserProfileRepository profiles;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    profiles = UserProfileRepository(database);
  });
  tearDown(() => database.close());

  Future<void> saveProfile({double weight = 80}) => profiles.save(
    gender: 'male',
    age: 35,
    height: 180,
    currentWeight: weight,
    targetWeight: 75,
    activityLevel: 'moderate',
    exercises: true,
  );

  test(
    'profile edits preserve goal identity and custom plan targets',
    () async {
      await saveProfile();
      final profile = (await profiles.getProfile())!;
      final goals = GoalRepository(database);
      final plans = PlanRepository(database);
      await goals.save(
        profileUuid: profile.uuid,
        type: 'lose',
        targetWeight: 75,
      );
      await plans.save(
        profileUuid: profile.uuid,
        recommended: const DailyTargets(
          calories: 2000,
          protein: 140,
          carbs: 230,
          fats: 65,
          potassium: 3500,
          sodium: 2300,
          fiber: 25,
          water: 2500,
        ),
        calories: 2100,
        protein: 150,
        water: 3000,
      );
      final goal = (await goals.getActive())!;
      final plan = (await plans.getForProfile(profile.uuid))!;

      await saveProfile(weight: 79);

      final updated = (await profiles.getProfile())!;
      expect(updated.uuid, profile.uuid);
      expect(updated.id, profile.id);
      expect(updated.currentWeight, 79);
      expect(updated.revision, profile.revision + 1);
      expect(await goals.getActive(), goal);
      expect(await plans.getForProfile(profile.uuid), plan);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'concurrent profile saves retain one source of truth and both revisions',
    () async {
      await Future.wait([saveProfile(), saveProfile(weight: 79)]);
      final rows = await database.select(database.userProfile).get();
      expect(rows, hasLength(1));
      expect(rows.single.revision, 2);
      expect(rows.single.currentWeight, 79);
    },
  );

  for (final value in [double.nan, double.infinity, double.negativeInfinity]) {
    test('goal rejects non-finite target $value before any write', () async {
      await saveProfile();
      final profile = (await profiles.getProfile())!;
      final goals = GoalRepository(database);
      await goals.save(
        profileUuid: profile.uuid,
        type: 'lose',
        targetWeight: 75,
      );
      final original = (await goals.getActive())!;
      await expectLater(
        goals.save(
          uuid: original.uuid,
          profileUuid: profile.uuid,
          type: 'lose',
          targetWeight: value,
        ),
        throwsArgumentError,
      );
      expect(await goals.getActive(), original);
    });
  }
}
