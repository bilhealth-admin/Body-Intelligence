import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_brief_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_read_guard.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_daily_brief.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_native_command_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Fixture fixture;

  setUp(() => fixture = _Fixture());
  tearDown(() => fixture.close());

  test('read tools map to only their required local context category', () {
    expect(coachHealthFocus('read_fasting', {}), CoachContextFocus.habits);
    expect(coachHealthFocus('preview_plan', {}), CoachContextFocus.nutrition);
    expect(
      coachHealthFocus('read_health_progress', {}),
      CoachContextFocus.analytics,
    );
    for (final entry in {
      'daily': CoachContextFocus.nutrition,
      'sleep': CoachContextFocus.habits,
      'activity': CoachContextFocus.training,
      'weight': CoachContextFocus.analytics,
      'measurements': CoachContextFocus.analytics,
    }.entries) {
      expect(
        coachHealthFocus('read_health_history', {'topic': entry.key}),
        entry.value,
      );
    }
    expect(coachHealthFocus('open_route', {}), isNull);
  });

  test(
    'read guard rejects an excluded category and closes its subscription',
    () async {
      final preferences = _ControlledPreferences(fixture.database)
        ..raw = _focuses({CoachContextFocus.nutrition});
      addTearDown(preferences.close);
      await expectLater(
        CoachHealthReadGuard.capture(
          preferences: preferences,
          focus: CoachContextFocus.habits,
          checkOwner: fixture.scopeCheck,
        ),
        throwsA(isA<CoachHealthContextUnavailable>()),
      );
      expect(preferences.readCount, 1);
      expect(preferences.changes.hasListener, isFalse);
      fixture.expectNoHealthReads();
    },
  );

  test(
    'a category-free read checks ownership without reading preferences',
    () async {
      final preferences = _ControlledPreferences(fixture.database);
      addTearDown(preferences.close);
      final guard = await CoachHealthReadGuard.capture(
        preferences: preferences,
        focus: null,
        checkOwner: fixture.scopeCheck,
      );
      await guard.verify();
      expect(preferences.readCount, 0);
      expect(preferences.changes.hasListener, isFalse);
      fixture.scope.cancel();
      expect(guard.check, throwsA(_ownerConflict));
      await guard.close();
    },
  );

  test(
    'denied read returns before delayed cancellation and contains a later cleanup error',
    () async {
      final preferences = _DelayedCancellationPreferences(fixture.database);
      try {
        await expectLater(
          CoachHealthReadGuard.capture(
            preferences: preferences,
            focus: CoachContextFocus.habits,
            checkOwner: fixture.scopeCheck,
          ).timeout(const Duration(seconds: 2)),
          throwsA(isA<CoachHealthContextUnavailable>()),
        );
        expect(preferences.cancelStarted.isCompleted, isTrue);
        expect(preferences.releaseCancellation.isCompleted, isFalse);
        preferences.releaseCancellation.complete();
        await Future<void>.delayed(Duration.zero);
        fixture.expectNoHealthReads();
      } finally {
        await preferences.close();
      }
    },
  );

  test(
    'a delivered category revoke stays latched after re-enabling it',
    () async {
      final preferences = _ControlledPreferences(fixture.database)
        ..raw = _focuses({CoachContextFocus.habits});
      addTearDown(preferences.close);
      final guard = await CoachHealthReadGuard.capture(
        preferences: preferences,
        focus: CoachContextFocus.habits,
        checkOwner: fixture.scopeCheck,
      );
      preferences.emit(_focuses({}));
      preferences.emit(_focuses({CoachContextFocus.habits}));
      expect(guard.check, throwsA(isA<CoachHealthContextUnavailable>()));
      await expectLater(
        guard.verify(),
        throwsA(isA<CoachHealthContextUnavailable>()),
      );
      await guard.close();
      expect(preferences.changes.hasListener, isFalse);
    },
  );

  test(
    'A to B to A during a guarded preference read cannot revive its owner visit',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final preferences = _ControlledPreferences(fixture.database)
        ..raw = _focuses({CoachContextFocus.habits});
      addTearDown(preferences.close);
      final guard = await CoachHealthReadGuard.capture(
        preferences: preferences,
        focus: CoachContextFocus.habits,
        checkOwner: fixture.scopeCheck,
      );
      preferences.beforeRead = () async {
        entered.complete();
        await release.future;
      };
      final pending = expectLater(guard.verify(), throwsA(_ownerConflict));
      await entered.future;
      fixture.switchOwner('synthetic-owner-b');
      fixture.scope.cancel();
      fixture.switchOwner('synthetic-owner-a');
      release.complete();
      await pending;
      await guard.close();
    },
  );

  test(
    'a read exception cannot hide owner cancellation after its await',
    () async {
      final preferences = _ControlledPreferences(fixture.database)
        ..raw = _focuses({CoachContextFocus.habits});
      addTearDown(preferences.close);
      final guard = await CoachHealthReadGuard.capture(
        preferences: preferences,
        focus: CoachContextFocus.habits,
        checkOwner: fixture.scopeCheck,
      );
      preferences.beforeRead = () async {
        fixture.scope.cancel();
        throw StateError('synthetic read failure');
      };
      await expectLater(guard.verify(), throwsA(_ownerConflict));
      await guard.close();
    },
  );

  test(
    'closing a read guard removes observation and invalidates further use',
    () async {
      final preferences = _ControlledPreferences(fixture.database)
        ..raw = _focuses({CoachContextFocus.training});
      addTearDown(preferences.close);
      final guard = await CoachHealthReadGuard.capture(
        preferences: preferences,
        focus: CoachContextFocus.training,
        checkOwner: fixture.scopeCheck,
      );
      expect(preferences.changes.hasListener, isTrue);
      await guard.close();
      expect(preferences.changes.hasListener, isFalse);
      expect(guard.check, throwsA(isA<CoachHealthContextUnavailable>()));
    },
  );

  test(
    'real Drift guard close completes while another preference watcher remains active',
    () async {
      await fixture.setFocuses({CoachContextFocus.habits});
      final ready = Completer<void>();
      final changed = Completer<void>();
      final emptyFocus = _focuses({});
      final otherWatcher = fixture.preferences
          .watch(CoachContextPreferences.storageKey)
          .listen((raw) {
            if (!ready.isCompleted) ready.complete();
            if (raw == emptyFocus && !changed.isCompleted) changed.complete();
          });
      try {
        await ready.future.timeout(const Duration(seconds: 2));
        final guard = await CoachHealthReadGuard.capture(
          preferences: fixture.preferences,
          focus: CoachContextFocus.habits,
          checkOwner: fixture.scopeCheck,
        );
        await guard.close().timeout(const Duration(seconds: 2));
        expect(guard.check, throwsA(isA<CoachHealthContextUnavailable>()));
        await fixture.preferences.set(
          CoachContextPreferences.storageKey,
          emptyFocus,
        );
        await changed.future.timeout(const Duration(seconds: 2));
      } finally {
        await otherWatcher.cancel().timeout(const Duration(seconds: 2));
      }
    },
  );

  test(
    'an explicitly empty focus set skips every health repository read',
    () async {
      await fixture.setFocuses({});
      final snapshot = await fixture.readBrief();
      fixture.expectNoHealthReads();
      expect(snapshot.profile, isEmpty);
      expect(snapshot.weights, isEmpty);
      expect(snapshot.nutritionDays, isEmpty);
      expect(snapshot.computedHealth, isEmpty);
      expect(snapshot.activityHistory, isEmpty);
      fixture.expectNoFullContext(snapshot);
    },
  );

  test(
    'habits-only brief preserves zero sleep without exposing training or nutrition',
    () async {
      await fixture.setFocuses({CoachContextFocus.habits});
      await fixture.daily.save(
        date: fixture.today,
        sleepHours: 0,
        steps: 7300,
        notes: 'private note outside the short brief',
        exerciseNotes: 'private workout outside the short brief',
      );
      final snapshot = await fixture.readBrief();
      expect(fixture.daily.dayReads, [dayKeyFor(fixture.today)]);
      expect(fixture.daily.ledgerReads, isEmpty);
      expect(fixture.weights.dayReads, isEmpty);
      expect(fixture.profiles.readCount, 0);
      expect(fixture.schedule.readCount, 0);
      expect(snapshot.activityHistory, [
        {'day': dayKeyFor(fixture.today), 'sleepHours': 0},
      ]);
      expect(snapshot.toJson().toString(), isNot(contains('private')));
      fixture.expectNoFullContext(snapshot);
    },
  );

  test('training-only brief preserves zero steps and excludes sleep', () async {
    await fixture.setFocuses({CoachContextFocus.training});
    await fixture.daily.save(date: fixture.today, sleepHours: 7, steps: 0);
    final snapshot = await fixture.readBrief();
    expect(snapshot.activityHistory, [
      {'day': dayKeyFor(fixture.today), 'steps': 0},
    ]);
    expect(fixture.daily.dayReads, [dayKeyFor(fixture.today)]);
    expect(fixture.daily.ledgerReads, isEmpty);
    expect(fixture.weights.dayReads, isEmpty);
    expect(fixture.schedule.readCount, 0);
    fixture.expectNoFullContext(snapshot);
  });

  test(
    'analytics reads exactly seven civil days and excludes older, future, deleted and invalid weights',
    () async {
      await fixture.setFocuses({CoachContextFocus.analytics});
      final writer = WeightRepository(fixture.database);
      for (var offset = -1; offset < 10; offset++) {
        final day = fixture.dayAgo(offset);
        final id = await writer.addWeight(80 + offset.toDouble(), date: day);
        if (offset == 2) await writer.deleteWeight(id);
        if (offset == 3) {
          await (fixture.database.update(fixture.database.weightEntries)
                ..where((row) => row.id.equals(id)))
              .write(const WeightEntriesCompanion(weight: Value(0)));
        }
      }
      final snapshot = await fixture.readBrief();
      expect(fixture.weights.dayReads, [
        for (var offset = 0; offset < 7; offset++)
          dayKeyFor(fixture.dayAgo(offset)),
      ]);
      expect(snapshot.weights.map((row) => dayKeyFor(row.at)), [
        for (final offset in [0, 1, 4, 5, 6]) dayKeyFor(fixture.dayAgo(offset)),
      ]);
      expect(snapshot.weights.map((row) => row.kg), [80, 81, 84, 85, 86]);
      expect(fixture.profiles.readCount, 1);
      expect(fixture.daily.dayReads, isEmpty);
      expect(fixture.daily.ledgerReads, isEmpty);
      expect(fixture.schedule.readCount, 0);
      fixture.expectNoFullContext(snapshot);
    },
  );

  test(
    'partial nutrition keeps unknown macros absent and never derives a false remaining total',
    () async {
      await fixture.setFocuses({CoachContextFocus.nutrition});
      await fixture.savePercentageGoal();
      await MealRepository(fixture.database).addQuickMacroEntry(
        date: fixture.today,
        mealType: 'lunch',
        calories: 300,
        protein: 0,
        carbohydrates: 0,
        fat: 0,
        caloriesKnown: true,
        proteinKnown: false,
        carbohydratesKnown: true,
        fatKnown: false,
      );
      final snapshot = await fixture.readBrief();
      final day = snapshot.nutritionDays.single;
      expect(day.knownTotals, {'caloriesKcal', 'carbsG'});
      expect(day.toJson()['totals'], {'caloriesKcal': 300, 'carbsG': 0});
      expect(snapshot.nutritionRemainingFor(fixture.today), isNull);
      for (final locale in ['en', 'ar']) {
        final brief = const CoachDailyBriefEngine().build(
          context: snapshot,
          now: fixture.today,
          locale: locale,
        );
        expect(brief.kind, isNot(CoachDailyBriefKind.nutrition));
        expect(brief.message, isNot(contains('1700')));
      }
      expect(fixture.daily.ledgerReads, [dayKeyFor(fixture.today)]);
      expect(fixture.weights.dayReads, isEmpty);
      fixture.expectNoFullContext(snapshot);
    },
  );

  test(
    'explicit known zero nutrition remains zero in both English and Arabic briefs',
    () async {
      await fixture.setFocuses({CoachContextFocus.nutrition});
      await fixture.savePercentageGoal();
      // Persist an explicit, valid zero-evidence meal snapshot. Quick Add has
      // its own all-zero input restriction, which this read test preserves.
      final foodId = await fixture.database
          .into(fixture.database.foods)
          .insert(
            FoodsCompanion.insert(
              name: 'Synthetic zero-evidence food',
              calories: 0,
              protein: 0,
              carbs: 0,
              fats: 0,
            ),
          );
      final mealId = await fixture.database
          .into(fixture.database.meals)
          .insert(
            MealsCompanion.insert(
              date: fixture.today,
              dayKey: dayKeyFor(fixture.today),
              type: const Value('snack'),
            ),
          );
      await fixture.database
          .into(fixture.database.mealItems)
          .insert(
            MealItemsCompanion.insert(
              mealId: mealId,
              foodId: foodId,
              calories: const Value(0),
              protein: const Value(0),
              carbs: const Value(0),
              fats: const Value(0),
              nutrientEvidenceMask: Value(
                NutrientEvidenceMask.fromValues(
                  calories: 0,
                  protein: 0,
                  carbohydrates: 0,
                  fat: 0,
                ),
              ),
            ),
          );
      final snapshot = await fixture.readBrief();
      expect(snapshot.nutritionDays.single.toJson()['totals'], {
        'caloriesKcal': 0,
        'proteinG': 0,
        'carbsG': 0,
        'fatG': 0,
      });
      final remaining = snapshot.nutritionRemainingFor(fixture.today)!;
      expect(remaining['caloriesKcal'], 2000);
      expect(remaining['proteinG'], 150);
      for (final locale in ['en', 'ar']) {
        final brief = const CoachDailyBriefEngine().build(
          context: snapshot,
          now: fixture.today,
          locale: locale,
        );
        expect(brief.kind, CoachDailyBriefKind.nutrition);
        expect(brief.message, contains('150'));
        expect(brief.message, contains('2000'));
        expect(brief.evidenceLabel, contains('0'));
        expect(brief.message, isNot(contains('{')));
      }
      fixture.expectNoFullContext(snapshot);
    },
  );

  test(
    'saved weekly targets win over conflicting defaults and gram overrides',
    () async {
      await fixture.setFocuses({CoachContextFocus.nutrition});
      await fixture.savePercentageGoal();
      await fixture.preferences.setMany({
        'goal.proteinGrams': '180',
        'goal.carbsGrams': '100',
        'goal.fatGrams': '90',
      });
      const target = NutritionGoalTarget(
        calories: 2400,
        carbsPercent: 50,
        proteinPercent: 25,
        fatPercent: 25,
      );
      await fixture.schedule.saveDay(fixture.today.weekday, target);
      final snapshot = await fixture.readBrief();
      final persisted = (await NutritionGoalScheduleRepository(
        fixture.preferences,
      ).read()).targetFor(fixture.today)!;
      final targets = snapshot.computedHealth['dailyTargets']! as Map;
      expect(targets['caloriesKcal'], persisted.calories);
      expect(targets['proteinG'], persisted.proteinGrams);
      expect(targets['carbsG'], persisted.carbsGrams);
      expect(targets['fatG'], closeTo(persisted.fatGrams, .0000001));
      fixture.expectNoFullContext(snapshot);
    },
  );

  test(
    'valid saved percentage defaults retain the existing gram conversion',
    () async {
      await fixture.setFocuses({CoachContextFocus.nutrition});
      await fixture.savePercentageGoal();
      final snapshot = await fixture.readBrief();
      final targets = snapshot.computedHealth['dailyTargets']! as Map;
      expect(targets['caloriesKcal'], 2000);
      expect(targets['proteinG'], 150);
      expect(targets['carbsG'], 250);
      expect(targets['fatG'], closeTo(2000 * .2 / 9, .0000001));
      fixture.expectNoFullContext(snapshot);
    },
  );

  test(
    'no saved goals or meal evidence creates neither a target nor zero intake',
    () async {
      await fixture.setFocuses({CoachContextFocus.nutrition});
      await fixture.daily.startDay(fixture.today);
      await fixture.daily.closeDay(fixture.today);
      final snapshot = await fixture.readBrief();
      expect(snapshot.computedHealth.containsKey('dailyTargets'), isFalse);
      expect(snapshot.nutritionDays, isEmpty);
      expect(snapshot.nutritionRemainingFor(fixture.today), isNull);
      for (final locale in ['en', 'ar']) {
        expect(
          const CoachDailyBriefEngine()
              .build(context: snapshot, now: fixture.today, locale: locale)
              .kind,
          isNot(CoachDailyBriefKind.nutrition),
        );
      }
      fixture.expectNoFullContext(snapshot);
    },
  );

  test(
    'an incomplete or invalid saved goal is omitted instead of completed with invented zeros',
    () async {
      await fixture.setFocuses({CoachContextFocus.nutrition});
      await fixture.preferences.setMany({
        'goal.calories': '2000',
        'goal.proteinPercent': '30',
        'goal.fatPercent': 'NaN',
        'goal.proteinGrams': '150',
      });
      final snapshot = await fixture.readBrief();
      expect(snapshot.computedHealth.containsKey('dailyTargets'), isFalse);
      fixture.expectNoFullContext(snapshot);
    },
  );

  test(
    'brief rejects A to B to A during a repository await before any health result escapes',
    () async {
      await fixture.setFocuses({CoachContextFocus.analytics});
      final entered = Completer<void>();
      final release = Completer<void>();
      fixture.profiles.beforeRead = () async {
        entered.complete();
        await release.future;
      };
      final pending = expectLater(fixture.readBrief(), throwsA(_ownerConflict));
      await entered.future;
      fixture.switchOwner('synthetic-owner-b');
      fixture.switchOwner('synthetic-owner-a');
      release.complete();
      await pending;
      expect(fixture.published, isEmpty);
      expect(fixture.weights.dayReads, isEmpty);
      expect(fixture.daily.dayReads, isEmpty);
    },
  );

  test(
    'an initial witness owner mismatch rejects the brief before personal reads',
    () async {
      await fixture.setFocuses({CoachContextFocus.analytics});
      fixture.switchOwner('synthetic-owner-b');
      await expectLater(fixture.readBrief(), throwsA(_ownerConflict));
      fixture.expectNoHealthReads();
      expect(fixture.published, isEmpty);
    },
  );

  test(
    'a saved goal edit invalidates the short brief and publishes the latest target',
    () async {
      await fixture.setFocuses({CoachContextFocus.nutrition});
      await fixture.savePercentageGoal();
      final initial = await fixture.readBrief();
      expect(
        (initial.computedHealth['dailyTargets'] as Map)['caloriesKcal'],
        2000,
      );
      final refreshed = fixture.waitFor(
        (snapshot) =>
            (snapshot.computedHealth['dailyTargets']
                as Map?)?['caloriesKcal'] ==
            2200,
      );
      await fixture.preferences.set('goal.calories', '2200');
      final next = await refreshed;
      expect((next.computedHealth['dailyTargets'] as Map)['proteinG'], 165);
      fixture.expectNoFullContext(next);
    },
  );

  test(
    'a same-day meal write refreshes the brief using only the current ledger',
    () async {
      await fixture.setFocuses({CoachContextFocus.nutrition});
      final initial = await fixture.readBrief();
      expect(initial.nutritionDays, isEmpty);
      final refreshed = fixture.waitFor(
        (snapshot) => snapshot.nutritionDays.firstOrNull?.knownCalories == 120,
      );
      await MealRepository(fixture.database).addQuickMacroEntry(
        date: fixture.today,
        mealType: 'lunch',
        calories: 120,
        protein: 0,
        carbohydrates: 0,
        fat: 0,
        caloriesKnown: true,
        proteinKnown: false,
        carbohydratesKnown: false,
        fatKnown: false,
      );
      final next = await refreshed;
      expect(
        fixture.daily.ledgerReads.every(
          (day) => day == dayKeyFor(fixture.today),
        ),
        isTrue,
      );
      expect(fixture.weights.dayReads, isEmpty);
      expect(next.nutritionDays.single.toJson()['totals'], {
        'caloriesKcal': 120,
      });
      fixture.expectNoFullContext(next);
    },
  );
}

final _ownerConflict = isA<CoachNativeConflict>().having(
  (error) => error.reason,
  'reason',
  CoachNativeConflictReason.ownerChanged,
);

String _focuses(Set<CoachContextFocus> values) =>
    CoachContextPreferences(focuses: values).encode();

final class _Fixture {
  final database = AppDatabase.forTesting(
    NativeDatabase.memory(),
    localOwnerId: 'synthetic-owner-a',
  );
  final today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  late final preferences = PreferencesRepository(database);
  late final daily = _DailyReads(database);
  late final weights = _WeightReads(database);
  late final profiles = _ProfileReads(database);
  late final schedule = _ScheduleReads(preferences);
  final owners = StreamController<String?>.broadcast(sync: true);
  String? owner = 'synthetic-owner-a';
  late final scope = CoachNativeOwnerScope(
    ownerId: database.localOwnerId,
    isCurrent: () => owner == database.localOwnerId,
  );
  final published = <CoachContextSnapshot>[];
  final changes = StreamController<CoachContextSnapshot>.broadcast(sync: true);
  ProviderContainer? container;
  int completeContextReads = 0;

  void scopeCheck() => scope.check(database.localOwnerId);
  void switchOwner(String? next) {
    owner = next;
    owners.add(next);
  }

  DateTime dayAgo(int offset) =>
      DateTime(today.year, today.month, today.day - offset);
  Future<void> setFocuses(Set<CoachContextFocus> values) =>
      preferences.set(CoachContextPreferences.storageKey, _focuses(values));
  Future<void> savePercentageGoal() => preferences.setMany({
    'goal.calories': '2000',
    'goal.carbsPercent': '50',
    'goal.proteinPercent': '30',
    'goal.fatPercent': '20',
  });

  Future<CoachContextSnapshot> readBrief() {
    container ??=
        ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            databaseProvider.overrideWithValue(database),
            preferencesRepositoryProvider.overrideWithValue(preferences),
            dailyLogRepositoryProvider.overrideWithValue(daily),
            weightRepositoryProvider.overrideWithValue(weights),
            userProfileRepositoryProvider.overrideWithValue(profiles),
            nutritionGoalScheduleRepositoryProvider.overrideWithValue(schedule),
            coachNativeOwnerWitnessProvider.overrideWithValue(
              CoachNativeOwnerWitness(
                readOwner: () => owner,
                changes: owners.stream,
              ),
            ),
            coachContextSnapshotProvider.overrideWith((ref) {
              completeContextReads++;
              throw StateError(
                'The short brief must never assemble complete context',
              );
            }),
          ],
        )..listen(coachHealthBriefProvider, (_, value) {
          final snapshot = value.asData?.value;
          if (snapshot != null && !value.isLoading) {
            published.add(snapshot);
            changes.add(snapshot);
          }
        }, fireImmediately: true);
    return container!.read(coachHealthBriefProvider.future);
  }

  Future<CoachContextSnapshot> waitFor(
    bool Function(CoachContextSnapshot) predicate,
  ) => changes.stream.firstWhere(predicate).timeout(const Duration(seconds: 3));

  void expectNoHealthReads() {
    expect(daily.dayReads, isEmpty);
    expect(daily.ledgerReads, isEmpty);
    expect(weights.dayReads, isEmpty);
    expect(profiles.readCount, 0);
    expect(schedule.readCount, 0);
    expect(completeContextReads, 0);
  }

  void expectNoFullContext(CoachContextSnapshot snapshot) {
    expect(completeContextReads, 0);
    expect(daily.fullHistoryReads, 0);
    expect(weights.fullHistoryReads, 0);
    expect(snapshot.waterHistory, isEmpty);
    expect(snapshot.explicitMemories, isEmpty);
    expect(snapshot.decisionMemory, isEmpty);
    expect(snapshot.personalExperiments, isEmpty);
    expect(snapshot.bodyContextHistory, isEmpty);
  }

  Future<void> close() async {
    container?.dispose();
    await owners.close();
    await changes.close();
    await database.close();
  }
}

class _DelayedCancellationPreferences extends PreferencesRepository {
  _DelayedCancellationPreferences(super.database);
  final cancelStarted = Completer<void>();
  final releaseCancellation = Completer<void>();
  late final changes = StreamController<String?>(
    onCancel: () async {
      cancelStarted.complete();
      await releaseCancellation.future;
      throw StateError('Synthetic delayed cancellation failure');
    },
  );

  @override
  Future<String?> get(String key) async => _focuses({});

  @override
  Stream<String?> watch(String key) => changes.stream;

  Future<void> close() async {
    if (!releaseCancellation.isCompleted) releaseCancellation.complete();
    await changes.close();
  }
}

class _ControlledPreferences extends PreferencesRepository {
  _ControlledPreferences(super.database);
  String? raw;
  int readCount = 0;
  Future<void> Function()? beforeRead;
  final changes = StreamController<String?>.broadcast(sync: true);

  @override
  Future<String?> get(String key) async {
    expect(key, CoachContextPreferences.storageKey);
    readCount++;
    await beforeRead?.call();
    return raw;
  }

  @override
  Stream<String?> watch(String key) {
    expect(key, CoachContextPreferences.storageKey);
    return changes.stream;
  }

  void emit(String? value) {
    raw = value;
    changes.add(value);
  }

  Future<void> close() => changes.close();
}

class _DailyReads extends DailyLogRepository {
  _DailyReads(super.database);
  final dayReads = <String>[];
  final ledgerReads = <String>[];
  int fullHistoryReads = 0;

  @override
  Future<DailyLog?> getForDay(DateTime date) {
    dayReads.add(dayKeyFor(date));
    return super.getForDay(date);
  }

  @override
  Future<AuthoritativeDailyLedger> readLedger(DateTime date) {
    ledgerReads.add(dayKeyFor(date));
    return super.readLedger(date);
  }

  @override
  Future<List<DailyLog>> getAll() {
    fullHistoryReads++;
    throw StateError('Unbounded daily history is forbidden in the short brief');
  }

  @override
  Stream<List<DailyLog>> watchAll() {
    fullHistoryReads++;
    throw StateError(
      'Unbounded daily observation is forbidden in the short brief',
    );
  }
}

class _WeightReads extends WeightRepository {
  _WeightReads(super.database);
  final dayReads = <String>[];
  int fullHistoryReads = 0;

  @override
  Future<WeightEntry?> getForDay(DateTime date) {
    dayReads.add(dayKeyFor(date));
    return super.getForDay(date);
  }

  @override
  Future<List<WeightEntry>> getAll() {
    fullHistoryReads++;
    throw StateError(
      'Unbounded weight history is forbidden in the short brief',
    );
  }

  @override
  Stream<List<WeightEntry>> watchWeights() {
    fullHistoryReads++;
    throw StateError(
      'Unbounded weight observation is forbidden in the short brief',
    );
  }
}

class _ProfileReads extends UserProfileRepository {
  _ProfileReads(super.database);
  int readCount = 0;
  Future<void> Function()? beforeRead;

  @override
  Future<UserProfileData?> getProfile() async {
    readCount++;
    await beforeRead?.call();
    return super.getProfile();
  }
}

class _ScheduleReads extends NutritionGoalScheduleRepository {
  _ScheduleReads(super.preferences);
  int readCount = 0;

  @override
  Future<NutritionGoalSchedule> read() {
    readCount++;
    return super.read();
  }
}
