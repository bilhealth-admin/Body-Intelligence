import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrition_goal_snapshot.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_defaults_provider.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_snapshot_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/nutrition_goal_schedule_page.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

// These fixtures only supply inputs. The real snapshot, default-target adapter,
// schedule page, schedule repository, and Drift transaction remain under test.
final _owner = StateProvider<PreferencesRepository>(
  (ref) => throw StateError('The test must provide an owner.'),
);
final _defaults = StateProvider<Map<String, double>>((ref) => const {});
const _currentDefault = <String, double>{
  'goal.calories': 2124,
  'goal.carbsPercent': 49,
  'goal.proteinPercent': 21,
  'goal.fatPercent': 30,
};

void main() {
  late AppDatabase database;
  late _ObservedPreferences preferences;
  ProviderContainer? container;

  setUp(() {
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-a',
    );
    preferences = _ObservedPreferences(database);
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await database.close();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    AsyncValue<NutritionGoalSnapshot>? snapshot,
  }) async {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        _owner.overrideWith((ref) => preferences),
        _defaults.overrideWith((ref) => _currentDefault),
        preferencesRepositoryProvider.overrideWith((ref) => ref.watch(_owner)),
        nutritionGoalDefaultsProvider.overrideWith(
          (ref) => ref.watch(_defaults),
        ),
        if (snapshot != null)
          nutritionGoalSnapshotProvider.overrideWithValue(snapshot),
      ],
    );
    container!.listen(nutritionGoalScheduleProvider, (_, _) {});
    if (snapshot == null) {
      container!.listen(nutritionGoalSnapshotProvider, (_, _) {});
    }
    await tester.runAsync(() async {
      await container!
          .read(nutritionGoalScheduleProvider.future)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw StateError('Real schedule fixture did not emit'),
          );
      if (snapshot == null) {
        await container!
            .read(nutritionGoalSnapshotProvider.future)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () =>
                  throw StateError('Real goal snapshot fixture did not emit'),
            );
      }
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: const MaterialApp(home: NutritionGoalSchedulePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<NutritionGoalSchedule> readSchedule(
    WidgetTester tester, [
    PreferencesRepository? from,
  ]) async => (await tester.runAsync(
    () => NutritionGoalScheduleRepository(from ?? preferences).read(),
  ))!;

  Future<void> openMonday(WidgetTester tester) async {
    await tester.tap(find.text('Monday'));
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> closeEditor(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> finishHostWrite(
    WidgetTester tester,
    Future<Object?> write,
  ) async {
    var complete = false;
    Object? failure;
    StackTrace? failureStack;
    write.then<void>(
      (_) => complete = true,
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        complete = true;
      },
    );
    final elapsed = Stopwatch()..start();
    while (!complete && elapsed.elapsedMilliseconds < 5000) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(complete, isTrue, reason: 'Real Drift goal write did not finish');
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  }

  Future<void> saveEditor(WidgetTester tester) async {
    final writesBefore = preferences.scheduleWrites;
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(preferences.scheduleWrites, writesBefore + 1);
    await finishHostWrite(tester, preferences.latestScheduleWrite!);
    await tester.pump(const Duration(milliseconds: 350));
  }

  List<String> fieldTexts(WidgetTester tester) => tester
      .widgetList<TextField>(find.byType(TextField))
      .map((field) => field.controller!.text)
      .toList();

  testWidgets(
    'default weekday editor uses the actual 2124 current default and saves it exactly',
    (tester) async {
      await pumpPage(tester);
      final expected = container!.read(defaultNutritionGoalTargetProvider)!;
      expect(expected.calories, 2124);
      expect(expected.carbsPercent, 49);
      expect((await readSchedule(tester)).dayTargets, isEmpty);

      await openMonday(tester);
      // Main rounds these grams to 260 / 111 / 71. The editor keeps its
      // existing two-decimal input convention and the exact provider seed.
      expect(fieldTexts(tester), ['2,124', '260.19', '111.51', '70.80']);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(
          field.keyboardType,
          const TextInputType.numberWithOptions(decimal: true),
        );
      }
      await saveEditor(tester);

      final actual = (await readSchedule(tester)).dayTargets[DateTime.monday]!;
      expect(actual.calories, expected.calories);
      expect(actual.carbsPercent, closeTo(expected.carbsPercent, 1e-12));
      expect(actual.proteinPercent, closeTo(expected.proteinPercent, 1e-12));
      expect(actual.fatPercent, closeTo(expected.fatPercent, 1e-12));
      expect(
        await tester.runAsync(() => preferences.get('goal.calories')),
        isNull,
      );
    },
  );

  testWidgets(
    'saved weekday override wins and unchanged Save preserves precision',
    (tester) async {
      const override = NutritionGoalTarget(
        calories: 2000.123,
        carbsPercent: 45,
        proteinPercent: 30,
        fatPercent: 25,
      );
      await tester.runAsync(
        () => NutritionGoalScheduleRepository(
          preferences,
        ).saveDay(DateTime.monday, override),
      );
      final before = (await readSchedule(tester)).dayTargets[DateTime.monday]!;
      await pumpPage(tester);
      await openMonday(tester);
      expect(fieldTexts(tester), ['2,000.12', '225.01', '150.01', '55.56']);
      await saveEditor(tester);
      final after = (await readSchedule(tester)).dayTargets[DateTime.monday]!;
      expect(after.calories, before.calories);
      expect(after.carbsPercent, closeTo(before.carbsPercent, 1e-12));
      expect(after.proteinPercent, closeTo(before.proteinPercent, 1e-12));
      expect(after.fatPercent, closeTo(before.fatPercent, 1e-12));
    },
  );

  testWidgets(
    'Cancel creates no override and Use default removes only that day',
    (tester) async {
      await pumpPage(tester);
      await openMonday(tester);
      await closeEditor(tester);
      expect((await readSchedule(tester)).dayTargets, isEmpty);

      final repository = NutritionGoalScheduleRepository(preferences);
      const explicit = NutritionGoalTarget(
        calories: 1800,
        carbsPercent: 50,
        proteinPercent: 20,
        fatPercent: 30,
      );
      await _hostOperation<void>(tester, () async {
        await repository.saveDay(DateTime.monday, explicit);
        await repository.saveDay(DateTime.tuesday, explicit);
        await repository.saveMeal('breakfast', explicit);
      });
      await tester.pump(const Duration(milliseconds: 350));
      await openMonday(tester);
      final writesBefore = preferences.scheduleWrites;
      await tester.tap(find.widgetWithText(TextButton, 'Use default'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(preferences.scheduleWrites, writesBefore + 1);
      await finishHostWrite(tester, preferences.latestScheduleWrite!);
      await tester.pump(const Duration(milliseconds: 350));
      final after = await readSchedule(tester);
      expect(after.dayTargets.containsKey(DateTime.monday), isFalse);
      expect(after.dayTargets[DateTime.tuesday]!.calories, 1800);
      expect(after.mealTargets['breakfast']!.calories, 1800);
      expect(
        container!.read(defaultNutritionGoalTargetProvider)!.calories,
        2124,
      );
      expect(
        await tester.runAsync(() => preferences.get('goal.calories')),
        isNull,
      );
    },
  );

  for (final state in ['loading', 'error', 'invalid']) {
    testWidgets(
      'unavailable default $state never invents a 2000 weekday seed',
      (tester) async {
        final snapshot = switch (state) {
          'loading' => const AsyncLoading<NutritionGoalSnapshot>(),
          'error' => AsyncError<NutritionGoalSnapshot>(
            StateError('fixture read failed'),
            StackTrace.empty,
          ),
          _ => AsyncData(NutritionGoalSnapshot.resolve(const {}, const {})),
        };
        await pumpPage(tester, snapshot: snapshot);
        expect(container!.read(defaultNutritionGoalTargetProvider), isNull);
        expect(find.text('Scheduled goals'), findsOneWidget);
        expect(find.text('Monday'), findsOneWidget);
        final monday = tester.widget<ListTile>(
          find.widgetWithText(ListTile, 'Monday'),
        );
        expect(monday.onTap, isNull);
        if (state == 'loading') {
          expect(find.byType(BilFeatureWelcomeStatus), findsWidgets);
        } else {
          expect(find.text('Goals unavailable'), findsWidgets);
        }
        expect(find.byType(TextField), findsNothing);
        expect((await readSchedule(tester)).dayTargets, isEmpty);
      },
    );
  }

  testWidgets('explicit day remains editable when default snapshot failed', (
    tester,
  ) async {
    const override = NutritionGoalTarget(
      calories: 1800,
      carbsPercent: 50,
      proteinPercent: 20,
      fatPercent: 30,
    );
    await tester.runAsync(
      () => NutritionGoalScheduleRepository(
        preferences,
      ).saveDay(DateTime.monday, override),
    );
    await pumpPage(
      tester,
      snapshot: AsyncError<NutritionGoalSnapshot>(
        StateError('fixture default read failed'),
        StackTrace.empty,
      ),
    );
    await openMonday(tester);
    expect(fieldTexts(tester), ['1,800', '225', '90', '60']);
    await closeEditor(tester);
    expect(
      (await readSchedule(tester)).dayTargets[DateTime.monday]!.calories,
      1800,
    );
  });

  testWidgets('owner visit A to B to A retires an already opened editor', (
    tester,
  ) async {
    final otherDatabase = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-b',
    );
    final otherPreferences = PreferencesRepository(otherDatabase);
    try {
      await pumpPage(tester);
      await openMonday(tester);
      expect(fieldTexts(tester).first, '2,124');
      container!.read(_owner.notifier).state = otherPreferences;
      await tester.pump(const Duration(milliseconds: 50));
      container!.read(_owner.notifier).state = preferences;
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(TextField), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Use default'))
            .onPressed,
        isNull,
      );
      await closeEditor(tester);
      expect((await readSchedule(tester)).dayTargets, isEmpty);
      expect(
        (await readSchedule(tester, otherPreferences)).dayTargets,
        isEmpty,
      );
    } finally {
      // Stop provider subscriptions before closing their test database.
      await tester.pumpWidget(const SizedBox.shrink());
      container?.dispose();
      container = null;
      await tester.pump();
      await _hostOperation<void>(tester, otherDatabase.close);
      await tester.pump();
    }
  });

  testWidgets(
    'changed global default retires the old default seed before Save',
    (tester) async {
      await pumpPage(tester);
      await openMonday(tester);
      container!.read(_defaults.notifier).state = const {
        'goal.calories': 2400,
        'goal.carbsPercent': 50,
        'goal.proteinPercent': 25,
        'goal.fatPercent': 25,
      };
      await _hostOperation<NutritionGoalSnapshot>(
        tester,
        () => container!.read(nutritionGoalSnapshotProvider.future),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(TextField), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
      await closeEditor(tester);
      expect((await readSchedule(tester)).dayTargets, isEmpty);
    },
  );

  testWidgets('valid edited weekday persists the entered grams', (
    tester,
  ) async {
    await pumpPage(tester);
    await openMonday(tester);
    for (final (index, text) in ['2100', '250', '140', '60'].indexed) {
      await tester.enterText(find.byType(TextField).at(index), text);
    }
    await saveEditor(tester);
    final actual = (await readSchedule(tester)).dayTargets[DateTime.monday]!;
    expect(actual.calories, 2100);
    expect(actual.carbsGrams, closeTo(250, 1e-9));
    expect(actual.proteinGrams, closeTo(140, 1e-9));
    expect(actual.fatGrams, closeTo(60, 1e-9));
  });

  testWidgets('edited weekday still validates macro energy before saving', (
    tester,
  ) async {
    await pumpPage(tester);
    await openMonday(tester);
    await tester.enterText(find.byType(TextField).at(3), '1');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Macro grams must match calories'), findsOneWidget);
    expect((await readSchedule(tester)).dayTargets, isEmpty);
    await closeEditor(tester);
  });
}

// Observe completion of the real Drift update, avoiding timing-based waits.
class _ObservedPreferences extends PreferencesRepository {
  _ObservedPreferences(super.database);
  int scheduleWrites = 0;
  Future<String>? latestScheduleWrite;

  @override
  Future<String> update(
    String key,
    String Function(String? current) derive, {
    bool Function()? isCurrent,
  }) {
    final saved = super.update(key, derive, isCurrent: isCurrent);
    if (key == nutritionGoalSchedulePreferenceKey) {
      scheduleWrites++;
      latestScheduleWrite = saved;
    }
    return saved;
  }
}

Future<T> _hostOperation<T>(
  WidgetTester tester,
  Future<T> Function() operation,
) async {
  var complete = false;
  T? result;
  Object? failure;
  StackTrace? failureStack;
  await tester.runAsync(() async {
    Future<T>.sync(operation).then<void>(
      (value) {
        result = value;
        complete = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        complete = true;
      },
    );
  });
  final elapsed = Stopwatch()..start();
  while (!complete && elapsed.elapsedMilliseconds < 5000) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    complete,
    isTrue,
    reason: 'Actual goal fixture operation did not finish',
  );
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  return result as T;
}
