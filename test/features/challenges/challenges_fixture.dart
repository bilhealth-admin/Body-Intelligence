import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/challenge_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/challenges/challenges_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../qa_next/feature_splashes_test_support.dart'
    show closeFeatureSplashDatabase;

List<ChallengesFixture>? _fixturesInTest;

void challengeTestWidgets(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    final fixtures = <ChallengesFixture>[];
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

class ControlledChallengeRepository extends ChallengeRepository {
  ControlledChallengeRepository(super.database);
  int startFailures = 0, deleteFailures = 0, startCalls = 0, deleteCalls = 0;
  Completer<void>? startBarrier, deleteBarrier;

  @override
  Future<int> start({
    required String type,
    required String title,
    required int targetDays,
    String audience = 'private',
    DateTime? startedAt,
  }) async {
    startCalls++;
    await startBarrier?.future;
    if (startFailures > 0) {
      startFailures--;
      throw Exception('Synthetic challenge start failure before write');
    }
    return super.start(
      type: type,
      title: title,
      targetDays: targetDays,
      audience: audience,
      startedAt: startedAt,
    );
  }

  @override
  Future<void> delete(int id) async {
    deleteCalls++;
    await deleteBarrier?.future;
    if (deleteFailures > 0) {
      deleteFailures--;
      throw Exception('Synthetic challenge delete failure before write');
    }
    return super.delete(id);
  }
}

class ChallengesFixture {
  ChallengesFixture(this.tester, this.database, this.repository, this.router);
  final WidgetTester tester;
  final AppDatabase database;
  final ControlledChallengeRepository repository;
  final GoRouter router;
  bool _disposed = false;

  String t(String english) =>
      AppLocalizations(const Locale('en')).text(english);
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
    if (failure != null) {
      Error.throwWithStackTrace(failure!, stack!);
    }
    return result as T;
  }

  Future<List<Challenge>> rows() =>
      real(() => database.select(database.challenges).get());
  Finder get deleteButton => find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == t('Delete'),
  );

  Future<Finder> reveal(Finder matches) async {
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
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    return target;
  }

  Future<void> tapText(String english) async {
    final target = await reveal(find.text(t(english)));
    await tester.tap(target);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  }

  Future<void> tapDelete() async {
    final target = await reveal(deleteButton);
    await tester.tap(target);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final barrier in [repository.startBarrier, repository.deleteBarrier]) {
      if (barrier != null && !barrier.isCompleted) {
        barrier.complete();
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    await tester.pump(Duration.zero);
    await closeFeatureSplashDatabase(tester, database);
    await tester.binding.setSurfaceSize(null);
  }
}

Future<ChallengesFixture> pumpChallenges(
  WidgetTester tester, {
  bool seedChallenge = false,
  bool deletedWater = false,
  void Function(ControlledChallengeRepository)? configure,
}) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final repository = ControlledChallengeRepository(database);
  final router = GoRouter(
    initialLocation: '/challenges',
    routes: [
      GoRoute(path: '/challenges', builder: (_, _) => const ChallengesPage()),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(
          key: Key('challenge-return-dashboard'),
          body: Text('Today'),
        ),
      ),
      GoRoute(
        path: '/daily-log',
        builder: (_, _) => const Scaffold(body: Text('Diary')),
      ),
    ],
  );
  final fixture = ChallengesFixture(tester, database, repository, router);
  final fixtures = _fixturesInTest;
  if (fixtures == null) {
    throw StateError('Use challengeTestWidgets for owned cleanup');
  }
  fixtures.add(fixture);
  await fixture.real(() => database.customSelect('SELECT 1').getSingle());
  if (seedChallenge) {
    await fixture.real(
      () => ChallengeRepository(database).start(
        type: 'water',
        title: 'Hydration test',
        targetDays: 1,
        startedAt: DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        ),
      ),
    );
  }
  if (deletedWater) {
    await fixture.real(() async {
      final water = WaterRepository(database);
      final id = await water.add(occurredAt: DateTime.now(), amountMl: 2000);
      await water.delete(id);
      return id;
    });
  }
  configure?.call(repository);
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    ProviderScope(
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
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
  return fixture;
}
