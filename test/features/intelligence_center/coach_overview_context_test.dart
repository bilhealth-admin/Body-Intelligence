import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_brief_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_native_command_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_overview_context_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 25, 12);

class _HeldNamePreferences extends PreferencesRepository {
  _HeldNamePreferences(super.database);
  Completer<String?>? hold;
  final entered = Completer<void>();

  @override
  Future<String?> get(String key) {
    if (key == 'displayName' && hold != null) {
      final pending = hold!;
      hold = null;
      entered.complete();
      return pending.future;
    }
    return super.get(key);
  }
}

class _Fixture {
  final db = AppDatabase.forTesting(
    NativeDatabase.memory(),
    localOwnerId: 'owner-a',
  );
  final owners = StreamController<String?>.broadcast(sync: true);
  String? owner = 'owner-a';
  late final preferences = _HeldNamePreferences(db);
  late ProviderContainer container;
  int fullContextReads = 0;

  Future<void> open({
    CoachContextPreferences scope = const CoachContextPreferences(),
  }) async {
    await preferences.set('displayName', 'Alex');
    await preferences.set(CoachContextPreferences.storageKey, scope.encode());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        preferencesRepositoryProvider.overrideWithValue(preferences),
        intelligenceConversationClockProvider.overrideWithValue(() => _now),
        coachNativeOwnerWitnessProvider.overrideWithValue(
          CoachNativeOwnerWitness(
            readOwner: () => owner,
            changes: owners.stream,
          ),
        ),
        coachContextSnapshotProvider.overrideWith((ref) async {
          fullContextReads++;
          throw StateError('Overview must never assemble model context');
        }),
        coachHealthBriefProvider.overrideWith(
          (ref) async => CoachContextSnapshot(
            generatedAt: _now,
            profile: const {'private': 'unneeded profile payload'},
            weights: [CoachWeightPoint(at: _now, kg: 81)],
            nutritionDays: const [
              CoachNutritionDay(
                day: '2026-10-25',
                meals: [],
                calories: 300,
                protein: 10,
                carbs: 20,
                fat: 8,
                sodium: 0,
              ),
            ],
            waterHistory: const [],
            computedHealth: const {
              'dailyTargets': {'caloriesKcal': 1800},
            },
            activityHistory: const [
              {'day': '2026-10-25', 'steps': 1234, 'notes': 'private note'},
            ],
          ),
        ),
      ],
    );
  }

  Future<void> close() async {
    container.dispose();
    await owners.close();
    await db.close();
  }

  Future<int> meal(DateTime date, {bool withFood = true}) async {
    final id = await db
        .into(db.meals)
        .insert(MealsCompanion.insert(date: date, dayKey: dayKeyFor(date)));
    if (withFood) {
      final food = await db
          .into(db.foods)
          .insert(
            FoodsCompanion.insert(
              name: 'private fixture food name',
              calories: 100,
              protein: 2,
              carbs: 10,
              fats: 3,
            ),
          );
      await db
          .into(db.mealItems)
          .insert(MealItemsCompanion.insert(mealId: id, foodId: food));
    }
    return id;
  }
}

void main() {
  test(
    'Overview reads only actual current-day counts and latest water, without rich context or food text',
    () async {
      final fixture = _Fixture();
      await fixture.meal(_now);
      await fixture.meal(_now, withFood: false);
      await fixture.meal(_now.subtract(const Duration(days: 1)));
      await fixture.meal(_now.add(const Duration(days: 1)));
      final water = WaterRepository(fixture.db);
      await water.add(
        occurredAt: _now.subtract(const Duration(days: 1)),
        amountMl: 700,
      );
      await water.add(
        occurredAt: _now.subtract(const Duration(hours: 2)),
        amountMl: 300,
      );
      await water.add(
        occurredAt: _now.subtract(const Duration(hours: 1)),
        amountMl: 450,
      );
      await fixture.open();
      addTearDown(fixture.close);
      final subscription = fixture.container.listen(
        coachOverviewContextProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final result = await fixture.container.read(
        coachOverviewContextProvider.future,
      );
      expect(result.recordedMealCount, 1);
      expect(result.snapshot.waterHistory.single['amountMl'], 450);
      expect(result.snapshot.minimalIdentity['displayName'], 'Alex');
      expect(result.snapshot.nutritionDays.single.calories, 300);
      expect(fixture.fullContextReads, 0);
      final payload = jsonEncode(result.snapshot.toJson());
      expect(payload, isNot(contains('private fixture food name')));
      expect(payload, isNot(contains('private note')));
      expect(payload, isNot(contains('unneeded profile payload')));
      expect(result.snapshot.activityHistory.single.keys.toSet(), {
        'day',
        'steps',
      });
    },
  );

  test(
    'withheld categories stay withheld even if a supporting source contains data',
    () async {
      final fixture = _Fixture();
      await fixture.open(scope: const CoachContextPreferences(focuses: {}));
      addTearDown(fixture.close);
      final subscription = fixture.container.listen(
        coachOverviewContextProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final result = await fixture.container.read(
        coachOverviewContextProvider.future,
      );
      expect(result.recordedMealCount, isNull);
      expect(result.snapshot.weights, isEmpty);
      expect(result.snapshot.weightReadStatus, CoachWeightReadStatus.withheld);
      expect(result.snapshot.nutritionDays, isEmpty);
      expect(result.snapshot.waterHistory, isEmpty);
      expect(result.snapshot.computedHealth, isEmpty);
      expect(result.snapshot.activityHistory, isEmpty);
      expect(fixture.fullContextReads, 0);
    },
  );

  test('a delivered owner A B A retires an in-flight Overview read', () async {
    final fixture = _Fixture();
    await fixture.open();
    addTearDown(fixture.close);
    final held = Completer<String?>();
    fixture.preferences.hold = held;
    final subscription = fixture.container.listen(
      coachOverviewContextProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final pending = fixture.container.read(coachOverviewContextProvider.future);
    final rejected = expectLater(pending, throwsA(isA<CoachNativeConflict>()));
    await fixture.preferences.entered.future;
    fixture.owner = 'owner-b';
    fixture.owners.add('owner-b');
    fixture.owner = 'owner-a';
    fixture.owners.add('owner-a');
    held.complete('retired owner name');
    await rejected;
    expect(fixture.fullContextReads, 0);
  });

  test('a timed-out read cannot publish its late account name', () async {
    final fixture = _Fixture();
    await fixture.open();
    addTearDown(fixture.close);
    final held = Completer<String?>();
    fixture.preferences.hold = held;
    final values = <CoachOverviewContext>[];
    final subscription = fixture.container.listen(
      coachOverviewContextProvider,
      (_, next) {
        final data = next.asData?.value;
        if (data != null) values.add(data);
      },
    );
    addTearDown(subscription.close);
    await expectLater(
      fixture.container.read(coachOverviewContextProvider.future),
      throwsA(isA<TimeoutException>()),
    );
    held.complete('late name');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(values, isEmpty);
    expect(
      fixture.container.read(coachOverviewContextProvider).hasError,
      isTrue,
    );
  });
}
