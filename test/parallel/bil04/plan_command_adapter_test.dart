import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_plan_adapter.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_nutrition_goal_resolver.dart';
import 'package:body_intelligence_log/features/nutrition_plans/data/diet_plan_repository.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/diet_macro_plan.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PreferencesRepository preferences;
  late NutritionGoalScheduleRepository schedule;
  late DietPlanRepository repository;
  late CoachPlanCommandAdapter adapter;
  late VerifiedSubscriptionLoader subscription;
  var subscriptionCalls = 0;
  final now = DateTime(2026, 10, 7, 12);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    preferences = PreferencesRepository(database);
    schedule = NutritionGoalScheduleRepository(preferences);
    repository = DietPlanRepository(
      preferences: preferences,
      schedule: schedule,
    );
    subscriptionCalls = 0;
    subscription = () async => _premium();
    adapter = CoachPlanCommandAdapter(
      database: database,
      command: DietPlanCommand(
        repository: repository,
        verifiedSubscription: () {
          subscriptionCalls += 1;
          return subscription();
        },
      ),
    );
  });
  tearDown(() => database.close());

  Future<Map<String, Object?>> resolve([
    Map<String, Object?> arguments = const {'pathwayId': 'carb-cycling'},
  ]) => adapter.resolve(
    toolId: 'activate_plan',
    operationId: 'plan-test',
    arguments: arguments,
    now: now,
    checkAccess: _allowed,
  );

  Future<Map<String, Object?>> snapshot(Map<String, Object?> proposal) =>
      adapter.snapshot(resolved: proposal, checkAccess: _allowed);

  Future<void> apply(
    Map<String, Object?> proposal,
    Map<String, Object?> before,
  ) => database.transaction(
    () => adapter.apply(
      resolved: proposal,
      before: before,
      checkAccess: _allowed,
    ),
  );

  Future<Map<String, String>> values() async => {
    for (final row in await database.select(database.preferences).get())
      row.key: row.value,
  };

  test(
    'preview reads saved drafts and requirements without any mutation',
    () async {
      await repository.saveDraft(_personalDraft('high-protein'));
      final before = await database.select(database.preferences).get();
      subscription = () async =>
          throw StateError('No entitlement call on preview');

      final preview = await adapter.preview(
        pathwayId: 'high-protein',
        checkAccess: _allowed,
      );
      expect(preview['kind'], 'plan_preview');
      expect(preview['active'], isFalse);
      expect(preview['confirmationRequired'], isTrue);
      expect(preview['activationRequirements'], {
        'verifiedPremiumPrograms': true,
        'clinicianReview': false,
        'medicalSupervision': false,
      });
      final week = preview['draftWeekTargets'] as Map;
      expect(week, hasLength(7));
      expect((week['1'] as Map)['caloriesKcal'], 1750);
      expect(preview['effectiveWeekTargets'], isEmpty);
      final keto = await adapter.preview(
        pathwayId: 'keto',
        checkAccess: _allowed,
      );
      expect(
        keto['activationRequirements'],
        containsPair('clinicianReview', true),
      );
      expect(subscriptionCalls, 0);
      expect(await database.select(database.preferences).get(), before);
      expect(await repository.readActivePathway(), isNull);
    },
  );

  test(
    'free activation uses exact command and updates the live weekly goal',
    () async {
      subscription = () async =>
          throw StateError('Free plan must not load Premium');
      const breakfast = NutritionGoalTarget(
        calories: 450,
        carbsPercent: 40,
        proteinPercent: 35,
        fatPercent: 25,
      );
      await schedule.saveMeal('breakfast', breakfast);
      final proposal = await resolve();
      final before = await snapshot(proposal);
      expect(await repository.readActivePathway(), isNull);

      await apply(proposal, before);

      expect(subscriptionCalls, 0);
      expect(await repository.readActivePathway(), 'carb-cycling');
      final goals = await schedule.read();
      expect(goals.dayTargets, hasLength(7));
      expect(goals.mealTargets['breakfast']!.calories, 450);
      expect(goals.mealTargets['breakfast']!.proteinPercent, closeTo(35, .001));
      final coach = CoachNutritionGoalResolver.resolveWithSources(
        localDay: now,
        fallback: const {'caloriesKcal': 999},
        schedule: goals,
      );
      expect(coach.targets['caloriesKcal'], goals.targetFor(now)!.calories);
      expect(coach.sources['caloriesKcal'], 'scheduled_daily_goal');
      final receipt = (await snapshot(proposal))['receipt'] as Map;
      expect(receipt['active'], isTrue);
      expect(receipt['activePathwayId'], 'carb-cycling');
      expect(receipt['effectiveWeekTargets'], hasLength(7));
    },
  );

  test(
    'Premium requires current verified authority and the exact grant',
    () async {
      final proposal = await resolve({'pathwayId': 'high-protein'});
      final before = await snapshot(proposal);
      final blocked = <VerifiedSubscriptionLoader>[
        () async => SubscriptionState(
          plan: CommercePlan.premium,
          entitlements: const {CommerceEntitlement.premiumPrograms},
          authority: EntitlementAuthority.localDefault,
          isPurchasable: false,
          canRestorePurchases: false,
        ),
        () async => SubscriptionState(
          plan: CommercePlan.free,
          entitlements: const {},
          authority: EntitlementAuthority.verifiedServer,
          isPurchasable: false,
          canRestorePurchases: false,
        ),
        () async => throw StateError('Subscription service unavailable'),
      ];
      for (final loader in blocked) {
        subscription = loader;
        await expectLater(
          apply(proposal, before),
          throwsA(_failure(NutritionPathwayActivationFailure.premiumRequired)),
        );
        expect(await values(), isEmpty);
      }
      expect(subscriptionCalls, blocked.length);
    },
  );

  test(
    'verified Premium activates the exact saved personalized draft',
    () async {
      await repository.saveDraft(_personalDraft('high-protein'));
      final proposal = await resolve({'pathwayId': 'high-protein'});
      final before = await snapshot(proposal);
      await apply(proposal, before);

      expect(subscriptionCalls, 1);
      expect(await repository.readActivePathway(), 'high-protein');
      final saved = await repository.read('high-protein');
      expect(saved.calories, 1750);
      expect(saved.carbsByWeekday.values.toSet(), {100.0});
      expect(
        (await schedule.read()).dayTargets.values
            .map((day) => day.calories)
            .toSet(),
        {1750.0},
      );
    },
  );

  test(
    'clinician review is never inferred from a request to activate',
    () async {
      for (final pathwayId in const ['keto', 'dash', 'pregnancy']) {
        final proposal = await resolve({'pathwayId': pathwayId});
        expect(proposal['clinicianReviewConfirmed'], isFalse);
        final before = await snapshot(proposal);
        await expectLater(
          apply(proposal, before),
          throwsA(
            _failure(NutritionPathwayActivationFailure.clinicianReviewRequired),
          ),
        );
        expect(await values(), isEmpty);
      }
      final reviewed = await resolve({
        'pathwayId': 'keto',
        'clinicianReviewConfirmed': true,
      });
      await apply(reviewed, await snapshot(reviewed));
      expect(await repository.readActivePathway(), 'keto');
    },
  );

  test('hidden and malformed pathways never inherit another plan', () async {
    for (final pathwayId in const [
      'psmf',
      'unknown',
      ' carb-cycling',
      'KETO',
    ]) {
      await expectLater(
        resolve({'pathwayId': pathwayId, 'clinicianReviewConfirmed': true}),
        throwsArgumentError,
      );
      await expectLater(
        adapter.preview(pathwayId: pathwayId, checkAccess: _allowed),
        throwsArgumentError,
      );
    }
    await expectLater(
      resolve({'pathwayId': 'keto', 'clinicianReviewConfirmed': 'true'}),
      throwsArgumentError,
    );
    await expectLater(
      resolve({'pathwayId': 'carb-cycling', 'calories': 500}),
      throwsArgumentError,
    );
    expect(await values(), isEmpty);
    expect(subscriptionCalls, 0);
  });

  test(
    'changed draft invalidates accepted proposal before activation',
    () async {
      final proposal = await resolve();
      final before = await snapshot(proposal);
      await repository.saveDraft(_personalDraft('carb-cycling'));
      final externallyEdited = await values();
      await expectLater(apply(proposal, before), throwsStateError);
      expect(await values(), externallyEdited);
      expect(await repository.readActivePathway(), isNull);
    },
  );

  test(
    'draft changed between resolve and snapshot cannot replace the frozen draft',
    () async {
      final proposal = await resolve();
      await repository.saveDraft(_personalDraft('carb-cycling'));
      final before = await snapshot(proposal);
      await expectLater(apply(proposal, before), throwsStateError);
      expect(await repository.readActivePathway(), isNull);
      expect((await repository.read('carb-cycling')).calories, 1750);
    },
  );

  test(
    'changed meal schedule makes activation stale without overwriting it',
    () async {
      final proposal = await resolve();
      final before = await snapshot(proposal);
      await schedule.saveMeal(
        'dinner',
        const NutritionGoalTarget(
          calories: 650,
          carbsPercent: 40,
          proteinPercent: 30,
          fatPercent: 30,
        ),
      );
      final externallyEdited = await values();
      await expectLater(apply(proposal, before), throwsStateError);
      expect(await values(), externallyEdited);
      expect(await repository.readActivePathway(), isNull);
    },
  );

  test(
    'Undo from an empty state removes active plan, draft, and schedule',
    () async {
      await preferences.set('unrelated.setting', 'retained');
      final initialValues = await values();
      final proposal = await resolve();
      final before = await snapshot(proposal);
      await apply(proposal, before);
      final after = await snapshot(proposal);
      await database.transaction(
        () => adapter.compensate(
          resolved: proposal,
          before: before,
          after: after,
          checkAccess: _allowed,
        ),
      );
      expect(await values(), initialValues);
      expect(await repository.readActivePathway(), isNull);
      expect((await schedule.read()).dayTargets, isEmpty);
    },
  );

  test(
    'Undo restores previous plan, exact saved draft, and meal schedule',
    () async {
      final initial = await resolve();
      await apply(initial, await snapshot(initial));
      await repository.saveDraft(_personalDraft('high-protein'));
      await schedule.saveMeal(
        'lunch',
        const NutritionGoalTarget(
          calories: 700,
          carbsPercent: 45,
          proteinPercent: 30,
          fatPercent: 25,
        ),
      );
      final initialValues = await values();
      final proposal = await resolve({'pathwayId': 'high-protein'});
      final before = await snapshot(proposal);
      await apply(proposal, before);
      final after = await snapshot(proposal);
      await database.transaction(
        () => adapter.compensate(
          resolved: proposal,
          before: before,
          after: after,
          checkAccess: _allowed,
        ),
      );
      expect(await values(), initialValues);
      expect(await repository.readActivePathway(), 'carb-cycling');
      expect((await repository.read('high-protein')).calories, 1750);
      expect((await schedule.read()).mealTargets['lunch']!.calories, 700);
    },
  );

  test('Undo refuses to replace a later independent schedule edit', () async {
    final proposal = await resolve();
    final before = await snapshot(proposal);
    await apply(proposal, before);
    final after = await snapshot(proposal);
    await schedule.saveDay(
      2,
      const NutritionGoalTarget(
        calories: 1850,
        carbsPercent: 40,
        proteinPercent: 30,
        fatPercent: 30,
      ),
    );
    final changedValues = await values();
    await expectLater(
      database.transaction(
        () => adapter.compensate(
          resolved: proposal,
          before: before,
          after: after,
          checkAccess: _allowed,
        ),
      ),
      throwsStateError,
    );
    expect(await values(), changedValues);
  });

  test('a silent activation cannot produce a saved receipt', () async {
    final silent = _SilentPlanRepository(
      preferences: preferences,
      schedule: schedule,
    );
    adapter = CoachPlanCommandAdapter(
      database: database,
      command: DietPlanCommand(
        repository: silent,
        verifiedSubscription: () async => _premium(),
      ),
    );
    final proposal = await resolve();
    await expectLater(
      apply(proposal, await snapshot(proposal)),
      throwsStateError,
    );
    expect(await values(), isEmpty);
  });

  test('revocation during entitlement loading prevents mutation', () async {
    final entered = Completer<void>();
    final grant = Completer<SubscriptionState>();
    subscription = () {
      entered.complete();
      return grant.future;
    };
    final proposal = await resolve({'pathwayId': 'high-protein'});
    final before = await snapshot(proposal);
    var current = true;
    final future = database.transaction(
      () => adapter.apply(
        resolved: proposal,
        before: before,
        checkAccess: () {
          if (!current) throw StateError('Owner epoch revoked');
        },
      ),
    );
    await entered.future;
    current = false;
    grant.complete(_premium());
    await expectLater(future, throwsStateError);
    expect(await values(), isEmpty);
    expect(await repository.readActivePathway(), isNull);
  });

  test(
    'snapshot and proposal stay stable and immutable without state changes',
    () async {
      final proposal = await resolve();
      final first = await snapshot(proposal);
      expect(await snapshot(proposal), first);
      expect(() => proposal['pathwayId'] = 'keto', throwsUnsupportedError);
      expect(
        () => (first['receipt'] as Map)['active'] = true,
        throwsUnsupportedError,
      );
      expect(await values(), isEmpty);
    },
  );
}

void _allowed() {}

DietDraft _personalDraft(String pathwayId) => DietDraft(
  pathwayId: pathwayId,
  calories: 1750,
  fatLevel: DietFatLevel.medium,
  carbsByWeekday: uniformWeeklyCarbs(100),
);

SubscriptionState _premium() => SubscriptionState(
  plan: CommercePlan.premium,
  entitlements: const {CommerceEntitlement.premiumPrograms},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: true,
);

Matcher _failure(NutritionPathwayActivationFailure expected) =>
    isA<NutritionPathwayActivationException>().having(
      (error) => error.failure,
      'failure',
      expected,
    );

class _SilentPlanRepository extends DietPlanRepository {
  _SilentPlanRepository({required super.preferences, required super.schedule});

  @override
  Future<void> activate(
    DietDraft draft, {
    required NutritionPathwayActivationAuthorization authorization,
  }) async {}
}
