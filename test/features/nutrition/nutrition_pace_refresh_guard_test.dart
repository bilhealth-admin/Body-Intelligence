import 'dart:async';

import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrition_pace_intent.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_defaults_provider.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_snapshot_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nutrition_onboarding_pace_persistence_test.dart'
    show PacePersistenceFixture, holdPaceInputs, waitDefaults, waitSnapshot;

class ControlledPacePreferences extends PreferencesRepository {
  ControlledPacePreferences(super.database) {
    events = StreamController<String?>.broadcast(
      sync: true,
      onListen: () {
        if (!listened.isCompleted) listened.complete();
      },
    );
  }

  final listened = Completer<void>();
  late final StreamController<String?> events;

  @override
  Stream<String?> watch(String key) =>
      key == NutritionPaceIntent.storageKey ? events.stream : super.watch(key);
}

Future<AsyncValue<NutritionPaceIntent>> waitPace(
  ProviderContainer container,
  PreferencesRepository repository,
  bool Function(AsyncValue<NutritionPaceIntent>) matches,
) {
  final done = Completer<AsyncValue<NutritionPaceIntent>>();
  final subscription = container.listen(
    nutritionPaceIntentProvider(repository),
    (previous, next) {
      if (!done.isCompleted && matches(next)) done.complete(next);
    },
    fireImmediately: true,
  );
  return done.future
      .timeout(const Duration(seconds: 5))
      .whenComplete(subscription.close);
}

void main() {
  test(
    'same-owner refresh and read failure retain the last valid pace display',
    () async {
      final f = await PacePersistenceFixture.create('pace-refresh');
      final repository = ControlledPacePreferences(f.db);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(f.db),
          preferencesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final inputClosers = <void Function()>[];
      addTearDown(() async {
        for (final close in inputClosers.reversed) {
          close();
        }
        container.dispose();
        await repository.events.close();
        await f.close();
      });
      inputClosers.addAll(await holdPaceInputs(container));
      final seen = <double?>[];
      final display = container.listen(nutritionGoalDefaultsProvider, (
        _,
        next,
      ) {
        seen.add(next['goal.calories']);
      }, fireImmediately: true);
      addTearDown(display.close);
      await repository.listened.future;
      repository.events.add(
        await f.preferences.get(NutritionPaceIntent.storageKey),
      );
      await waitDefaults(container, (goals) => goals['goal.calories'] == 1633);
      await waitSnapshot(container, 1633);
      final visible = <double?>[];
      final snapshotDisplay = container.listen(
        nutritionGoalCurrentSnapshotProvider,
        (_, next) => visible.add(next?.goals['goal.calories']?.value),
        fireImmediately: true,
      );
      addTearDown(snapshotDisplay.close);
      expect(visible.single, 1633);
      seen.clear();
      container.invalidate(nutritionPaceIntentProvider(repository));
      final refreshing = container.read(
        nutritionPaceIntentProvider(repository),
      );
      expect(refreshing.isLoading, isTrue);
      expect(refreshing.value!.weeklyPaceKg, -.75);
      expect(
        container
            .read(nutritionGoalCurrentSnapshotProvider)!
            .goals['goal.calories']!
            .value,
        1633,
      );
      expect(
        container.read(nutritionGoalDefaultsProvider)['goal.calories'],
        1633,
      );
      repository.events.addError(
        StateError('synthetic read failure'),
        StackTrace.current,
      );
      final failed = await waitPace(
        container,
        repository,
        (state) => state.hasError,
      );
      expect(failed.value!.weeklyPaceKg, -.75);
      expect(
        container
            .read(nutritionGoalCurrentSnapshotProvider)!
            .goals['goal.calories']!
            .value,
        1633,
      );
      expect(
        container.read(nutritionGoalDefaultsProvider)['goal.calories'],
        1633,
      );
      repository.events.add('{corrupt');
      await waitPace(
        container,
        repository,
        (state) => state.error is FormatException,
      );
      expect(
        container.read(nutritionGoalDefaultsProvider)['goal.calories'],
        1633,
      );
      repository.events.add(
        await f.preferences.get(NutritionPaceIntent.storageKey),
      );
      await waitPace(
        container,
        repository,
        (state) => !state.isLoading && !state.hasError,
      );
      expect(
        container
            .read(nutritionGoalCurrentSnapshotProvider)!
            .goals['goal.calories']!
            .value,
        1633,
      );
      expect(seen.every((calories) => calories == 1633), isTrue);
      expect(visible.every((calories) => calories == 1633), isTrue);
    },
  );

  test(
    'initial pending or corrupt pace never invents legacy500 macros; manual wins',
    () async {
      final f = await PacePersistenceFixture.create('pace-corrupt');
      final repository = ControlledPacePreferences(f.db);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(f.db),
          preferencesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final inputClosers = <void Function()>[];
      addTearDown(() async {
        for (final close in inputClosers.reversed) {
          close();
        }
        container.dispose();
        await repository.events.close();
        await f.close();
      });
      inputClosers.addAll(await holdPaceInputs(container));
      inputClosers.add(
        container.listen(nutritionGoalDefaultsProvider, (_, _) {}).close,
      );
      expect(
        container.read(nutritionGoalDefaultsProvider)['goal.calories'],
        isNull,
      );
      await repository.listened.future;
      await f.preferences.setMany({
        'goal.calories': '1800',
        'goal.carbsPercent': '45',
        'goal.proteinPercent': '25',
        'goal.fatPercent': '30',
      });
      expect(
        (await waitSnapshot(container, 1800)).goals['goal.proteinGrams']!.value,
        112.5,
      );
      await f.preferences.set(NutritionPaceIntent.storageKey, '{corrupt');
      repository.events.add(
        await f.preferences.get(NutritionPaceIntent.storageKey),
      );
      await waitPace(container, repository, (state) => state.hasError);
      expect(
        container.read(nutritionGoalDefaultsProvider)['goal.calories'],
        isNull,
      );
      expect(
        (await waitSnapshot(container, 1800)).goals['goal.calories']!.value,
        1800,
      );
    },
  );

  test(
    'owner switch discards previous intent and ignores the old owners late stream',
    () async {
      final a = await PacePersistenceFixture.create('pace-owner-a');
      final b = await PacePersistenceFixture.create('pace-owner-b');
      await b.preferences.remove(NutritionPaceIntent.storageKey);
      final repositoryA = ControlledPacePreferences(a.db);
      final repositoryB = ControlledPacePreferences(b.db);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(a.db),
          preferencesRepositoryProvider.overrideWithValue(repositoryA),
        ],
      );
      final inputClosers = <void Function()>[];
      addTearDown(() async {
        for (final close in inputClosers.reversed) {
          close();
        }
        container.dispose();
        await repositoryA.events.close();
        await repositoryB.events.close();
        await a.close();
        await b.close();
      });
      inputClosers.addAll(await holdPaceInputs(container));
      final display = container.listen(
        nutritionGoalDefaultsProvider,
        (_, next) {},
      );
      addTearDown(display.close);
      await repositoryA.listened.future;
      repositoryA.events.add(
        await a.preferences.get(NutritionPaceIntent.storageKey),
      );
      await waitDefaults(container, (goals) => goals['goal.calories'] == 1633);
      container.updateOverrides([
        databaseProvider.overrideWithValue(b.db),
        preferencesRepositoryProvider.overrideWithValue(repositoryB),
      ]);
      inputClosers.addAll(await holdPaceInputs(container));
      await repositoryB.listened.future;
      expect(
        container.read(nutritionGoalDefaultsProvider)['goal.calories'],
        isNull,
      );
      repositoryA.events.add('{"version":1,"weeklyPaceKg":-0.25}');
      expect(
        container.read(nutritionGoalDefaultsProvider)['goal.calories'],
        isNull,
      );
      repositoryB.events.add(
        await b.preferences.get(NutritionPaceIntent.storageKey),
      );
      final own = await waitDefaults(
        container,
        (goals) => goals['goal.calories'] != null,
      );
      expect(own['goal.calories'], 1958);
      expect(await b.preferences.get(NutritionPaceIntent.storageKey), isNull);
    },
  );
}
