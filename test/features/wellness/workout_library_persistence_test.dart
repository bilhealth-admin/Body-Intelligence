import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_tools_pages.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  late AppDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => database.close());

  Widget app({
    DailyLogRepository? repository,
    Locale? locale,
    Future<bool> Function(List<Map<String, String>> value)? customWriter,
    Future<bool> Function(bool descending)? sortWriter,
  }) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      // These persistence tests do not exercise the profile stream. Keeping
      // its Drift query alive until framework teardown leaves a zero-duration
      // StreamQueryStore cleanup timer after the widget tree is disposed.
      userProfileProvider.overrideWith((ref) => const Stream.empty()),
      if (repository != null)
        dailyLogRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: WorkoutLibraryPage(
        customExercisesWriter: customWriter,
        sortOrderWriter: sortWriter,
      ),
    ),
  );

  testWidgets(
    'single confirmed workout persists and is reusable from history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Brisk walk').last);
      await tester.pump(const Duration(milliseconds: 500));
      final logButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Log workout'),
      );
      logButton.onPressed!();
      await tester.pump(const Duration(seconds: 1));

      final saved = await DailyLogRepository(
        database,
      ).getForDay(DateTime.now());
      expect(saved?.exerciseNotes, contains('"id":"walk"'));
      expect(saved?.exerciseNotes, contains('"minutes":20'));

      await tester.tap(find.text('History'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Brisk walk'), findsOneWidget);
      expect(find.textContaining('20 min ·'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Brisk walk'), findsOneWidget);

      await tester.tap(find.text('Brisk walk'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Duration: 20 min'), findsOneWidget);
      expect(
        (await DailyLogRepository(
          database,
        ).getForDay(DateTime.now()))?.exerciseNotes,
        saved?.exerciseNotes,
      );
    },
  );

  testWidgets('custom exercise saves before close and reloads from storage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('New exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('custom-exercise-name')),
      'Cable press',
    );
    await tester.tap(find.byKey(const Key('save-custom-exercise')));
    await tester.pumpAndSettle();
    expect(find.text('Cable press'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    final decoded =
        jsonDecode(preferences.getString('wellness.custom_exercises.v1')!)
            as List<dynamic>;
    expect(decoded, hasLength(1));
    expect(decoded.single['name'], 'Cable press');
    expect(decoded.single['category'], 'Strength');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Exercises'));
    await tester.pumpAndSettle();
    expect(find.text('Cable press'), findsOneWidget);
  });

  testWidgets('rejected custom exercise write keeps dialog and draft', (
    tester,
  ) async {
    await tester.pumpWidget(app(customWriter: (_) async => false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('custom-exercise-name')),
      'Retained draft',
    );
    await tester.tap(find.byKey(const Key('save-custom-exercise')));
    await tester.pumpAndSettle();
    expect(find.text('Create exercise'), findsOneWidget);
    expect(find.text('Retained draft'), findsOneWidget);
    expect(
      find.text('Could not save exercise. Review and retry.'),
      findsOneWidget,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        'wellness.custom_exercises.v1',
      ),
      isNull,
    );
  });

  testWidgets('rejected custom delete keeps authoritative row', (tester) async {
    SharedPreferences.setMockInitialValues({
      'wellness.custom_exercises.v1': jsonEncode([
        {'id': 'custom-kept', 'name': 'Keep me', 'category': 'Strength'},
      ]),
    });
    await tester.pumpWidget(app(customWriter: (_) async => false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete exercise?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Keep me'), findsOneWidget);
    expect(find.text('Could not delete exercise.'), findsOneWidget);
  });

  testWidgets('display sort order persists after rebuild', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Display options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Z to A'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Yoga').last).dy,
      lessThan(tester.getTopLeft(find.text('Upper-body strength').last).dy),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Yoga').last).dy,
      lessThan(tester.getTopLeft(find.text('Upper-body strength').last).dy),
    );
  });

  testWidgets('throwing sort write keeps sheet open and prior order', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(sortWriter: (_) async => throw StateError('injected sort failure')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Display options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Z to A'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Display options'), findsOneWidget);
    expect(find.text('Could not save display options.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'wellness.exercise_sort_descending.v1',
      ),
      isNull,
    );
  });

  testWidgets('malformed custom exercise records fail closed', (tester) async {
    SharedPreferences.setMockInitialValues({
      'wellness.custom_exercises.v1': jsonEncode([
        {'id': 'custom-good', 'name': 'Good row', 'category': 'Strength'},
        {'id': 'custom-good', 'name': 'Duplicate', 'category': 'Strength'},
        {'id': 'bad', 'name': 'Bad id', 'category': 'Strength'},
        {'id': 'custom-wrong', 'name': 7, 'category': 'Strength'},
        {'id': 'custom-category', 'name': 'Bad category', 'category': 'Other'},
      ]),
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Exercises'));
    await tester.pumpAndSettle();
    expect(find.text('Good row'), findsOneWidget);
    expect(find.text('Duplicate'), findsNothing);
    expect(find.text('Bad id'), findsNothing);
    expect(find.text('Bad category'), findsNothing);
  });

  testWidgets('multi-add requires selection and commits all entries once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Multi-add'));
    await tester.pump(const Duration(milliseconds: 300));
    final commit = find.byKey(const Key('log-selected-workouts'));
    expect(tester.widget<FilledButton>(commit).onPressed, isNull);

    await tester.tap(find.text('Brisk walk').last);
    await tester.tap(find.text('Breathing recovery'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Log 2'), findsOneWidget);
    await tester.tap(commit);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('2 workouts for today'), findsOneWidget);
    await tester.tap(find.text('Log workouts'));
    await tester.pump(const Duration(seconds: 1));

    final notes = (await DailyLogRepository(
      database,
    ).getForDay(DateTime.now()))?.exerciseNotes;
    expect(notes, contains('"id":"walk"'));
    expect(notes, contains('"id":"breathing"'));
    expect(notes!.split('\n'), hasLength(2));
    expect(find.text('Brisk walk'), findsOneWidget);
    expect(find.text('Breathing recovery'), findsOneWidget);
  });

  testWidgets('multi-add supports a duration override per selected workout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Multi-add'));
    await tester.pump();
    await tester.tap(find.text('Brisk walk').last);
    await tester.tap(find.text('Breathing recovery'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('log-selected-workouts')));
    await tester.pumpAndSettle();
    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders, hasLength(2));
    sliders.last.onChanged!(35);
    await tester.pump();
    await tester.tap(find.text('Log workouts'));
    await tester.pumpAndSettle();
    final notes = (await DailyLogRepository(
      database,
    ).getForDay(DateTime.now()))!.exerciseNotes!;
    expect(notes, contains('"id":"walk","name":"Brisk walk","minutes":20'));
    expect(
      notes,
      contains('"id":"breathing","name":"Breathing recovery","minutes":35'),
    );
  });

  testWidgets('malformed legacy exercise notes fail closed', (tester) async {
    await DailyLogRepository(database).save(
      date: DateTime.now(),
      exerciseNotes: 'legacy free text\n{"id":"bad","minutes":"no"}',
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No exercise history yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wrong types out-of-range and future history fail closed', (
    tester,
  ) async {
    final future = DateTime.now()
        .add(const Duration(days: 1))
        .toIso8601String();
    await DailyLogRepository(database).save(
      date: DateTime.now(),
      exerciseNotes: [
        '{"id":7,"name":"Wrong id","minutes":20,"recordedAt":"$future"}',
        '{"id":"x","name":{},"minutes":20,"recordedAt":"$future"}',
        '{"id":"x","name":"Too long","minutes":121,"recordedAt":"$future"}',
        '{"id":"x","name":"Future","minutes":20,"recordedAt":"$future"}',
      ].join('\n'),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No exercise history yet'), findsOneWidget);
  });

  testWidgets('failed single save keeps editor open for retry', (tester) async {
    final repository = _FailingDailyLogRepository(database);
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brisk walk').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log workout'));
    await tester.pumpAndSettle();
    expect(find.text('Duration: 20 min'), findsOneWidget);
    expect(find.text('Could not save workout.'), findsOneWidget);
    expect(await repository.getForDay(DateTime.now()), isNull);
  });

  test('atomic append preserves existing daily fields and notes', () async {
    final repository = DailyLogRepository(database);
    await repository.save(
      date: DateTime.now(),
      notes: 'private note',
      sleepHours: 7.5,
      steps: 4321,
      exerciseNotes: 'legacy note',
    );
    await repository.appendExerciseNotes(
      date: DateTime.now(),
      encodedEntries: const [
        '{"id":"walk","name":"Brisk walk","minutes":20,"recordedAt":"2026-08-13T08:00:00Z"}',
      ],
    );
    final saved = await repository.getForDay(DateTime.now());
    expect(saved?.notes, 'private note');
    expect(saved?.sleepHours, 7.5);
    expect(saved?.steps, 4321);
    expect(saved?.exerciseNotes, startsWith('legacy note\n'));
  });

  test('concurrent atomic appends preserve both workout entries', () async {
    final repository = DailyLogRepository(database);
    await Future.wait([
      repository.appendExerciseNotes(
        date: DateTime.now(),
        encodedEntries: const [
          '{"id":"walk","name":"Brisk walk","minutes":20,"recordedAt":"2026-08-13T08:00:00Z"}',
        ],
      ),
      repository.appendExerciseNotes(
        date: DateTime.now(),
        encodedEntries: const [
          '{"id":"breathing","name":"Breathing recovery","minutes":25,"recordedAt":"2026-08-13T08:01:00Z"}',
        ],
      ),
    ]);
    final notes = (await repository.getForDay(DateTime.now()))!.exerciseNotes!;
    expect(notes, contains('"id":"walk"'));
    expect(notes, contains('"id":"breathing"'));
    expect(notes.split('\n'), hasLength(2));
  });

  test(
    'atomic append rejects malformed or multiline structured entries',
    () async {
      final repository = DailyLogRepository(database);
      for (final entry in const [
        'not-json',
        '{"id":"walk"}',
        '{"id":"walk","name":"Walk","minutes":20,"recordedAt":"bad"}',
        '{"id":"walk","name":"Walk","minutes":20,"recordedAt":"2026-08-13T08:00:00Z"}\n{}',
      ]) {
        await expectLater(
          repository.appendExerciseNotes(
            date: DateTime.now(),
            encodedEntries: [entry],
          ),
          throwsArgumentError,
        );
      }
      expect(await repository.getForDay(DateTime.now()), isNull);
    },
  );

  testWidgets('changing tabs exits multi-select and clears hidden selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Multi-add'));
    await tester.pump();
    await tester.tap(find.text('Brisk walk').last);
    await tester.pump();
    expect(find.text('Log 1'), findsOneWidget);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Log 1'), findsNothing);
    expect(find.text('Multi-add'), findsOneWidget);
  });

  testWidgets('Arabic custom row exposes open and delete actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'wellness.custom_exercises.v1':
          '[{"id":"custom-one","name":"تمرين خاص","category":"Strength"}]',
    });
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(locale: const Locale('ar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تماريني'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('تمرين خاص'), findsWidgets);
    expect(find.byTooltip('حذف'), findsOneWidget);
    expect(find.bySemanticsLabel('حذف'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('history load failure is explicit and retryable', (tester) async {
    final repository = _FailingLoadDailyLogRepository(database);
    await tester.pumpWidget(app(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load exercise history.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

class _FailingDailyLogRepository extends DailyLogRepository {
  _FailingDailyLogRepository(super.database);

  @override
  Future<void> appendExerciseNotes({
    required DateTime date,
    required List<String> encodedEntries,
  }) async {
    throw StateError('injected write failure');
  }
}

class _FailingLoadDailyLogRepository extends DailyLogRepository {
  _FailingLoadDailyLogRepository(super.database);

  @override
  Future<List<DailyLog>> getAll() async {
    throw StateError('injected history failure');
  }
}
