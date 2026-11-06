import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/challenge_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/engine/challenge_engine.dart';
import 'package:body_intelligence_log/features/challenges/challenges_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'challenges_fixture.dart';

void main() {
  testWidgets(
    'automatic completion stays single flight across unrelated theme rebuilds',
    (tester) async {
      final f = _CompletionFixture(tester);
      final gate = Completer<void>();
      f.repository.completionBarrier = gate;
      try {
        await f.mount();
        await f.until(
          () => f.repository.completeCalls > 0,
          'eligible real water evidence must request automatic completion',
        );
        expect(f.repository.completeCalls, 1);
        expect(f.repository.finishedCalls, 0);
        expect((await f.base.rows()).single.status, 'active');
        final originalEvidence = f.progress;
        expect(originalEvidence.qualifyingDays, 1);
        expect(originalEvidence.complete, isTrue);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          1,
        );
        for (final brightness in [
          Brightness.dark,
          Brightness.light,
          Brightness.dark,
        ]) {
          await f.changeTheme(brightness);
          expect(identical(f.progress, originalEvidence), isTrue);
          expect(
            f.repository.completeCalls,
            1,
            reason: 'A Theme rebuild is not a new completion request.',
          );
          expect(f.repository.finishedCalls, 0);
        }
        gate.complete();
        await f.until(
          () async => (await f.base.rows()).single.status == 'completed',
          'accepted completion must reach real SQLite',
        );
        await f.until(
          () => f.repository.finishedCalls == 1,
          'accepted completion must finish',
        );
        final row = (await f.base.rows()).single;
        expect(row.revision, 2);
        expect(row.completedAt, isNotNull);
        expect(f.repository.completeCalls, 1);
        expect(f.repository.completedWrites, 1);
        expect(
          await f.base.real(
            () => WaterRepository(f.base.database).totalForDay(f.day),
          ),
          2000,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await f.dispose();
      }
    },
  );

  testWidgets(
    'failed automatic completion waits for fresh real diary evidence to retry',
    (tester) async {
      final f = _CompletionFixture(tester);
      f.repository.completionFailures = 1;
      try {
        await f.mount();
        await f.until(
          () => f.repository.finishedCalls == 1,
          'the synthetic pre-write failure must settle',
        );
        expect(f.repository.completeCalls, 1);
        expect(f.repository.completedWrites, 0);
        var row = (await f.base.rows()).single;
        expect(row.status, 'active');
        expect(row.revision, 1);
        expect(row.completedAt, isNull);
        final originalEvidence = f.progress;
        expect(originalEvidence.complete, isTrue);
        for (final brightness in [
          Brightness.dark,
          Brightness.light,
          Brightness.dark,
        ]) {
          await f.changeTheme(brightness);
          expect(identical(f.progress, originalEvidence), isTrue);
          expect(
            f.repository.completeCalls,
            1,
            reason: 'A caught failure must not retry from a Theme rebuild.',
          );
        }
        row = (await f.base.rows()).single;
        expect(row.status, 'active');
        expect(row.revision, 1);
        expect(tester.takeException(), isNull);
        await f.base.real(
          () => WaterRepository(
            f.base.database,
          ).add(occurredAt: f.day, amountMl: 50),
        );
        await f.until(
          () async => (await f.base.rows()).single.status == 'completed',
          'new real diary evidence must retain automatic retry',
        );
        await f.until(
          () => f.repository.finishedCalls == 2,
          'exactly one retry must finish',
        );
        row = (await f.base.rows()).single;
        expect(f.repository.completeCalls, 2);
        expect(f.repository.completedWrites, 1);
        expect(row.revision, 2);
        expect(row.completedAt, isNotNull);
        expect(
          await f.base.real(
            () => WaterRepository(f.base.database).totalForDay(f.day),
          ),
          2050,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await f.dispose();
      }
    },
  );
}

class _ObservedCompletionRepository extends ControlledChallengeRepository {
  _ObservedCompletionRepository(super.database);
  int completeCalls = 0;
  int finishedCalls = 0;
  int completedWrites = 0;
  int completionFailures = 0;
  Completer<void>? completionBarrier;

  @override
  Future<void> markComplete(int id) async {
    completeCalls++;
    try {
      await completionBarrier?.future;
      if (completionFailures > 0) {
        completionFailures--;
        throw StateError('Synthetic automatic completion failure before write');
      }
      // The success path uses the unchanged real SQLite repository write.
      await super.markComplete(id);
      completedWrites++;
    } finally {
      finishedCalls++;
    }
  }
}

class _CompletionFixture {
  factory _CompletionFixture(WidgetTester tester) {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = _ObservedCompletionRepository(database);
    final router = GoRouter(
      initialLocation: '/challenges',
      routes: [
        GoRoute(path: '/challenges', builder: (_, _) => const ChallengesPage()),
      ],
    );
    final base = ChallengesFixture(tester, database, repository, router);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        challengeRepositoryProvider.overrideWithValue(repository),
        dashboardNutrientGoalProvider(
          'goal.proteinGrams',
        ).overrideWith((_) => Stream<double?>.value(null)),
        dashboardNutrientGoalProvider(
          'goal.fiber',
        ).overrideWith((_) => Stream<double?>.value(null)),
      ],
    );
    return _CompletionFixture._(base, repository, container);
  }

  _CompletionFixture._(this.base, this.repository, this.container);
  final ChallengesFixture base;
  final _ObservedCompletionRepository repository;
  final ProviderContainer container;
  final brightness = ValueNotifier(Brightness.light);
  final day = DateTime.now();
  final _goalSubscriptions = <ProviderSubscription<AsyncValue<double?>>>[];
  late Challenge challenge;
  ChallengeProgress get progress =>
      container.read(challengeProgressProvider(challenge)).requireValue;

  Future<void> mount() async {
    await base.real(() => base.database.customSelect('SELECT 1').getSingle());
    await base.real(
      () => ChallengeRepository(base.database).start(
        type: 'water',
        title: 'Automatic hydration completion',
        targetDays: 1,
        startedAt: DateTime(day.year, day.month, day.day),
      ),
    );
    await base.real(
      () => WaterRepository(base.database).add(occurredAt: day, amountMl: 2000),
    );
    challenge = (await base.rows()).single;
    // Settle real async goal providers first; these tests vary only Theme or
    // actual diary records, not unrelated initial provider loading transitions.
    for (final key in ['goal.proteinGrams', 'goal.fiber']) {
      final provider = dashboardNutrientGoalProvider(key);
      _goalSubscriptions.add(
        container.listen(provider, (_, _) {}, fireImmediately: true),
      );
      await base.real(() => container.read(provider.future));
    }
    await base.tester.binding.setSurfaceSize(const Size(390, 844));
    await base.tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ValueListenableBuilder<Brightness>(
          valueListenable: brightness,
          builder: (_, value, _) => MaterialApp.router(
            routerConfig: base.router,
            theme: ThemeData(brightness: value),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> changeTheme(Brightness value) async {
    brightness.value = value;
    await base.tester.pumpAndSettle(
      const Duration(milliseconds: 20),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(
      Theme.of(
        base.tester.element(find.byType(LinearProgressIndicator)),
      ).brightness,
      value,
    );
  }

  Future<void> until(FutureOr<bool> Function() condition, String reason) async {
    final watch = Stopwatch()..start();
    while (watch.elapsed < const Duration(seconds: 5)) {
      await base.tester.pump(Duration.zero);
      if (await condition()) return;
      await base.real(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    fail('Bounded automatic-completion wait: $reason');
  }

  Future<void> dispose() async {
    // All cleanup occurs before the widget-test invariant check. Unmount first
    // so failed pre-fix assertions cannot schedule more completion requests.
    await base.tester.pumpWidget(const SizedBox.shrink());
    final gate = repository.completionBarrier;
    if (gate != null && !gate.isCompleted) gate.complete();
    await until(
      () => repository.finishedCalls == repository.completeCalls,
      'drain accepted real SQLite completion writes before closing',
    );
    for (final subscription in _goalSubscriptions) {
      subscription.close();
    }
    container.dispose();
    await base.tester.pump(Duration.zero);
    await base.dispose();
    brightness.dispose();
  }
}
