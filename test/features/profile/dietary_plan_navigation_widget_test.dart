import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/dietary_preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/domain/goal_timeline_estimator.dart';
import 'package:body_intelligence_log/features/profile/goal_timeline_card.dart';
import 'package:body_intelligence_log/features/profile/plan_navigation_contract.dart';
import 'package:body_intelligence_log/features/profile/plan_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'plan lists every pattern and style then saves back only to profile',
    (tester) async {
      final fixture = await _pumpPlan(tester, origin: PlanPageOrigin.profile);

      for (final label in const [
        'Omnivore',
        'Pescatarian',
        'Vegetarian',
        'Vegan',
        'Balanced',
        'High protein',
        'Low carb',
        'Keto',
        'Mediterranean',
        'Plant-forward',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'Missing $label');
      }

      await _selectAndSave(
        tester,
        pattern: DietaryPattern.vegan,
        approach: 'high_protein',
      );

      expect(
        fixture.router.routeInformationProvider.value.uri.path,
        '/profile-settings',
      );
      expect(find.byKey(const Key('return-profile')), findsOneWidget);
      expect(find.text('saved:vegan/high_protein'), findsOneWidget);
      expect(
        find.byKey(const Key('estimated-time-to-goal-field')),
        findsOneWidget,
      );
      final restored = await DietaryPreferencesRepository(
        PreferencesRepository(fixture.database),
      ).read();
      expect(restored.pattern, DietaryPattern.vegan);
      expect(restored.approach, 'high_protein');

      await fixture.dispose(tester);
    },
  );

  testWidgets('dashboard-origin save returns only to dashboard', (
    tester,
  ) async {
    final fixture = await _pumpPlan(tester, origin: PlanPageOrigin.dashboard);

    await _selectAndSave(
      tester,
      pattern: DietaryPattern.pescatarian,
      approach: 'mediterranean',
    );

    expect(
      fixture.router.routeInformationProvider.value.uri.path,
      '/dashboard',
    );
    expect(find.byKey(const Key('return-dashboard')), findsOneWidget);
    expect(find.text('saved:pescatarian/mediterranean'), findsOneWidget);
    expect(find.byKey(const Key('return-profile')), findsNothing);

    await fixture.dispose(tester);
  });

  testWidgets('a real plan edit prompts before explicit-origin discard', (
    tester,
  ) async {
    final fixture = await _pumpPlan(tester, origin: PlanPageOrigin.dashboard);

    final vegan = find.byKey(const Key('dietary-pattern-vegan'));
    await tester.ensureVisible(vegan);
    await tester.tap(vegan);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('secondary-page-back')));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dietary-system-selector')), findsOneWidget);

    await tester.tap(find.byKey(const Key('secondary-page-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(
      fixture.router.routeInformationProvider.value.uri.path,
      '/dashboard',
    );

    await fixture.dispose(tester);
  });

  testWidgets('plan reflects the pathway activated by the diet engine', (
    tester,
  ) async {
    final fixture = await _pumpPlan(
      tester,
      origin: PlanPageOrigin.profile,
      activePathwayId: 'carb-cycling',
    );

    await tester.scrollUntilVisible(
      find.text('Selected pathway'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Selected pathway'), findsOneWidget);
    expect(find.text('Carb cycling'), findsOneWidget);

    await fixture.dispose(tester);
  });
}

Future<void> _selectAndSave(
  WidgetTester tester, {
  required DietaryPattern pattern,
  required String approach,
}) async {
  final patternFinder = find.byKey(Key('dietary-pattern-${pattern.name}'));
  await tester.ensureVisible(patternFinder);
  await tester.tap(patternFinder);
  await tester.pump();
  final approachFinder = find.byKey(Key('dietary-approach-$approach'));
  await tester.ensureVisible(approachFinder);
  await tester.tap(approachFinder);
  await tester.pump();
  final save = find.byKey(const Key('plan-save-action'));
  await tester.scrollUntilVisible(
    save,
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<_PlanFixture> _pumpPlan(
  WidgetTester tester, {
  required PlanPageOrigin origin,
  String? activePathwayId,
}) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  await UserProfileRepository(database).save(
    gender: 'female',
    age: 34,
    height: 168,
    currentWeight: 78,
    targetWeight: 70,
    activityLevel: 'moderate',
    exercises: true,
  );
  if (activePathwayId != null) {
    await PreferencesRepository(
      database,
    ).set('activeNutritionPathway', activePathwayId);
  }
  final initial = '/plan?origin=${origin.queryValue}';
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/plan',
        builder: (_, state) => PlanPage(
          origin: PlanPageOrigin.fromQuery(state.uri.queryParameters['origin']),
        ),
      ),
      GoRoute(
        path: '/profile-settings',
        builder: (_, _) => const _ReturnProbe(key: Key('return-profile')),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const _ReturnProbe(key: Key('return-dashboard')),
      ),
    ],
  );
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: MaterialApp.router(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _PlanFixture(database: database, router: router);
}

class _ReturnProbe extends ConsumerWidget {
  const _ReturnProbe({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dietary = ref.watch(dietaryPreferencesProvider);
    final profile = ref.watch(userProfileProvider);
    return Scaffold(
      body: dietary.when(
        loading: () => const CircularProgressIndicator(),
        error: (_, _) => const Text('error'),
        data: (saved) => profile.when(
          loading: () => const CircularProgressIndicator(),
          error: (_, _) => const Text('error'),
          data: (body) => Column(
            children: [
              Text('saved:${saved.pattern.name}/${saved.approach}'),
              if (body != null)
                GoalTimelineCard(
                  estimate: GoalTimelineEstimator.estimate(
                    currentWeightKg: body.currentWeight,
                    targetWeightKg: body.targetWeight,
                    goalType: body.targetWeight < body.currentWeight
                        ? 'lose'
                        : body.targetWeight > body.currentWeight
                        ? 'gain'
                        : 'maintain',
                    asOf: DateTime(2026, 8, 24),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _PlanFixture {
  const _PlanFixture({required this.database, required this.router});

  final AppDatabase database;
  final GoRouter router;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    await database.close();
    await tester.binding.setSurfaceSize(null);
  }
}
