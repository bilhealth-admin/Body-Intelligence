import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrition_goal_snapshot.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_defaults_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final state in [
    'loading',
    'storageError',
    'absent',
    'manualDuringFailure',
  ]) {
    test(
      'real goal defaults distinguish $state without inventing maintenance targets',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.userProfile)
            .insert(
              UserProfileCompanion.insert(
                gender: 'male',
                age: 30,
                height: 180,
                currentWeight: 80,
                targetWeight: 75,
                activityLevel: 'sedentary',
                exercises: false,
              ),
            );
        final profile = await db.select(db.userProfile).getSingle();
        final goal = state == 'loading'
            ? const AsyncValue<Goal?>.loading()
            : state == 'absent'
            ? const AsyncValue<Goal?>.data(null)
            : AsyncValue<Goal?>.error(
                StateError('fixture storage failure'),
                StackTrace.current,
              );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            userProfileProvider.overrideWithValue(AsyncData(profile)),
            activeGoalProvider.overrideWithValue(goal),
            effectiveCurrentWeightProvider.overrideWithValue(80),
            planSettingProvider(
              profile.uuid,
            ).overrideWithValue(const AsyncData(null)),
          ],
        );
        addTearDown(container.dispose);
        final defaults = container.read(nutritionGoalDefaultsProvider);
        expect(defaults['goal.fiber'], 28);
        if (state == 'absent') {
          expect(defaults['goal.calories'], greaterThan(0));
          expect(
            defaults['goal.carbsPercent']! +
                defaults['goal.proteinPercent']! +
                defaults['goal.fatPercent']!,
            closeTo(100, .000001),
          );
        } else {
          expect(defaults.containsKey('goal.calories'), isFalse);
          expect(defaults.containsKey('goal.proteinPercent'), isFalse);
        }
        if (state == 'manualDuringFailure') {
          final prefs = PreferencesRepository(db);
          await prefs.setMany({
            'goal.calories': '1000',
            'goal.carbsPercent': '45',
            'goal.proteinPercent': '20',
            'goal.fatPercent': '35',
          });
          final stored = await prefs
              .watchSnapshot(NutritionGoalSnapshot.storageKeys)
              .first;
          final resolved = NutritionGoalSnapshot.resolve(stored, defaults);
          expect(resolved.goals['goal.calories']!.value, 1000);
          expect(resolved.goals['goal.carbsGrams']!.value, 112.5);
          expect(resolved.goals['goal.proteinGrams']!.value, 50);
          expect(
            resolved.goals['goal.fatGrams']!.value,
            closeTo(38.8888888889, .000001),
          );
        }
      },
    );
  }
}
