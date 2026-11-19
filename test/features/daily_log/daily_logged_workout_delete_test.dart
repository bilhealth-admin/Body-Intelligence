import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

// The real page, exercise codec, daily-log repository, selected-day stream,
// and Drift persistence run in these tests. Only unrelated cloud/catalog and
// display inputs are supplied as fixtures; no replacement delete algorithm.
final _database = StateProvider<AppDatabase>(
  (ref) => throw StateError('The test must provide an owner database.'),
);
final _day = DateTime(2026, 11, 17);
final _neighbourDay = DateTime(2026, 11, 16);
const _first =
    '{"id":"bench-push-up","name":"Bench push-up","minutes":10,"recordedAt":"2026-11-17T08:00:00Z"}';
const _second =
    '{"id":"bench-push-up","name":"Bench push-up","minutes":20,"recordedAt":"2026-11-17T09:00:00Z"}';
const _walk =
    '{"id":"walk","name":"Walk","minutes":30,"recordedAt":"2026-11-17T10:00:00Z"}';
const _damaged = '{"kind":"future_payload"';
const _original =
    'Warm-up note\n$_first\n$_damaged\n$_second\n$_walk\nKeep this note';
const _withoutSecond =
    'Warm-up note\n$_first\n$_damaged\n$_walk\nKeep this note';

void main() {
  late AppDatabase database;
  late DailyLogRepository repository;
  ProviderContainer? container;

  setUp(() async {
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'a',
    );
    repository = DailyLogRepository(database);
    await repository.save(
      date: _day,
      notes: 'Private body-context note',
      sleepHours: 7.25,
      steps: 8123,
      exerciseNotes: _original,
    );
    await repository.save(
      date: _neighbourDay,
      notes: 'Other day',
      sleepHours: 6.5,
      steps: 4321,
      exerciseNotes: _original,
    );
  });
  tearDown(() async {
    container?.dispose();
    container = null;
    await database.close();
  });

  Future<void> pumpPage(WidgetTester tester, {String language = 'en'}) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        _database.overrideWith((ref) => database),
        databaseProvider.overrideWith((ref) => ref.watch(_database)),
        seedCatalogProvider.overrideWith((ref) async {}),
        foodsProvider.overrideWithValue(const AsyncData([])),
        userProfileProvider.overrideWithValue(const AsyncData(null)),
        verifiedSubscriptionAccessProvider.overrideWithValue(
          AsyncData(FreePlan.createState()),
        ),
        verifiedSubscriptionStateProvider.overrideWithValue(
          AsyncData(FreePlan.createState()),
        ),
        selectedLogDateProvider.overrideWith((ref) => _day),
        dailyMealsProvider.overrideWithValue(const AsyncData([])),
        dailyWaterProvider.overrideWithValue(const AsyncData([])),
        diaryMealNamesProvider.overrideWithValue(
          const AsyncData([null, null, null, null]),
        ),
        nutritionGoalScheduleProvider.overrideWithValue(
          const AsyncData(NutritionGoalSchedule()),
        ),
        defaultNutritionGoalTargetProvider.overrideWithValue(null),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const DailyLogPage(),
        ),
      ),
    );
    await _hostOperation(tester, () async {
      await container!.read(selectedDailyLogProvider.future);
      await container!.read(selectedDailyLedgerProvider.future);
    });
    await tester.pumpAndSettle();
    final section = find.byKey(const Key('daily-log-exercise-section'));
    await tester.ensureVisible(section);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(section);
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<DailyLog> read(WidgetTester tester, [DateTime? day]) async =>
      (await _hostOperation<DailyLog?>(
        tester,
        () => repository.getForDay(day ?? _day),
      ))!;

  Future<void> requestSecondRemoval(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('daily-exercise-remove-3'));
    expect(
      button,
      findsOneWidget,
      reason: 'Each saved occurrence must have an ordinary removal action.',
    );
    await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('Today removes only the confirmed saved workout occurrence', (
    tester,
  ) async {
    await pumpPage(tester);
    await requestSecondRemoval(tester);
    await tester.tap(find.byKey(const Key('daily-exercise-confirm-remove')));
    await tester.pump(const Duration(milliseconds: 350));
    await _hostOperation(
      tester,
      () => repository
          .watchForDay(_day)
          .firstWhere((row) => row?.exerciseNotes == _withoutSecond)
          .timeout(const Duration(seconds: 5)),
    );
    await tester.pumpAndSettle();
    final saved = await read(tester);
    expect(saved.exerciseNotes, _withoutSecond);
    expect(saved.notes, 'Private body-context note');
    expect(saved.steps, 8123);
    expect(saved.sleepHours, 7.25);
    final neighbour = await read(tester, _neighbourDay);
    expect(neighbour.exerciseNotes, _original);
    expect(neighbour.steps, 4321);
    expect(find.text('Bench push-up'), findsOneWidget);
    expect(find.text('Walk'), findsOneWidget);
  });

  testWidgets('removing the last saved workout preserves the daily record', (
    tester,
  ) async {
    await _hostOperation(
      tester,
      () => repository.save(
        date: _day,
        notes: 'Private body-context note',
        sleepHours: 7.25,
        steps: 8123,
        exerciseNotes: _first,
      ),
    );
    final before = await read(tester);
    await pumpPage(tester);
    final button = find.byKey(const ValueKey('daily-exercise-remove-0'));
    await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const Key('daily-exercise-confirm-remove')));
    await tester.pump(const Duration(milliseconds: 350));
    await _hostOperation(
      tester,
      () => repository
          .watchForDay(_day)
          .firstWhere((row) => row != null && row.exerciseNotes == null)
          .timeout(const Duration(seconds: 5)),
    );
    await tester.pumpAndSettle();
    final after = await read(tester);
    expect(after.uuid, before.uuid);
    expect(after.id, before.id);
    expect(after.exerciseNotes, isNull);
    expect(after.notes, before.notes);
    expect(after.steps, before.steps);
    expect(after.sleepHours, before.sleepHours);
    expect((await read(tester, _neighbourDay)).exerciseNotes, _original);
  });

  testWidgets('Cancel leaves both duplicate workouts and notes unchanged', (
    tester,
  ) async {
    await pumpPage(tester);
    final before = await read(tester);
    await requestSecondRemoval(tester);
    await tester.tap(find.byKey(const Key('daily-exercise-cancel-remove')));
    await tester.pumpAndSettle();
    final after = await read(tester);
    expect(after.toJson(), before.toJson());
    expect(find.text('Bench push-up'), findsNWidgets(2));
  });

  testWidgets(
    'removing a saved workout preserves the unsaved plain-note draft',
    (tester) async {
      await pumpPage(tester);
      final note = find.byKey(const Key('daily-log-exercise-notes'));
      await tester.ensureVisible(note);
      await tester.enterText(note, 'Unsaved local draft');
      await requestSecondRemoval(tester);
      await tester.tap(find.byKey(const Key('daily-exercise-confirm-remove')));
      await tester.pump(const Duration(milliseconds: 350));
      await _hostOperation(
        tester,
        () => repository
            .watchForDay(_day)
            .firstWhere((row) => row?.exerciseNotes == _withoutSecond)
            .timeout(const Duration(seconds: 5)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(note).controller!.text,
        'Unsaved local draft',
      );
      expect((await read(tester)).exerciseNotes, _withoutSecond);
    },
  );

  testWidgets('a concurrent workout append retires the old confirmation', (
    tester,
  ) async {
    await pumpPage(tester);
    await requestSecondRemoval(tester);
    await _hostOperation(
      tester,
      () =>
          repository.appendExerciseNotes(date: _day, encodedEntries: [_first]),
    );
    await _hostOperation(
      tester,
      () => repository
          .watchForDay(_day)
          .firstWhere((row) => row?.exerciseNotes == '$_original\n$_first'),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('daily-exercise-confirm-remove')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('daily-exercise-cancel-remove')));
    await tester.pumpAndSettle();
    expect((await read(tester)).exerciseNotes, '$_original\n$_first');
  });

  testWidgets('day A to B to A cannot revive a pending deletion', (
    tester,
  ) async {
    await pumpPage(tester);
    await requestSecondRemoval(tester);
    container!.read(selectedLogDateProvider.notifier).state = _neighbourDay;
    await tester.pump(const Duration(milliseconds: 50));
    container!.read(selectedLogDateProvider.notifier).state = _day;
    await _hostOperation(
      tester,
      () => container!.read(selectedDailyLogProvider.future),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('daily-exercise-confirm-remove')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('daily-exercise-cancel-remove')));
    await tester.pumpAndSettle();
    expect((await read(tester)).exerciseNotes, _original);
    expect((await read(tester, _neighbourDay)).exerciseNotes, _original);
  });

  testWidgets('owner A to B to A cannot revive a pending deletion', (
    tester,
  ) async {
    final other = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'b',
    );
    final otherRepository = DailyLogRepository(other);
    await _hostOperation(
      tester,
      () => otherRepository.save(
        date: _day,
        notes: 'Owner B',
        exerciseNotes: _original,
      ),
    );
    try {
      await pumpPage(tester);
      await requestSecondRemoval(tester);
      container!.read(_database.notifier).state = other;
      await tester.pump(const Duration(milliseconds: 50));
      container!.read(_database.notifier).state = database;
      await _hostOperation(
        tester,
        () => container!.read(selectedDailyLogProvider.future),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('daily-exercise-confirm-remove')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('daily-exercise-cancel-remove')));
      await tester.pumpAndSettle();
      expect((await read(tester)).exerciseNotes, _original);
      expect(
        (await _hostOperation(
          tester,
          () => otherRepository.getForDay(_day),
        ))!.exerciseNotes,
        _original,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container?.dispose();
      container = null;
      await tester.pump();
      await _hostOperation<void>(tester, other.close);
      await tester.pump();
    }
  });

  testWidgets('completed day keeps saved workouts until explicitly reopened', (
    tester,
  ) async {
    await _hostOperation(tester, () => repository.closeDay(_day));
    await pumpPage(tester);
    final button = find.byKey(const ValueKey('daily-exercise-remove-3'));
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    expect((await read(tester)).exerciseNotes, _original);
  });

  testWidgets('workout confirmation uses the existing Arabic action labels', (
    tester,
  ) async {
    await pumpPage(tester, language: 'ar');
    await requestSecondRemoval(tester);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('daily-exercise-cancel-remove')),
          )
          .child,
      isA<Text>(),
    );
    expect(find.text('إلغاء'), findsOneWidget);
    expect(find.text('إزالة'), findsWidgets);
    await tester.tap(find.byKey(const Key('daily-exercise-cancel-remove')));
    await tester.pumpAndSettle();
    expect((await read(tester)).exerciseNotes, _original);
  });
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
