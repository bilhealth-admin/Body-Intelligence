import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/meal_planner/domain/meal_plan.dart';
import 'package:body_intelligence_log/features/meal_planner/presentation/meal_planner_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _weekKey = 'mealPlanner.week.v1';
const _checksKey = 'mealPlanner.groceryChecks.v1';

final _ownerRepositoryProvider = StateProvider<PreferencesRepository?>(
  (ref) => null,
);

final class _ControlledRepository extends PreferencesRepository {
  _ControlledRepository(super.database);

  bool offline = false;
  bool rejectMutation = false;
  Completer<void>? readGate;
  Completer<void>? writeGate;
  int attemptedMutations = 0;

  @override
  Future<String?> get(String key) async {
    if (readGate case final gate?) await gate.future;
    if (offline) throw StateError('synthetic offline');
    return super.get(key);
  }

  @override
  Future<bool> mutateIfUnchanged({
    required Map<String, String?> expected,
    Map<String, String> set = const {},
    Iterable<String> remove = const [],
    bool Function()? isCurrent,
  }) async {
    attemptedMutations++;
    if (writeGate case final gate?) await gate.future;
    if (rejectMutation) throw StateError('synthetic write failure');
    return super.mutateIfUnchanged(
      expected: expected,
      set: set,
      remove: remove,
      isCurrent: isCurrent,
    );
  }
}

WeeklyMealPlan _plan(String id) => WeeklyMealPlan(
  createdAt: DateTime(2026, 10, 25),
  meals: [PlannedMeal(day: 0, recipeId: id)],
);

Future<void> _seed(PreferencesRepository repo, String id) async {
  await repo.set(_weekKey, _plan(id).encode());
}

Future<void> _pumpPlanner(
  WidgetTester tester,
  PreferencesRepository repository, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
  GoRouter? router,
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [preferencesRepositoryProvider.overrideWithValue(repository)],
      child: router == null
          ? MaterialApp(
              locale: locale,
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const MealPlannerPage(),
            )
          : MaterialApp.router(
              locale: locale,
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              routerConfig: router,
            ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _dispose(WidgetTester tester, AppDatabase database) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await database.close();
  await tester.binding.setSurfaceSize(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'offline saved week cannot be overwritten until successful retry',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = _ControlledRepository(db);
      addTearDown(() => _dispose(tester, db));
      await _seed(repo, 'lentil_soup');
      final original = await repo.get(_weekKey);
      repo.offline = true;
      await _pumpPlanner(tester, repo);
      final generate = find.byKey(const Key('generate-weekly-meal-plan'));
      expect(tester.widget<FilledButton>(generate).onPressed, isNull);
      expect(repo.attemptedMutations, 0);
      expect(await PreferencesRepository(db).get(_weekKey), original);

      repo.offline = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(generate).onPressed, isNotNull);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(repo.attemptedMutations, 1);
      expect(await repo.get(_weekKey), isNotNull);
    },
  );

  testWidgets(
    'corrupt final grocery key never partially installs stored plan',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = _ControlledRepository(db);
      addTearDown(() => _dispose(tester, db));
      await _seed(repo, 'lentil_soup');
      await repo.set(_checksKey, '{broken');
      await _pumpPlanner(tester, repo);
      expect(find.text('Red lentil soup'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('generate-weekly-meal-plan')),
            )
            .onPressed,
        isNull,
      );
      expect(await repo.get(_weekKey), _plan('lentil_soup').encode());

      await repo.set(_checksKey, '[]');
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Red lentil soup'), findsOneWidget);
    },
  );

  testWidgets(
    'missing saved recipe remains visible safely in Week and Meal prep',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = _ControlledRepository(db);
      addTearDown(() => _dispose(tester, db));
      await _seed(repo, 'deleted_recipe');
      final original = await repo.get(_weekKey);
      await _pumpPlanner(tester, repo);
      expect(find.textContaining('no longer available'), findsOneWidget);
      await tester.ensureVisible(find.text('Meal prep'));
      await tester.tap(find.text('Meal prep'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no longer available'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(await repo.get(_weekKey), original);
      expect(repo.attemptedMutations, 0);
    },
  );

  testWidgets(
    'failed generation keeps previous durable week and explicit retry',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = _ControlledRepository(db);
      addTearDown(() => _dispose(tester, db));
      await _seed(repo, 'lentil_soup');
      final original = await repo.get(_weekKey);
      repo.rejectMutation = true;
      await _pumpPlanner(tester, repo);
      await tester.tap(find.byKey(const Key('generate-weekly-meal-plan')));
      await tester.pumpAndSettle();
      expect(await repo.get(_weekKey), original);
      expect(find.textContaining('could not be saved'), findsOneWidget);
      repo.rejectMutation = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repo.attemptedMutations, 2);
    },
  );

  testWidgets(
    'rapid grocery taps serialize writes and never save stale checklist',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = _ControlledRepository(db);
      addTearDown(() => _dispose(tester, db));
      await _seed(repo, 'lentil_soup');
      await _pumpPlanner(tester, repo);
      await tester.tap(find.text('Grocery list'));
      await tester.pumpAndSettle();
      final carrot = find.widgetWithText(CheckboxListTile, 'Carrot');
      final onion = find.widgetWithText(CheckboxListTile, 'Onion');
      repo.writeGate = Completer<void>();
      await tester.tap(carrot);
      await tester.pump();
      expect(repo.attemptedMutations, 1);
      expect(tester.widget<CheckboxListTile>(onion).onChanged, isNull);
      await tester.tap(onion, warnIfMissed: false);
      await tester.pump();
      expect(repo.attemptedMutations, 1);
      repo.writeGate!.complete();
      await tester.pumpAndSettle();
      final persisted = (jsonDecode((await repo.get(_checksKey))!) as List)
          .cast<String>();
      expect(persisted, ['Carrot']);
      expect(repo.attemptedMutations, 1);
    },
  );

  testWidgets(
    '320px Arabic RTL tabs scroll and long recipe sheet avoids overflow',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = _ControlledRepository(db);
      addTearDown(() => _dispose(tester, db));
      await _seed(repo, 'lentil_soup');
      await _pumpPlanner(
        tester,
        repo,
        size: const Size(320, 540),
        locale: const Locale('ar'),
      );
      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.isScrollable, isTrue);
      expect(
        Directionality.of(tester.element(find.byType(TabBar))),
        TextDirection.rtl,
      );
      // A 320px RTL screen does not initially build the offscreen recipe.
      // Scroll the actual Week ListView rather than tapping a missing child.
      final weekScroll = find.descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Red lentil soup'),
        160,
        scrollable: weekScroll,
      );
      await tester.tap(find.text('Red lentil soup'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('راجع وسجّل'));
      await tester.pumpAndSettle();
      expect(find.text('راجع وسجّل').hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'Review and log only navigates with hints, without writing a diary meal',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = _ControlledRepository(db);
      addTearDown(() => _dispose(tester, db));
      await _seed(repo, 'lentil_soup');
      final router = GoRouter(
        initialLocation: '/meal-planner',
        routes: [
          GoRoute(
            path: '/meal-planner',
            builder: (_, _) => const MealPlannerPage(),
          ),
          GoRoute(
            path: '/daily-log',
            builder: (_, state) => Scaffold(
              body: Text(
                'REVIEW_ONLY:${state.uri.queryParameters['action']}:'
                '${state.uri.queryParameters['query']}',
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await _pumpPlanner(tester, repo, router: router);
      await tester.tap(find.text('Red lentil soup'));
      await tester.pumpAndSettle();
      // Recipe details are intentionally scrollable; the consent button
      // sits below the fold and must be brought on-screen for a real tap.
      await tester.ensureVisible(find.text('Review and log'));
      await tester.pumpAndSettle();
      expect(find.text('Review and log').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Review and log'));
      await tester.pumpAndSettle();
      expect(find.text('REVIEW_ONLY:food:Red lentil soup'), findsOneWidget);
      expect(repo.attemptedMutations, 0);
      expect(await db.select(db.meals).get(), isEmpty);
      expect(await db.select(db.mealItems).get(), isEmpty);
    },
  );

  testWidgets('A to B to A delayed reads never render the other account plan', (
    tester,
  ) async {
    final dbA = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-A',
    );
    final dbB = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-B',
    );
    final a = _ControlledRepository(dbA);
    final b = _ControlledRepository(dbB);
    await _seed(a, 'lentil_soup');
    await _seed(b, 'yogurt_oats');
    a.readGate = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        _ownerRepositoryProvider.overrideWith((ref) => a),
        preferencesRepositoryProvider.overrideWith(
          (ref) => ref.watch(_ownerRepositoryProvider)!,
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      await dbA.close();
      await dbB.close();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MealPlannerPage()),
      ),
    );
    await tester.pump();
    container.read(_ownerRepositoryProvider.notifier).state = b;
    await tester.pumpAndSettle();
    expect(find.text('Yogurt oat bowl'), findsOneWidget);
    container.read(_ownerRepositoryProvider.notifier).state = a;
    await tester.pump();
    expect(find.text('Yogurt oat bowl'), findsNothing);
    a.readGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Red lentil soup'), findsOneWidget);
    expect(find.text('Yogurt oat bowl'), findsNothing);
    expect(a.attemptedMutations, 0);
    expect(b.attemptedMutations, 0);
  });
}
