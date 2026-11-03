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
  bool suppressScopeEvents = false;
  StreamController<String?>? scopeEvents;
  final entered = Completer<void>();

  @override
  Stream<String?> watch(String key) =>
      key == CoachContextPreferences.storageKey && suppressScopeEvents
      ? const Stream.empty()
      : key == CoachContextPreferences.storageKey && scopeEvents != null
      ? scopeEvents!.stream
      : super.watch(key);

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
  DateTime now = _now;
  double calories = 300;
  double targetCalories = 1800;
  Object? briefFailure;
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
        intelligenceConversationClockProvider.overrideWithValue(() => now),
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
        coachHealthBriefProvider.overrideWith((ref) async {
          if (briefFailure != null) throw briefFailure!;
          return CoachContextSnapshot(
            generatedAt: now,
            profile: const {'private': 'unneeded profile payload'},
            weights: [CoachWeightPoint(at: _now, kg: 81)],
            nutritionDays: [
              CoachNutritionDay(
                day: dayKeyFor(now),
                meals: [],
                calories: calories,
                protein: 10,
                carbs: 20,
                fat: 8,
                sodium: 0,
              ),
            ],
            waterHistory: const [],
            computedHealth: {
              'dailyTargets': {'caloriesKcal': targetCalories},
            },
            activityHistory: const [
              {'day': '2026-10-25', 'steps': 1234, 'notes': 'private note'},
            ],
          );
        }),
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
  test('a silent permission stream fails within its bounded read', () async {
    final fixture = _Fixture();
    await fixture.open();
    fixture.briefFailure = StateError('early unavailable brief');
    fixture.preferences.suppressScopeEvents = true;
    addTearDown(fixture.close);
    final subscription = fixture.container.listen(
      coachOverviewPresentationContextProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await expectLater(
      fixture.container.read(coachOverviewContextProvider.future),
      throwsA(isA<TimeoutException>()),
    );
    expect(
      fixture.container.read(coachOverviewPresentationContextProvider),
      isNull,
    );
    expect(fixture.fullContextReads, 0);
  });

  test(
    'a fresh consent event recovers after a transient stream error',
    () async {
      final fixture = _Fixture();
      await fixture.open();
      final events = StreamController<String?>.broadcast(sync: true);
      fixture.preferences.scopeEvents = events;
      addTearDown(() async {
        await fixture.close();
        await events.close();
      });
      final subscription = fixture.container.listen(
        coachOverviewPresentationContextProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final scope = const CoachContextPreferences().encode();
      events.add(scope);
      await fixture.container.read(coachOverviewContextProvider.future);
      expect(
        fixture.container.read(coachOverviewPresentationContextProvider),
        isNotNull,
      );
      events.addError(StateError('synthetic permission stream unavailable'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        fixture.container.read(coachOverviewPresentationContextProvider),
        isNull,
      );
      fixture.container.read(coachOverviewContextProvider.future).ignore();
      events.add(scope);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await fixture.container.read(coachOverviewContextProvider.future);
      expect(
        fixture.container.read(coachOverviewPresentationContextProvider),
        isNotNull,
      );
    },
  );

  test(
    'same-visit local refresh keeps the exact previous snapshot until the new value arrives',
    () async {
      final fixture = _Fixture();
      await fixture.open();
      addTearDown(fixture.close);
      final subscription = fixture.container.listen(
        coachOverviewPresentationContextProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await fixture.container.read(coachOverviewContextProvider.future);
      final before = fixture.container.read(
        coachOverviewPresentationContextProvider,
      )!;
      final held = Completer<String?>();
      fixture.preferences.hold = held;
      await fixture.preferences.set('displayName', 'New current name');
      await fixture.preferences.entered.future;
      expect(
        fixture.container.read(coachOverviewContextProvider).isLoading,
        isTrue,
      );
      expect(
        identical(
          fixture.container.read(coachOverviewPresentationContextProvider),
          before,
        ),
        isTrue,
      );
      expect(before.snapshot.nutritionDays.single.calories, 300);
      held.complete('New current name');
      await fixture.container.read(coachOverviewContextProvider.future);
      final after = fixture.container.read(
        coachOverviewPresentationContextProvider,
      )!;
      expect(after.snapshot.minimalIdentity['displayName'], 'New current name');
      expect(identical(after, before), isFalse);
    },
  );

  test(
    'permission revocation cannot retain old nutrition or accept a late private snapshot',
    () async {
      final fixture = _Fixture();
      await fixture.open();
      addTearDown(fixture.close);
      final subscription = fixture.container.listen(
        coachOverviewPresentationContextProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await fixture.container.read(coachOverviewContextProvider.future);
      expect(
        fixture.container
            .read(coachOverviewPresentationContextProvider)!
            .snapshot
            .nutritionDays,
        isNotEmpty,
      );
      final held = Completer<String?>();
      fixture.preferences.hold = held;
      await fixture.preferences.set('displayName', 'pending private name');
      await fixture.preferences.entered.future;
      fixture.container.read(coachOverviewContextProvider.future).ignore();
      await fixture.preferences.set(
        CoachContextPreferences.storageKey,
        const CoachContextPreferences(focuses: {}).encode(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final during = fixture.container.read(
        coachOverviewPresentationContextProvider,
      );
      expect(during?.snapshot.nutritionDays ?? const [], isEmpty);
      held.complete('retired private name');
      await fixture.container.read(coachOverviewContextProvider.future);
      final after = fixture.container.read(
        coachOverviewPresentationContextProvider,
      )!;
      expect(after.snapshot.nutritionDays, isEmpty);
      expect(after.snapshot.computedHealth, isEmpty);
      expect(
        after.snapshot.minimalIdentity['displayName'],
        isNot('retired private name'),
      );
    },
  );

  test(
    'a rapid owner visit clears retained presentation until a fresh read',
    () async {
      final fixture = _Fixture();
      await fixture.open();
      addTearDown(fixture.close);
      final subscription = fixture.container.listen(
        coachOverviewPresentationContextProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await fixture.container.read(coachOverviewContextProvider.future);
      final before = fixture.container.read(
        coachOverviewPresentationContextProvider,
      )!;
      final held = Completer<String?>();
      fixture.preferences.hold = held;
      await fixture.preferences.set('displayName', 'new visit name');
      await fixture.preferences.entered.future;
      final retired = expectLater(
        fixture.container.read(coachOverviewContextProvider.future),
        throwsA(isA<CoachNativeConflict>()),
      );
      fixture.owner = 'owner-b';
      fixture.owners.add('owner-b');
      fixture.owner = 'owner-a';
      fixture.owners.add('owner-a');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        identical(
          fixture.container.read(coachOverviewPresentationContextProvider),
          before,
        ),
        isFalse,
      );
      held.complete('retired owner name');
      await retired;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await fixture.container.read(coachOverviewContextProvider.future);
      final after = fixture.container.read(
        coachOverviewPresentationContextProvider,
      )!;
      expect(after.snapshot.minimalIdentity['displayName'], 'new visit name');
    },
  );

  test(
    'a fresh diary and target result replaces the retained snapshot',
    () async {
      final fixture = _Fixture();
      await fixture.open();
      addTearDown(fixture.close);
      final subscription = fixture.container.listen(
        coachOverviewPresentationContextProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await fixture.container.read(coachOverviewContextProvider.future);
      final before = fixture.container.read(
        coachOverviewPresentationContextProvider,
      )!;
      final held = Completer<String?>();
      fixture.preferences.hold = held;
      fixture.calories = 500;
      fixture.targetCalories = 2100;
      fixture.container.invalidate(coachHealthBriefProvider);
      await fixture.preferences.entered.future;
      expect(
        identical(
          fixture.container.read(coachOverviewPresentationContextProvider),
          before,
        ),
        isTrue,
      );
      held.complete('Alex');
      await fixture.container.read(coachOverviewContextProvider.future);
      final after = fixture.container.read(
        coachOverviewPresentationContextProvider,
      )!;
      expect(after.snapshot.nutritionDays.single.calories, 500);
      expect(after.snapshot.computedHealth['dailyTargets'], {
        'caloriesKcal': 2100.0,
      });
      expect(identical(after, before), isFalse);
    },
  );

  test('a new civil day never displays yesterday during its read', () async {
    final fixture = _Fixture();
    await fixture.open();
    addTearDown(fixture.close);
    final subscription = fixture.container.listen(
      coachOverviewPresentationContextProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await fixture.container.read(coachOverviewContextProvider.future);
    fixture.now = _now.add(const Duration(days: 1));
    // Model the day refresh fired by the boundary's midnight timer. The clock
    // override itself is one stable callback, so invalidating that callback
    // alone would not notify dependents in Riverpod.
    fixture.container.invalidate(coachOverviewContextProvider);
    expect(
      fixture.container.read(coachOverviewPresentationContextProvider),
      isNull,
    );
    await expectLater(
      fixture.container.read(coachOverviewContextProvider.future),
      throwsStateError,
    );
    // Model the brief's independent midnight invalidation too. A cached
    // yesterday brief is refused before that source provides the new day.
    final held = Completer<String?>();
    fixture.preferences.hold = held;
    fixture.container.invalidate(coachHealthBriefProvider);
    await fixture.preferences.entered.future;
    expect(
      fixture.container.read(coachOverviewPresentationContextProvider),
      isNull,
    );
    held.complete('Alex');
    await fixture.container.read(coachOverviewContextProvider.future);
    final after = fixture.container.read(
      coachOverviewPresentationContextProvider,
    )!;
    expect(after.snapshot.generatedAt, fixture.now);
    expect(after.snapshot.nutritionDays.single.day, '2026-10-26');
  });

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
