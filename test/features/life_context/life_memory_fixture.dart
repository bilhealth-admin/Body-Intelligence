import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/decision_memory_repository.dart';
import 'package:body_intelligence_log/data/repositories/life_context_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_memory_repository.dart';
import 'package:body_intelligence_log/features/life_context/coach_memory_sync_review_panel.dart';
import 'package:body_intelligence_log/features/life_context/decision_memory_page.dart';
import 'package:body_intelligence_log/features/life_context/life_context_page.dart';
import 'package:body_intelligence_log/features/life_context/providers/life_context_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../qa_next/feature_splashes_test_support.dart'
    show closeFeatureSplashDatabase;

List<LifeMemoryFixture>? _fixtures;

void lifeMemoryTestWidgets(
  String name,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(name, (tester) async {
    final owned = <LifeMemoryFixture>[];
    _fixtures = owned;
    try {
      await body(tester);
    } finally {
      for (final fixture in owned.reversed) {
        await fixture.dispose();
      }
      _fixtures = null;
    }
  });
}

class ControlledLifeContextRepository extends LifeContextRepository {
  ControlledLifeContextRepository(super.database);
  int addCalls = 0, addFinished = 0, consentCalls = 0, deleteCalls = 0;
  int addFailures = 0, consentFailures = 0, deleteFailures = 0;
  Completer<void>? addBarrier, consentBarrier, deleteBarrier;

  @override
  Future<int> add({
    String? uuid,
    required DateTime occurredAt,
    required String type,
    String? details,
    bool useInInsights = true,
  }) async {
    addCalls++;
    try {
      await addBarrier?.future;
      if (addFailures > 0) {
        addFailures--;
        throw Exception('Synthetic life context insert failure before write');
      }
      return await super.add(
        uuid: uuid,
        occurredAt: occurredAt,
        type: type,
        details: details,
        useInInsights: useInInsights,
      );
    } finally {
      addFinished++;
    }
  }

  @override
  Future<void> setInsightConsent(int id, bool enabled) async {
    consentCalls++;
    await consentBarrier?.future;
    if (consentFailures > 0) {
      consentFailures--;
      throw Exception('Synthetic consent failure before write');
    }
    return super.setInsightConsent(id, enabled);
  }

  @override
  Future<void> delete(int id) async {
    deleteCalls++;
    await deleteBarrier?.future;
    if (deleteFailures > 0) {
      deleteFailures--;
      throw Exception('Synthetic life context delete failure before write');
    }
    return super.delete(id);
  }
}

class ControlledDecisionMemoryRepository extends DecisionMemoryRepository {
  ControlledDecisionMemoryRepository(super.database);
  int evaluateCalls = 0, evaluateFinished = 0, deleteCalls = 0, forgetCalls = 0;
  int evaluateFailures = 0, deleteFailures = 0, forgetFailures = 0;
  Completer<void>? evaluateBarrier, deleteBarrier, forgetBarrier;

  @override
  Future<void> evaluate({
    required int id,
    required int helpfulness,
    String? outcome,
  }) async {
    evaluateCalls++;
    try {
      await evaluateBarrier?.future;
      if (evaluateFailures > 0) {
        evaluateFailures--;
        throw Exception('Synthetic rating failure before write');
      }
      await super.evaluate(id: id, helpfulness: helpfulness, outcome: outcome);
    } finally {
      evaluateFinished++;
    }
  }

  @override
  Future<void> delete(int id) async {
    deleteCalls++;
    await deleteBarrier?.future;
    if (deleteFailures > 0) {
      deleteFailures--;
      throw Exception('Synthetic decision delete failure before write');
    }
    return super.delete(id);
  }

  @override
  Future<int> forgetUnhelpful() async {
    forgetCalls++;
    await forgetBarrier?.future;
    if (forgetFailures > 0) {
      forgetFailures--;
      throw Exception('Synthetic bulk forget failure before write');
    }
    return super.forgetUnhelpful();
  }
}

class ControlledMemoryPreferences extends PreferencesRepository {
  ControlledMemoryPreferences(super.database);
  final calls = <String, int>{};
  final failures = <String, int>{};
  final barriers = <String, Completer<void>>{};

  @override
  Future<void> set(String key, String value) async {
    calls[key] = (calls[key] ?? 0) + 1;
    await barriers[key]?.future;
    if ((failures[key] ?? 0) > 0) {
      failures[key] = failures[key]! - 1;
      throw Exception('Synthetic local preference failure before write');
    }
    return super.set(key, value);
  }
}

class LifeMemoryFixture {
  LifeMemoryFixture(
    this.tester,
    this.database,
    this.life,
    this.memory,
    this.preferences,
    this.router,
    this.container,
    this.language,
  );
  final WidgetTester tester;
  final AppDatabase database;
  final ControlledLifeContextRepository life;
  final ControlledDecisionMemoryRepository memory;
  final ControlledMemoryPreferences preferences;
  final GoRouter router;
  final ProviderContainer container;
  final String language;
  bool _disposed = false;
  String t(String value) => AppLocalizations(Locale(language)).text(value);

  Future<T> real<T>(Future<T> Function() action) async {
    T? result;
    Object? failure;
    StackTrace? stack;
    await tester.runAsync(() async {
      try {
        result = await action().timeout(const Duration(seconds: 5));
      } on Object catch (error, trace) {
        failure = error;
        stack = trace;
      }
    });
    if (failure != null) Error.throwWithStackTrace(failure!, stack!);
    return result as T;
  }

  Future<void> waitFor(bool Function() ready) async {
    final watch = Stopwatch()..start();
    while (!ready() && watch.elapsed < const Duration(seconds: 5)) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(ready(), isTrue);
  }

  Future<void> tap(Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
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
    await tester.ensureVisible(finder.last);
    await tester.pumpAndSettle();
    await tester.tap(finder.last);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(String english) => tap(find.text(t(english)));
  Future<List<LifeContextEntry>> lifeRows() =>
      real(() => database.select(database.lifeContextEntries).get());
  Future<List<DecisionMemory>> memoryRows() =>
      real(() => database.select(database.decisionMemories).get());

  Future<int> seedLife() => real(
    () => LifeContextRepository(database).add(
      occurredAt: DateTime.now(),
      type: 'travel',
      details: 'Synthetic context',
    ),
  );

  Future<int> seedMemory({
    BestActionType type = BestActionType.weighIn,
    String title = 'Synthetic recommendation',
    int? helpfulness,
  }) => real(() async {
    final repository = DecisionMemoryRepository(database);
    final id = await repository.rememberAction(
      BestAction(
        type: type,
        title: title,
        reason: 'Synthetic reason',
        evidence: const ['Synthetic evidence'],
      ),
    );
    if (helpfulness != null) {
      await repository.evaluate(id: id, helpfulness: helpfulness);
    }
    return id;
  });

  Future<Map<String, Object?>> seedExplicit(String text) => real(
    () => CoachMemoryRepository(
      preferences: preferences,
    ).saveConfirmed(text: text),
  );

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final gate in [
      life.addBarrier,
      life.consentBarrier,
      life.deleteBarrier,
      memory.evaluateBarrier,
      memory.deleteBarrier,
      memory.forgetBarrier,
      ...preferences.barriers.values,
    ]) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    container.dispose();
    await tester.pump(Duration.zero);
    await closeFeatureSplashDatabase(tester, database);
    await tester.binding.setSurfaceSize(null);
  }
}

Future<LifeMemoryFixture> pumpLifeMemory(
  WidgetTester tester, {
  bool memory = false,
  String language = 'en',
  Future<void> Function(LifeMemoryFixture)? seed,
}) async {
  final database = (await tester.runAsync(() async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'synthetic-life-memory-owner',
    );
    await database
        .customSelect('SELECT 1')
        .getSingle()
        .timeout(const Duration(seconds: 5));
    return database;
  }))!;
  final lifeRepository = ControlledLifeContextRepository(database);
  final memoryRepository = ControlledDecisionMemoryRepository(database);
  final preferences = ControlledMemoryPreferences(database);
  final router = GoRouter(
    initialLocation: memory ? '/memory' : '/life',
    routes: [
      GoRoute(path: '/life', builder: (_, _) => const LifeContextPage()),
      GoRoute(path: '/memory', builder: (_, _) => const DecisionMemoryPage()),
      GoRoute(
        path: '/away',
        builder: (_, _) => const Scaffold(body: Text('Away')),
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      lifeContextRepositoryProvider.overrideWithValue(lifeRepository),
      decisionMemoryRepositoryProvider.overrideWithValue(memoryRepository),
      preferencesRepositoryProvider.overrideWithValue(preferences),
      // This fixture exercises local page writes; cloud conflict review has its
      // own suite and must never contact a real account from a local widget test.
      coachMemorySyncIssuesProvider.overrideWith((_) async => []),
    ],
  );
  final fixture = LifeMemoryFixture(
    tester,
    database,
    lifeRepository,
    memoryRepository,
    preferences,
    router,
    container,
    language,
  );
  final owned = _fixtures;
  if (owned == null) {
    throw StateError('Use lifeMemoryTestWidgets for owned cleanup');
  }
  owned.add(fixture);
  if (seed != null) await seed(fixture);
  await tester.binding.setSurfaceSize(const Size(430, 1100));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
  await fixture.waitFor(
    () => memory
        ? container.read(decisionMemoriesProvider).hasValue &&
              container.read(explicitCoachMemoriesProvider).hasValue &&
              container.read(decisionMemoryEnabledProvider).hasValue
        : container.read(todayLifeContextProvider).hasValue,
  );
  await tester.pumpAndSettle();
  return fixture;
}
