import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/goal_repository.dart';
import 'package:body_intelligence_log/data/repositories/plan_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/engine/daily_targets.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrition_pace_intent.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_defaults_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/profile_auth_identity_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/reference_goals_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';

const _ownerA = 'goals-owned-A', _ownerB = 'goals-owned-B';
final _firstDate = DateTime(2026, 11, 18);

class _HeldReadPreferences extends PreferencesRepository {
  _HeldReadPreferences(super.database);
  final entered = Completer<void>(), release = Completer<String?>();
  bool once = false;
  @override
  Future<String?> get(String key) async {
    if (key == 'goals.startingWeight' && !once) {
      once = true;
      entered.complete();
      return release.future;
    }
    return super.get(key);
  }
}

class _HeldWritePreferences extends PreferencesRepository {
  _HeldWritePreferences(super.database);
  bool armed = false;
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    if (armed && values.containsKey(NutritionPaceIntent.storageKey)) {
      armed = false;
      // Hold after a real first write; owner retirement must roll back BOTH
      // legacy and pace rather than leave a mixed committed snapshot.
      await super.setManyInCurrentTransaction({
        'goals.weeklyRate': values['goals.weeklyRate']!,
      });
      entered.complete();
      await release.future;
      final rest = Map<String, String>.from(values)..remove('goals.weeklyRate');
      await super.setManyInCurrentTransaction(rest);
      return;
    }
    return super.setManyInCurrentTransaction(values);
  }
}

class _FailedGoalRead extends GoalRepository {
  _FailedGoalRead(super.database);
  bool failNext = true;
  @override
  Future<Goal?> getActive() {
    if (failNext) {
      failNext = false;
      return Future<Goal?>.error(StateError('synthetic goal read unavailable'));
    }
    return super.getActive();
  }
}

Future<AppDatabase> _seed(
  String owner, {
  MeasurementSystem system = MeasurementSystem.imperial,
}) async {
  final db = AppDatabase.forTesting(
    NativeDatabase.memory(),
    localOwnerId: owner,
  );
  final current = UnitConverter.weightToKg(180, MeasurementSystem.imperial);
  final target = UnitConverter.weightToKg(170, MeasurementSystem.imperial);
  await UserProfileRepository(db).save(
    gender: 'male',
    age: 30,
    height: 170.18,
    currentWeight: current,
    targetWeight: target,
    activityLevel: 'sedentary',
    exercises: false,
  );
  final profile = (await UserProfileRepository(db).getProfile())!;
  await GoalRepository(
    db,
  ).save(profileUuid: profile.uuid, type: 'lose', targetWeight: target);
  await WeightRepository(
    db,
  ).addWeight(current, date: _firstDate, measurementContext: 'unspecified');
  await PlanRepository(db).save(
    profileUuid: profile.uuid,
    recommended: const DailyTargets(
      calories: 1532,
      protein: 100,
      carbs: 180,
      fats: 50,
      potassium: 3500,
      sodium: 2300,
      fiber: 25,
      water: 2500,
    ),
    calories: 2200,
    protein: 140,
    carbs: 250,
    fats: 70,
  );
  await PreferencesRepository(db).setMany({
    'units': system.name,
    NutritionPaceIntent.storageKey: jsonEncode({
      'version': 1,
      'weeklyPaceKg': -.5,
      'calculatedAt': '2026-11-18T12:00:00.000Z',
      'recommended': {'calories': 1532, 'protein': 100},
    }),
    'goal.calories': '1800',
    'goal.proteinPercent': '25',
    'goal.carbsPercent': '45',
    'goal.fatPercent': '30',
  });
  return db;
}

class _Harness {
  _Harness(this.db, this.preferences, {this.goalOverride, this.profileSeed}) {
    identityOverride = profileAuthIdentityProvider.overrideWith((ref) async* {
      yield const ProfileAuthIdentity(ownerId: _ownerA, email: null);
      yield* identities.stream;
    });
    freeOverride = verifiedSubscriptionStateProvider.overrideWithValue(
      AsyncData(FreePlan.createState()),
    );
    profileOverride = profileSeed == null
        ? null
        : userProfileProvider.overrideWith((ref) async* {
            yield profileSeed;
            yield* profiles.stream;
          });
    container = ProviderContainer(overrides: _overrides());
  }
  AppDatabase db;
  PreferencesRepository preferences;
  final GoalRepository? goalOverride;
  final UserProfileData? profileSeed;
  final profiles = StreamController<UserProfileData?>.broadcast();
  late final Override? profileOverride;
  final identities = StreamController<ProfileAuthIdentity>.broadcast();
  late final Override identityOverride, freeOverride;
  late final ProviderContainer container;
  List<Override> _overrides() => [
    databaseProvider.overrideWithValue(db),
    preferencesRepositoryProvider.overrideWithValue(preferences),
    identityOverride,
    freeOverride,
    ?profileOverride,
    if (goalOverride != null)
      goalRepositoryProvider.overrideWithValue(goalOverride!),
  ];
  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const ReferenceGoalsPage(),
        ),
      ),
    );
  }

  void switchTo(AppDatabase next, PreferencesRepository prefs, String owner) {
    db = next;
    preferences = prefs;
    container.updateOverrides(_overrides());
    identities.add(ProfileAuthIdentity(ownerId: owner, email: null));
  }

  Future<void> close(WidgetTester tester, {bool trace = false}) async {
    if (trace) {
      debugPrint('GOALS_FIXTURE teardown:unmount');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(() async {
      if (trace) {
        debugPrint('GOALS_FIXTURE teardown:container');
      }
      container.dispose();
      if (trace) {
        debugPrint('GOALS_FIXTURE teardown:identities');
      }
      await identities.close();
      if (trace) {
        debugPrint('GOALS_FIXTURE teardown:profiles');
      }
      await profiles.close();
      if (trace) {
        debugPrint('GOALS_FIXTURE teardown:done');
      }
    });
  }
}

Future<void> _settle(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 80; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (ready()) {
      return;
    }
  }
  fail('Owned Goals UI did not reach the expected finite state.');
}

String? _value(WidgetTester tester, String label) {
  final finder = find.widgetWithText(ListTile, label);
  if (finder.evaluate().isEmpty) {
    return null;
  }
  final texts = find.descendant(of: finder, matching: find.byType(Text));
  return tester
      .widgetList<Text>(texts)
      .map((t) => t.data)
      .whereType<String>()
      .lastOrNull;
}

Future<T> _query<T>(WidgetTester tester, Future<T> Function() read) async =>
    (await tester.runAsync(read)) as T;
Future<void> _ready(WidgetTester tester) =>
    _settle(tester, () => _value(tester, 'Current Weight') != null);
Future<void> _edit(WidgetTester tester, String label, String input) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), input);
  await tester.tap(find.widgetWithIcon(IconButton, Icons.check_rounded));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 40)),
  );
  await tester.pump();
}

Future<List<void Function()>> _holdPaceInputsWithFrames(
  WidgetTester tester,
  ProviderContainer container,
  String profileUuid,
) async {
  final close = <void Function()>[
    container.listen(userProfileProvider, (_, _) {}).close,
    container.listen(activeGoalProvider, (_, _) {}).close,
    container.listen(latestWeightProvider, (_, _) {}).close,
    container.listen(planSettingProvider(profileUuid), (_, _) {}).close,
  ];
  try {
    // Riverpod schedules dependency refreshes with Flutter frames. Real SQLite
    // I/O alone cannot settle a newly observed plan provider in testWidgets.
    await _settle(
      tester,
      () =>
          container.read(userProfileProvider).asData?.value?.uuid ==
              profileUuid &&
          container.read(activeGoalProvider).asData?.value != null &&
          container.read(latestWeightProvider).asData?.value != null &&
          container.read(planSettingProvider(profileUuid)).asData?.value !=
              null,
    );
    return close;
  } catch (_) {
    for (final cancel in close.reversed) {
      cancel();
    }
    rethrow;
  }
}

Future<void> _chooseRate(WidgetTester tester) async {
  await tester.tap(find.text('Weekly Goal'));
  await _settle(
    tester,
    () => find.text('Lose 1.8 lb per week').evaluate().isNotEmpty,
  );
  await tester.pumpAndSettle();
  expect(find.text('Gain 0.4 lb per week'), findsNothing);
  expect(find.text('Maintain weight'), findsNothing);
  expect(
    find.byKey(const Key('goals-weekly-edit-weight-goal')),
    findsOneWidget,
  );
  await tester.tap(find.text('Lose 1.8 lb per week'));
  await tester.pump();
  await tester.tap(find.widgetWithIcon(IconButton, Icons.check_rounded));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Yes'));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native imperial fixture hydrates real start and canonical pace without writing defaults',
    (tester) async {
      debugPrint('GOALS_FIXTURE seed:start');
      final db = await _query(tester, () => _seed(_ownerA));
      final prefs = PreferencesRepository(db);
      final h = _Harness(db, prefs);
      try {
        debugPrint('GOALS_FIXTURE seed:done/mount:start');
        await h.mount(tester);
        debugPrint('GOALS_FIXTURE mount:done/ready:start');
        await _ready(tester);
        debugPrint('GOALS_FIXTURE ready:done/assert:start');
        expect(_value(tester, 'Current Weight'), '180.0 lb');
        expect(_value(tester, 'Goal Weight'), '170.0 lb');
        expect(_value(tester, 'Starting Weight'), '180.0 lb · 2026-11-18');
        expect(_value(tester, 'Weekly Goal'), 'Lose 1.1 lb per week');
        for (final key in [
          'goals.startingWeight',
          'goals.startingDate',
          'goals.weeklyRate',
        ]) {
          expect(await _query(tester, () => prefs.get(key)), isNull);
        }
        debugPrint('GOALS_FIXTURE assert:done');
      } finally {
        await h.close(tester, trace: true);
        debugPrint('GOALS_FIXTURE database:close');
        await _query(tester, () => db.close());
        debugPrint('GOALS_FIXTURE database:closed');
      }
    },
  );

  testWidgets(
    'metric fallback retains canonical kg and actual first measurement date',
    (tester) async {
      final db = await _query(
        tester,
        () => _seed(_ownerA, system: MeasurementSystem.metric),
      );
      final prefs = PreferencesRepository(db);
      final h = _Harness(db, prefs);
      try {
        await h.mount(tester);
        await _ready(tester);
        expect(_value(tester, 'Current Weight'), '81.6 kg');
        expect(_value(tester, 'Goal Weight'), '77.1 kg');
        expect(_value(tester, 'Starting Weight'), '81.6 kg · 2026-11-18');
        expect(_value(tester, 'Weekly Goal'), 'Lose 0.5 kg per week');
      } finally {
        await h.close(tester);
        await _query(tester, () => db.close());
      }
    },
  );

  for (final raw in ['', 'invalid']) {
    testWidgets(
      'present $raw legacy facts do not fall back to plausible onboarding values',
      (tester) async {
        final db = await _query(tester, () => _seed(_ownerA));
        final prefs = PreferencesRepository(db);
        await _query(
          tester,
          () => prefs.setMany({
            'goals.startingWeight': raw,
            'goals.startingDate': raw,
            'goals.weeklyRate': raw,
          }),
        );
        final h = _Harness(db, prefs);
        try {
          await h.mount(tester);
          await _ready(tester);
          expect(_value(tester, 'Starting Weight'), '—');
          expect(_value(tester, 'Weekly Goal'), '—');
          for (final key in [
            'goals.startingWeight',
            'goals.startingDate',
            'goals.weeklyRate',
          ]) {
            expect(await _query(tester, () => prefs.get(key)), raw);
          }
        } finally {
          await h.close(tester);
          await _query(tester, () => db.close());
        }
      },
    );
  }

  testWidgets(
    'manual legacy start and opposite weekly direction remain visible until explicit save',
    (tester) async {
      final db = await _query(tester, () => _seed(_ownerA));
      final prefs = PreferencesRepository(db);
      await _query(
        tester,
        () => prefs.setMany({
          'goals.startingWeight': '88.8',
          'goals.startingDate': '2025-04-03',
          'goals.weeklyRate': 'Gain 0.2 kg per week',
        }),
      );
      final h = _Harness(db, prefs);
      try {
        await h.mount(tester);
        await _ready(tester);
        expect(_value(tester, 'Starting Weight'), '195.8 lb · 2025-04-03');
        expect(_value(tester, 'Weekly Goal'), 'Gain 0.4 lb per week');
        await tester.tap(find.text('Weekly Goal'));
        await _settle(
          tester,
          () => find.text('Lose 1.8 lb per week').evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(find.text('Gain 0.4 lb per week'), findsNothing);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(
          await _query(tester, () => prefs.get('goals.weeklyRate')),
          'Gain 0.2 kg per week',
        );
        expect(
          NutritionPaceIntent.decode(
            await _query(
              tester,
              () => prefs.get(NutritionPaceIntent.storageKey),
            ),
          ).weeklyPaceKg,
          -.5,
        );
      } finally {
        await h.close(tester);
        await _query(tester, () => db.close());
      }
    },
  );

  testWidgets(
    'imperial target editor stores kilograms once and preserves the same durable goal',
    (tester) async {
      final db = await _query(tester, () => _seed(_ownerA));
      final prefs = PreferencesRepository(db);
      final h = _Harness(db, prefs);
      final before = (await _query(
        tester,
        () => GoalRepository(db).getActive(),
      ))!;
      try {
        await h.mount(tester);
        await _ready(tester);
        await _edit(tester, 'Goal Weight', '160');
        final profile = (await _query(
          tester,
          () => UserProfileRepository(db).getProfile(),
        ))!;
        expect(
          profile.targetWeight,
          closeTo(
            UnitConverter.weightToKg(160, MeasurementSystem.imperial),
            1e-9,
          ),
        );
        expect(
          profile.currentWeight,
          closeTo(
            UnitConverter.weightToKg(180, MeasurementSystem.imperial),
            1e-9,
          ),
        );
        final goal = (await _query(
          tester,
          () => GoalRepository(db).getActive(),
        ))!;
        expect(goal.uuid, before.uuid);
        expect(goal.targetWeight, profile.targetWeight);
        expect(
          await _query(tester, () => db.select(db.goals).get()),
          hasLength(1),
        );
      } finally {
        await h.close(tester);
        await _query(tester, () => db.close());
      }
    },
  );

  testWidgets(
    'imperial starting-weight edit stores kg and retains actual starting date',
    (tester) async {
      final db = await _query(tester, () => _seed(_ownerA));
      final prefs = PreferencesRepository(db);
      final h = _Harness(db, prefs);
      try {
        await h.mount(tester);
        await _ready(tester);
        await _edit(tester, 'Starting Weight', '190');
        final raw = await _query(
          tester,
          () => prefs.get('goals.startingWeight'),
        );
        expect(
          double.parse(raw!),
          closeTo(
            UnitConverter.weightToKg(190, MeasurementSystem.imperial),
            1e-9,
          ),
        );
        expect(
          await _query(tester, () => prefs.get('goals.startingDate')),
          '2026-11-18',
        );
        expect(
          (await _query(
            tester,
            () => UserProfileRepository(db).getProfile(),
          ))!.currentWeight,
          closeTo(
            UnitConverter.weightToKg(180, MeasurementSystem.imperial),
            1e-9,
          ),
        );
      } finally {
        await h.close(tester);
        await _query(tester, () => db.close());
      }
    },
  );

  testWidgets(
    'imperial current editor writes canonical kg to profile and actual weight history',
    (tester) async {
      final db = await _query(tester, () => _seed(_ownerA));
      final prefs = PreferencesRepository(db);
      final h = _Harness(db, prefs);
      try {
        await h.mount(tester);
        await _ready(tester);
        await _edit(tester, 'Current Weight', '175');
        final kg = UnitConverter.weightToKg(175, MeasurementSystem.imperial);
        final profile = (await _query(
          tester,
          () => UserProfileRepository(db).getProfile(),
        ))!;
        expect(profile.currentWeight, closeTo(kg, 1e-9));
        final history = await _query(
          tester,
          () => WeightRepository(db).getAll(),
        );
        expect(history.first.weight, closeTo(kg, 1e-9));
        expect(
          profile.targetWeight,
          closeTo(
            UnitConverter.weightToKg(170, MeasurementSystem.imperial),
            1e-9,
          ),
        );
      } finally {
        await h.close(tester);
        await _query(tester, () => db.close());
      }
    },
  );

  testWidgets(
    'unchanged rounded imperial input preserves exact original kilograms',
    (tester) async {
      final db = await _query(tester, () => _seed(_ownerA));
      final prefs = PreferencesRepository(db);
      await _query(
        tester,
        () => prefs.setMany({
          'goals.startingWeight': '80',
          'goals.startingDate': '2026-11-18',
        }),
      );
      final h = _Harness(db, prefs);
      try {
        await h.mount(tester);
        await _ready(tester);
        await _edit(tester, 'Starting Weight', '176.4');
        expect(
          double.parse(
            (await _query(tester, () => prefs.get('goals.startingWeight')))!,
          ),
          80,
        );
      } finally {
        await h.close(tester);
        await _query(tester, () => db.close());
      }
    },
  );

  testWidgets(
    'imperial bounds are evaluated in kg and a cleared date is never replaced with today',
    (tester) async {
      final db = await _query(tester, () => _seed(_ownerA));
      final prefs = PreferencesRepository(db);
      final h = _Harness(db, prefs);
      await _query(tester, () => prefs.set('goals.startingDate', ''));
      try {
        await h.mount(tester);
        await _ready(tester);
        expect(_value(tester, 'Starting Weight'), '180.0 lb');
        await tester.tap(find.text('Goal Weight'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '20');
        await tester.tap(find.widgetWithIcon(IconButton, Icons.check_rounded));
        await tester.pump();
        expect(
          find.byType(TextField),
          findsOneWidget,
          reason: '20lb is below the existing20kg core minimum.',
        );
        await tester.enterText(find.byType(TextField), '1000');
        await tester.tap(find.widgetWithIcon(IconButton, Icons.check_rounded));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));
        await _query(tester, () => UserProfileRepository(db).getProfile());
        final target = (await _query(
          tester,
          () => UserProfileRepository(db).getProfile(),
        ))!.targetWeight;
        expect(
          target,
          closeTo(
            UnitConverter.weightToKg(1000, MeasurementSystem.imperial),
            1e-9,
          ),
        );
        await _ready(tester);
        await _edit(tester, 'Starting Weight', '190');
        expect(await _query(tester, () => prefs.get('goals.startingDate')), '');
        expect(_value(tester, 'Starting Weight'), '190.0 lb');
      } finally {
        await h.close(tester);
        await _query(tester, () => db.close());
      }
    },
  );

  for (final legacy in [false, true]) {
    testWidgets(
      'weekly save atomically updates pace and preserves manual targets legacy=$legacy',
      (tester) async {
        final db = await _query(tester, () => _seed(_ownerA));
        final prefs = PreferencesRepository(db);
        final h = _Harness(db, prefs);
        if (legacy) {
          await _query(
            tester,
            () => prefs.set('goals.weeklyRate', 'Lose 0.8 kg per week'),
          );
        }
        final profile = (await _query(
          tester,
          () => UserProfileRepository(db).getProfile(),
        ))!;
        final planBefore = (await _query(
          tester,
          () => PlanRepository(db).getForProfile(profile.uuid),
        ))!.toJson();
        final rawBefore =
            jsonDecode(
                  (await _query(
                    tester,
                    () => prefs.get(NutritionPaceIntent.storageKey),
                  ))!,
                )
                as Map;
        final closers = <void Function()>[];
        try {
          await h.mount(tester);
          await _ready(tester);
          closers.addAll(
            await _holdPaceInputsWithFrames(tester, h.container, profile.uuid),
          );
          final sub = h.container.listen(
            nutritionGoalDefaultsProvider,
            (_, _) {},
          );
          closers.add(sub.close);
          final observed = Completer<void>();
          final paceSub = h.container.listen(
            nutritionPaceIntentProvider(prefs),
            (previous, next) {
              if (next.asData?.value.weeklyPaceKg == -.8 &&
                  !observed.isCompleted) {
                observed.complete();
              }
            },
            fireImmediately: true,
          );
          closers.add(paceSub.close);
          await _chooseRate(tester);
          await _settle(tester, () => observed.isCompleted);
          await observed.future;
          await tester.pump();
          expect(
            await _query(tester, () => prefs.get('goals.weeklyRate')),
            'Lose 0.8 kg per week',
          );
          final after =
              jsonDecode(
                    (await _query(
                      tester,
                      () => prefs.get(NutritionPaceIntent.storageKey),
                    ))!,
                  )
                  as Map;
          expect(after['weeklyPaceKg'], -.8);
          expect(after['recommended'], rawBefore['recommended']);
          expect(after['calculatedAt'], rawBefore['calculatedAt']);
          expect(
            (await _query(
              tester,
              () => PlanRepository(db).getForProfile(profile.uuid),
            ))!.toJson(),
            planBefore,
          );
          final defaults = h.container.read(nutritionGoalDefaultsProvider);
          expect(defaults['goal.calories'], 2200);
          expect(defaults['goal.proteinGrams'], 140);
          expect(defaults['goal.carbsGrams'], 250);
          expect(defaults['goal.fatGrams'], 70);
          expect(
            await _query(tester, () => prefs.get('goal.calories')),
            '1800',
          );
          expect(
            await _query(tester, () => prefs.get('goal.proteinPercent')),
            '25',
          );
        } finally {
          for (final close in closers.reversed) {
            close();
          }
          await h.close(tester);
          await _query(tester, () => db.close());
        }
      },
    );
  }

  testWidgets(
    'unavailable active goal offers Retry and never saves an assumed direction',
    (tester) async {
      final db = await _query(tester, () => _seed(_ownerA));
      final prefs = PreferencesRepository(db);
      final h = _Harness(db, prefs, goalOverride: _FailedGoalRead(db));
      final before = await _query(
        tester,
        () => prefs.get(NutritionPaceIntent.storageKey),
      );
      try {
        await h.mount(tester);
        await _ready(tester);
        await tester.tap(find.text('Weekly Goal'));
        await _settle(
          tester,
          () => find
              .widgetWithText(SnackBarAction, 'Retry')
              .evaluate()
              .isNotEmpty,
        );
        expect(find.text('Lose 1.8 lb per week'), findsNothing);
        expect(
          await _query(tester, () => prefs.get('goals.weeklyRate')),
          isNull,
        );
        expect(
          await _query(tester, () => prefs.get(NutritionPaceIntent.storageKey)),
          before,
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(SnackBarAction, 'Retry').hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(SnackBarAction, 'Retry'));
        await _settle(
          tester,
          () => find.text('Lose 1.8 lb per week').evaluate().isNotEmpty,
        );
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(
          await _query(tester, () => prefs.get('goals.weeklyRate')),
          isNull,
        );
      } finally {
        await h.close(tester);
        await _query(tester, () => db.close());
      }
    },
  );

  testWidgets('A B A retires the old same-repository hydrate result', (
    tester,
  ) async {
    final a = await _query(tester, () => _seed(_ownerA)),
        b = await _query(
          tester,
          () => _seed(_ownerB, system: MeasurementSystem.metric),
        );
    final pa = _HeldReadPreferences(a), pb = PreferencesRepository(b);
    await _query(
      tester,
      () => PreferencesRepository(a).set('goals.startingWeight', '70'),
    );
    await _query(tester, () => pb.set('goals.startingWeight', '55'));
    final h = _Harness(a, pa);
    try {
      await h.mount(tester);
      await _settle(tester, () => pa.entered.isCompleted);
      h.switchTo(b, pb, _ownerB);
      await _settle(
        tester,
        () => _value(tester, 'Starting Weight')?.startsWith('55.0 kg') == true,
      );
      await _query(
        tester,
        () => PreferencesRepository(a).set('goals.startingWeight', '88'),
      );
      h.switchTo(a, pa, _ownerA);
      await _settle(
        tester,
        () => _value(tester, 'Starting Weight')?.startsWith('194.0 lb') == true,
      );
      pa.release.complete('70');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
      expect(_value(tester, 'Starting Weight')?.startsWith('194.0 lb'), isTrue);
      expect(
        await _query(
          tester,
          () => PreferencesRepository(a).get('goals.startingWeight'),
        ),
        '88',
      );
      expect(await _query(tester, () => pb.get('goals.startingWeight')), '55');
    } finally {
      if (!pa.release.isCompleted) {
        pa.release.complete('70');
      }
      await h.close(tester);
      await _query(tester, () => a.close());
      await _query(tester, () => b.close());
    }
  });

  testWidgets(
    'owner ABA during first weekly write rolls back both keys in the original database',
    (tester) async {
      final a = await _query(tester, () => _seed(_ownerA)),
          b = await _query(
            tester,
            () => _seed(_ownerB, system: MeasurementSystem.metric),
          );
      final pa = _HeldWritePreferences(a), pb = PreferencesRepository(b);
      final h = _Harness(a, pa);
      final before = await _query(
        tester,
        () => pa.get(NutritionPaceIntent.storageKey),
      );
      try {
        await h.mount(tester);
        await _ready(tester);
        pa.armed = true;
        await _chooseRate(tester);
        await _settle(tester, () => pa.entered.isCompleted);
        h.switchTo(b, pb, _ownerB);
        await _settle(
          tester,
          () => _value(tester, 'Current Weight') == '81.6 kg',
        );
        h.switchTo(a, pa, _ownerA);
        await tester.pump();
        pa.release.complete();
        await _settle(
          tester,
          () => _value(tester, 'Current Weight') == '180.0 lb',
        );
        expect(
          await _query(
            tester,
            () => PreferencesRepository(a).get('goals.weeklyRate'),
          ),
          isNull,
        );
        expect(
          await _query(
            tester,
            () => PreferencesRepository(a).get(NutritionPaceIntent.storageKey),
          ),
          before,
        );
        expect(await _query(tester, () => pb.get('goals.weeklyRate')), isNull);
        expect(
          NutritionPaceIntent.decode(
            await _query(tester, () => pb.get(NutritionPaceIntent.storageKey)),
          ).weeklyPaceKg,
          -.5,
        );
      } finally {
        if (!pa.release.isCompleted) {
          pa.release.complete();
        }
        await h.close(tester);
        await _query(tester, () => a.close());
        await _query(tester, () => b.close());
      }
    },
  );

  testWidgets(
    'same owner profile replacement rehydrates while same UUID refresh keeps its lease',
    (tester) async {
      final db = await _query(tester, () => _seed(_ownerA));
      final prefs = PreferencesRepository(db);
      final original = (await _query(
        tester,
        () => UserProfileRepository(db).getProfile(),
      ))!;
      final replacement = original.copyWith(
        uuid: 'goals-profile-replacement',
        activityLevel: 'active',
      );
      final h = _Harness(db, prefs, profileSeed: original);
      try {
        await h.mount(tester);
        await _ready(tester);
        expect(_value(tester, 'Weekly Goal'), 'Lose 1.1 lb per week');
        await _query(
          tester,
          () => prefs.set('goals.weeklyRate', 'Lose 0.8 kg per week'),
        );
        h.profiles.add(replacement);
        await _settle(
          tester,
          () => _value(tester, 'Weekly Goal') == 'Lose 1.8 lb per week',
        );
        expect(_value(tester, 'Activity Level'), 'Very Active');
        // Same UUID metadata refresh must not retire and hydrate again.
        await _query(
          tester,
          () => prefs.set('goals.weeklyRate', 'Lose 1 kg per week'),
        );
        h.profiles.add(replacement.copyWith(age: 31));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
        expect(_value(tester, 'Weekly Goal'), 'Lose 1.8 lb per week');
        expect(
          await _query(tester, () => prefs.get('goals.weeklyRate')),
          'Lose 1 kg per week',
        );
      } finally {
        await h.close(tester);
        await _query(tester, () => db.close());
      }
    },
  );

  for (final returnToOriginal in [false, true]) {
    testWidgets(
      'profile-only held hydrate cannot revive old lease ABA=$returnToOriginal',
      (tester) async {
        final db = await _query(tester, () => _seed(_ownerA));
        final prefs = _HeldReadPreferences(db);
        final original = (await _query(
          tester,
          () => UserProfileRepository(db).getProfile(),
        ))!;
        final replacement = original.copyWith(
          uuid: 'goals-profile-replacement',
          activityLevel: 'active',
        );
        await _query(
          tester,
          () => PreferencesRepository(db).set('goals.startingWeight', '70'),
        );
        final h = _Harness(db, prefs, profileSeed: original);
        try {
          await h.mount(tester);
          await _settle(tester, () => prefs.entered.isCompleted);
          await _query(
            tester,
            () => PreferencesRepository(db).set('goals.startingWeight', '88'),
          );
          h.profiles.add(replacement);
          await _settle(
            tester,
            () =>
                _value(tester, 'Starting Weight')?.startsWith('194.0 lb') ==
                true,
          );
          if (returnToOriginal) {
            await _query(
              tester,
              () => PreferencesRepository(db).set('goals.startingWeight', '89'),
            );
            h.profiles.add(original);
            await _settle(
              tester,
              () =>
                  _value(tester, 'Starting Weight')?.startsWith('196.2 lb') ==
                  true,
            );
          }
          prefs.release.complete('70');
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump();
          expect(
            _value(
              tester,
              'Starting Weight',
            )?.startsWith(returnToOriginal ? '196.2 lb' : '194.0 lb'),
            isTrue,
          );
          expect(
            await _query(
              tester,
              () => PreferencesRepository(db).get('goals.startingWeight'),
            ),
            returnToOriginal ? '89' : '88',
          );
          expect(h.container.read(databaseProvider), same(db));
          expect(h.container.read(preferencesRepositoryProvider), same(prefs));
          expect(
            h.container.read(profileAuthIdentityProvider).asData?.value.ownerId,
            _ownerA,
          );
        } finally {
          if (!prefs.release.isCompleted) {
            prefs.release.complete('70');
          }
          await h.close(tester);
          await _query(tester, () => db.close());
        }
      },
    );
  }
}
