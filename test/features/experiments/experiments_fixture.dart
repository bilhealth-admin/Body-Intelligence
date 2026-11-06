import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/experiment_repository.dart';
import 'package:body_intelligence_log/features/experiments/experiments_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../qa_next/feature_splashes_test_support.dart'
    show closeFeatureSplashDatabase;

List<ExperimentsFixture>? _fixturesInTest;

void experimentTestWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    final fixtures = <ExperimentsFixture>[];
    _fixturesInTest = fixtures;
    try {
      await body(tester);
    } finally {
      for (final fixture in fixtures.reversed) {
        await fixture.dispose();
      }
      _fixturesInTest = null;
    }
  });
}

class ControlledExperimentRepository extends ExperimentRepository {
  ControlledExperimentRepository(super.database);

  int watchFailures = 0,
      createFailures = 0,
      completeFailures = 0,
      deleteFailures = 0;
  int watchCalls = 0, createCalls = 0, completeCalls = 0, deleteCalls = 0;
  Completer<void>? watchBarrier, createBarrier, completeBarrier, deleteBarrier;

  @override
  Stream<List<PersonalExperiment>> watchAll() async* {
    watchCalls++;
    await watchBarrier?.future;
    if (watchFailures > 0) {
      watchFailures--;
      throw Exception('Synthetic read failure');
    }
    yield* super.watchAll();
  }

  @override
  Future<int> create({
    required String hypothesis,
    required String changedVariable,
    required String controlledFactors,
    required String requiredData,
    required DateTime startedAt,
    required int durationDays,
  }) async {
    createCalls++;
    await createBarrier?.future;
    if (createFailures > 0) {
      createFailures--;
      throw Exception('Synthetic create failure before write');
    }
    return super.create(
      hypothesis: hypothesis,
      changedVariable: changedVariable,
      controlledFactors: controlledFactors,
      requiredData: requiredData,
      startedAt: startedAt,
      durationDays: durationDays,
    );
  }

  @override
  Future<void> complete({
    required int id,
    required double adherence,
    required String result,
    required String limitations,
    required String confidence,
  }) async {
    completeCalls++;
    await completeBarrier?.future;
    if (completeFailures > 0) {
      completeFailures--;
      throw Exception('Synthetic completion failure before write');
    }
    return super.complete(
      id: id,
      adherence: adherence,
      result: result,
      limitations: limitations,
      confidence: confidence,
    );
  }

  @override
  Future<void> delete(int id) async {
    deleteCalls++;
    await deleteBarrier?.future;
    if (deleteFailures > 0) {
      deleteFailures--;
      throw Exception('Synthetic delete failure before write');
    }
    return super.delete(id);
  }
}

Future<int> seedActiveExperiment(ExperimentRepository repository) =>
    repository.create(
      hypothesis: 'A steadier breakfast may help my morning energy.',
      changedVariable: 'Keep the breakfast protein source consistent',
      controlledFactors: 'Keep the usual activity routine',
      requiredData: 'Breakfast and recorded energy',
      startedAt: DateTime.now(),
      durationDays: 7,
    );

class ExperimentsFixture {
  ExperimentsFixture(
    this.database,
    this.repository,
    this.router,
    this.language,
    this.tester,
  );
  final AppDatabase database;
  final ControlledExperimentRepository repository;
  final GoRouter router;
  final String language;
  final WidgetTester tester;
  bool _disposed = false;
  String t(String english) => AppLocalizations(Locale(language)).text(english);
  Future<T> real<T>(Future<T> Function() action) async {
    T? result;
    Object? failure;
    StackTrace? failureStack;
    await tester.runAsync(() async {
      try {
        result = await action().timeout(const Duration(seconds: 5));
      } on Object catch (error, stack) {
        failure = error;
        failureStack = stack;
      }
    });
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
    return result as T;
  }

  Future<List<PersonalExperiment>> rows() =>
      real(() => database.select(database.personalExperiments).get());
  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == t(label),
  );

  Future<void> tap(WidgetTester tester, String english) async {
    final matches = find.text(t(english));
    if (matches.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        matches,
        250,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
        maxScrolls: 40,
      );
    }
    final target = matches.last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final barrier in [
      repository.watchBarrier,
      repository.createBarrier,
      repository.completeBarrier,
      repository.deleteBarrier,
    ]) {
      if (barrier != null && !barrier.isCompleted) barrier.complete();
    }
    // This runs inside the test body's finally, before Flutter verifies that
    // automatic unmount left no timers. addTearDown is too late for that gate.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    await tester.pump(Duration.zero);
    await closeFeatureSplashDatabase(tester, database);
    await tester.binding.setSurfaceSize(null);
  }
}

Future<ExperimentsFixture> pumpExperiments(
  WidgetTester tester, {
  String language = 'en',
  bool seedActive = false,
  bool pushed = false,
  bool settle = true,
  void Function(ControlledExperimentRepository)? configure,
}) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final repository = ControlledExperimentRepository(database);
  final router = GoRouter(
    initialLocation: pushed ? '/dashboard' : '/experiments',
    routes: [
      GoRoute(path: '/experiments', builder: (_, _) => const ExperimentsPage()),
      GoRoute(
        path: '/dashboard',
        builder: (context, _) => Scaffold(
          key: const Key('experiments-return-dashboard'),
          body: Center(
            child: FilledButton(
              onPressed: () => context.push('/experiments'),
              child: const Text('Open experiments'),
            ),
          ),
        ),
      ),
    ],
  );
  final fixture = ExperimentsFixture(
    database,
    repository,
    router,
    language,
    tester,
  );
  final fixtures = _fixturesInTest;
  if (fixtures == null) {
    throw StateError('Use experimentTestWidgets for owned cleanup');
  }
  fixtures.add(fixture);
  // Open SQLite in the real runner zone rather than making native I/O depend
  // on the widget fake clock. All explicit database readbacks use this bound.
  await fixture.real(() => database.customSelect('SELECT 1').getSingle());
  if (seedActive) await fixture.real(() => seedActiveExperiment(repository));
  configure?.call(repository);
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        experimentRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  if (pushed) {
    await tester.tap(find.text('Open experiments'));
    await tester.pumpAndSettle();
  }
  return fixture;
}
