import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/nutrition_plans/data/diet_plan_repository.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/diet_macro_plan.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway_catalog.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_nutrition_goal_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PreferencesRepository preferences;
  late NutritionGoalScheduleRepository schedule;
  late DietPlanRepository repository;
  late DietPlanCommand command;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    preferences = PreferencesRepository(database);
    schedule = NutritionGoalScheduleRepository(preferences);
    repository = DietPlanRepository(
      preferences: preferences,
      schedule: schedule,
    );
    command = DietPlanCommand(
      repository: repository,
      verifiedSubscription: () async => _verifiedPremium(),
    );
  });

  tearDown(() => database.close());

  test('activates seven day targets and preserves meal targets', () async {
    const breakfast = NutritionGoalTarget(
      calories: 500,
      carbsPercent: 40,
      proteinPercent: 35,
      fatPercent: 25,
    );
    await schedule.saveMeal('breakfast', breakfast);
    final draft = dietPresets['carb-cycling']!.toDraft();

    await command.activate(draft);

    final stored = await repository.read('carb-cycling');
    final goals = await schedule.read();
    expect(stored.carbsByWeekday[DateTime.monday], 20);
    expect(stored.carbsByWeekday[DateTime.sunday], 200);
    expect(goals.dayTargets, hasLength(7));
    expect(goals.dayTargets[DateTime.monday]!.calories, 2000);
    expect(goals.dayTargets[DateTime.sunday]!.calories, 2000);
    expect(goals.mealTargets['breakfast']?.proteinPercent, 35);
    expect(
      await preferences.get(DietPlanRepository.activePathwayKey),
      'carb-cycling',
    );
  });

  test(
    'persists an exact 1000 kcal user macro split for every engine',
    () async {
      final base = DietMacroAllocator.allocate(
        calories: 1000,
        carbsGrams: 100,
        fatLevel: DietFatLevel.medium,
      )!;
      final edited = DietMacroAllocator.rebalance(
        current: base,
        edited: DietMacroComponent.protein,
        grams: 110,
        fallbackFatLevel: DietFatLevel.medium,
      )!;
      final draft = DietDraft(
        pathwayId: 'carb-cycling',
        calories: 1000,
        fatLevel: DietFatLevel.medium,
        carbsByWeekday: {
          for (var day = 1; day <= 7; day += 1) day: edited.carbsGrams,
        },
        proteinByWeekday: {
          for (var day = 1; day <= 7; day += 1) day: edited.proteinGrams,
        },
        fatByWeekday: {
          for (var day = 1; day <= 7; day += 1) day: edited.fatGrams,
        },
      );

      await command.activate(draft);

      final stored = await repository.read('carb-cycling');
      final target = (await schedule.read()).dayTargets[DateTime.monday]!;
      expect(stored.proteinByWeekday[DateTime.monday], 110);
      expect(target.calories, 1000);
      expect(
        target.carbsPercent + target.proteinPercent + target.fatPercent,
        closeTo(100, .000001),
      );
      final coach = CoachNutritionGoalResolver.resolveWithSources(
        localDay: DateTime(2026, 8, 24),
        fallback: const {},
        schedule: await schedule.read(),
      );
      expect(coach.targets['caloriesKcal'], 1000);
      expect(coach.targets['proteinG'], closeTo(110, .001));
    },
  );

  test('draft save does not activate or mutate target schedule', () async {
    final draft = dietPresets['mediterranean']!.toDraft();
    await repository.saveDraft(draft);

    expect((await repository.read('mediterranean')).pathwayId, 'mediterranean');
    expect((await schedule.read()).dayTargets, isEmpty);
    expect(await preferences.get(DietPlanRepository.activePathwayKey), isNull);
  });

  test('draft persistence rejects macro energy that misses calories', () async {
    final invalid = DietDraft(
      pathwayId: 'carb-cycling',
      calories: 1000,
      fatLevel: DietFatLevel.medium,
      carbsByWeekday: const {
        1: 100,
        2: 100,
        3: 100,
        4: 100,
        5: 100,
        6: 100,
        7: 100,
      },
      proteinByWeekday: const {
        1: 100,
        2: 100,
        3: 100,
        4: 100,
        5: 100,
        6: 100,
        7: 100,
      },
      fatByWeekday: const {
        1: 100,
        2: 100,
        3: 100,
        4: 100,
        5: 100,
        6: 100,
        7: 100,
      },
    );

    await expectLater(repository.saveDraft(invalid), throwsArgumentError);
    expect(await repository.readActivePathway(), isNull);
    expect((await schedule.read()).dayTargets, isEmpty);
  });

  test('activated pathway is the same target explained by AI Coach', () async {
    final draft = dietPresets['high-protein']!.toDraft();
    await command.activate(draft);

    final goals = await schedule.read();
    final monday = DateTime(2026, 8, 24);
    final scheduled = goals.targetFor(monday)!;
    final coach = CoachNutritionGoalResolver.resolveWithSources(
      localDay: monday,
      fallback: const {
        'caloriesKcal': 999,
        'proteinG': 10,
        'carbsG': 10,
        'fatG': 10,
      },
      schedule: goals,
    );

    expect(coach.targets['caloriesKcal'], scheduled.calories);
    expect(
      coach.targets['proteinG'],
      closeTo(scheduled.calories * scheduled.proteinPercent / 400, 0.001),
    );
    expect(coach.sources['caloriesKcal'], 'scheduled_daily_goal');
    expect(coach.sources['proteinG'], 'scheduled_percentage_goal');
  });

  test(
    'reset restores one recommended target for all days atomically',
    () async {
      await command.activate(dietPresets['carb-cycling']!.toDraft());
      const recommended = NutritionGoalTarget(
        calories: 1875,
        carbsPercent: 45,
        proteinPercent: 30,
        fatPercent: 25,
      );

      await repository.resetToRecommended(recommended);

      final goals = await schedule.read();
      expect(goals.dayTargets, hasLength(7));
      expect(goals.dayTargets.values.map((target) => target.calories), {1875});
      expect(goals.dayTargets.values.map((target) => target.carbsPercent), {
        45,
      });
      expect(goals.dayTargets.values.map((target) => target.proteinPercent), {
        30,
      });
      expect(goals.dayTargets.values.map((target) => target.fatPercent), {25});
      expect(await repository.readActivePathway(), isNull);
    },
  );

  test(
    'free carb cycling never consults the paid entitlement loader',
    () async {
      var loaderCalls = 0;
      final freeCommand = DietPlanCommand(
        repository: repository,
        verifiedSubscription: () async {
          loaderCalls += 1;
          throw StateError('Free pathway must not load commerce state.');
        },
      );

      await freeCommand.activate(dietPresets['carb-cycling']!.toDraft());

      expect(loaderCalls, 0);
      expect(await repository.readActivePathway(), 'carb-cycling');
    },
  );

  test(
    'Premium activation requires both verified authority and grant',
    () async {
      final premiumDraft = dietPresets['high-protein']!.toDraft();
      final localGrantCommand = DietPlanCommand(
        repository: repository,
        verifiedSubscription: () async => _localStateWithPremiumGrant(),
      );
      final verifiedWithoutGrantCommand = DietPlanCommand(
        repository: repository,
        verifiedSubscription: () async => _verifiedFree(),
      );

      await expectLater(
        localGrantCommand.activate(premiumDraft),
        throwsA(
          _activationFailure(NutritionPathwayActivationFailure.premiumRequired),
        ),
      );
      await expectLater(
        verifiedWithoutGrantCommand.activate(premiumDraft),
        throwsA(
          _activationFailure(NutritionPathwayActivationFailure.premiumRequired),
        ),
      );

      expect(await repository.readActivePathway(), isNull);
      expect((await schedule.read()).dayTargets, isEmpty);
    },
  );

  test('verified premiumPrograms grant activates a Premium pathway', () async {
    await command.activate(dietPresets['high-protein']!.toDraft());

    expect(await repository.readActivePathway(), 'high-protein');
    expect((await schedule.read()).dayTargets, hasLength(7));
  });

  test('hidden PSMF cannot be activated even for verified Premium', () async {
    final draft = DietDraft(
      pathwayId: 'psmf',
      calories: 1600,
      fatLevel: DietFatLevel.lighter,
      carbsByWeekday: const {1: 30, 2: 30, 3: 30, 4: 30, 5: 30, 6: 30, 7: 30},
    );

    await expectLater(
      command.activate(draft),
      throwsA(
        _activationFailure(NutritionPathwayActivationFailure.unknownPathway),
      ),
    );
    expect(await repository.readActivePathway(), isNull);
  });

  test('unknown pathway never falls back to a known preset', () async {
    await expectLater(repository.read('not-a-pathway'), throwsArgumentError);
    expect(await preferences.get(DietPlanRepository.activePathwayKey), isNull);
  });

  test('hidden PSMF never inherits an editable preset fallback', () async {
    await expectLater(repository.read('psmf'), throwsArgumentError);
    expect(await repository.readActivePathway(), isNull);
  });
}

Matcher _activationFailure(NutritionPathwayActivationFailure failure) =>
    isA<NutritionPathwayActivationException>().having(
      (error) => error.failure,
      'failure',
      failure,
    );

SubscriptionState _verifiedPremium() => SubscriptionState(
  plan: CommercePlan.premium,
  entitlements: const {CommerceEntitlement.premiumPrograms},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: true,
);

SubscriptionState _verifiedFree() => SubscriptionState(
  plan: CommercePlan.free,
  entitlements: const <CommerceEntitlement>{},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: false,
);

SubscriptionState _localStateWithPremiumGrant() => SubscriptionState(
  plan: CommercePlan.free,
  entitlements: const {CommerceEntitlement.premiumPrograms},
  authority: EntitlementAuthority.localDefault,
  isPurchasable: false,
  canRestorePurchases: false,
);
