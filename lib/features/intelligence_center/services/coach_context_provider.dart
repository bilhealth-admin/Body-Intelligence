import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../data/repositories/experiment_repository.dart';
import '../../../data/database/database_provider.dart';
import '../../../engine/body_profile.dart';
import '../../../engine/plan_engine.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../daily_log/domain/daily_body_context_codec.dart';
import '../../connected_health/connected_health_model.dart';
import '../../connected_health/providers/connected_health_provider.dart';
import '../../foods/providers/food_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../../ai_platform/providers/product_intelligence_provider.dart';
import '../../life_context/providers/life_context_provider.dart';
import '../../exercise_calorie_controls/domain/exercise_calorie_policy.dart';
import '../../exercise_calorie_controls/providers/exercise_calorie_providers.dart';
import '../../wellness/domain/fasting_session.dart';
import '../domain/coach_context_snapshot.dart';
import '../domain/coach_context_preferences.dart';
import '../domain/coach_nutrition_goal_resolver.dart';
import '../../onboarding/domain/onboarding_goal_bindings.dart';
import '../../nutrition/domain/macro_gram_goals.dart';
import '../../nutrition/domain/percentage_nutrition_goals.dart';
import '../../nutrition/domain/dietary_preferences.dart';
import 'coach_health_tools.dart';

part 'coach_context_assembly.dart';

// A voice turn starts reading this snapshot only after recording has stopped.
// Keep the provider alive while its asynchronous repository reads complete;
// `ref.read(provider.future)` does not install a widget subscription and an
// auto-disposed provider can otherwise dispose its own Ref mid-build.
// Mutations that affect Coach context explicitly invalidate this snapshot.
final coachContextSnapshotProvider = FutureProvider<CoachContextSnapshot>((
  ref,
) async {
  // Rebuild cached Coach context whenever either structured context source
  // changes. Repository reads below remain best-effort and failure tolerant.
  ref.watch(latestDailyLogProvider);
  ref.watch(insightLifeContextProvider);
  final connectedHealth = ref.watch(connectedHealthProvider).value;
  final preferences = ref.read(preferencesRepositoryProvider);

  // Start independent repository reads together. They used to run one after
  // another, so a few healthy four-second guards could make one Coach turn
  // feel hung even though no source depended on the previous source.
  final profileFuture = (() async {
    try {
      return await ref.read(userProfileRepositoryProvider).getProfile();
    } on Object {
      return null;
    }
  })();
  final canonicalOutputFuture = (() async {
    try {
      return await ref
          .read(productIntelligenceOutputProvider.future)
          .timeout(const Duration(seconds: 6));
    } on Object {
      return null;
    }
  })();
  final decisionMemoriesFuture = (() async {
    try {
      return await ref
          .read(decisionMemoryRepositoryProvider)
          .watchAll()
          .first
          .timeout(const Duration(seconds: 4));
    } on Object {
      return <DecisionMemory>[];
    }
  })();
  final weightsFuture = (() async {
    try {
      return await ref.read(weightRepositoryProvider).getAll();
    } on Object {
      return <WeightEntry>[];
    }
  })();
  final latestBodyMeasurementFuture = (() async {
    try {
      return await ref.read(bodyMeasurementRepositoryProvider).getLatest();
    } on Object {
      return null;
    }
  })();
  final mealsFuture = (() async {
    try {
      return await ref
          .read(mealRepositoryProvider)
          .watchAll()
          .first
          .timeout(const Duration(seconds: 4));
    } on Object {
      return <MealWithItems>[];
    }
  })();
  final waterFuture = (() async {
    try {
      return await ref
          .read(waterRepositoryProvider)
          .watchAll()
          .first
          .timeout(const Duration(seconds: 4));
    } on Object {
      return <WaterEntry>[];
    }
  })();
  final dailyLogsFuture = (() async {
    try {
      return await ref.read(dailyLogRepositoryProvider).getAll();
    } on Object {
      return <DailyLog>[];
    }
  })();
  final consentedContextsFuture = (() async {
    try {
      return await ref
          .read(lifeContextRepositoryProvider)
          .watchAllForInsights()
          .first
          .timeout(const Duration(seconds: 4));
    } on Object {
      return <LifeContextEntry>[];
    }
  })();
  final personalExperimentsFuture = (() async {
    try {
      return await ExperimentRepository(
        ref.read(databaseProvider),
      ).watchAll().first.timeout(const Duration(seconds: 4));
    } on Object {
      return <PersonalExperiment>[];
    }
  })();
  final dietaryPreferencesFuture = (() async {
    try {
      return await ref.read(dietaryPreferencesRepositoryProvider).read();
    } on Object {
      return const DietaryPreferences();
    }
  })();
  final displayNameFuture = preferences.get('displayName');
  final onboardingGoalsFuture = preferences.get(
    OnboardingGoalBindings.storageKey,
  );
  final coachContextPreferencesFuture = preferences.get(
    CoachContextPreferences.storageKey,
  );
  final explicitMemoriesFuture = (() async {
    try {
      final raw = await preferences.get('coachExplicitMemoriesV1');
      if (raw == null || raw.trim().isEmpty) {
        return <Map<String, Object?>>[];
      }
      return (jsonDecode(raw) as List<Object?>)
          .whereType<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .where(
            (item) =>
                item['source'] == 'explicit_user_confirmation' &&
                item['text']?.toString().trim().isNotEmpty == true,
          )
          .take(20)
          .toList(growable: false);
    } on Object {
      return <Map<String, Object?>>[];
    }
  })();
  final goalScheduleFuture = ref
      .read(nutritionGoalScheduleRepositoryProvider)
      .read();
  Future<double> storedNumber(String key) async =>
      double.tryParse(await preferences.get(key) ?? '') ?? 0;
  final caloriesGoalFuture = storedNumber('goal.calories');
  final carbsPercentFuture = storedNumber('goal.carbsPercent');
  final proteinPercentFuture = storedNumber('goal.proteinPercent');
  final fatPercentFuture = storedNumber('goal.fatPercent');
  final proteinGramsFuture = storedNumber('goal.proteinGrams');
  final carbsGramsFuture = storedNumber('goal.carbsGrams');
  final fatGramsFuture = storedNumber('goal.fatGrams');
  final exerciseIncludedFuture = preferences.get(
    exerciseCaloriesIncludedPreferenceKey,
  );
  final exerciseMacrosFuture = preferences.get(
    exerciseMacrosAdjustedPreferenceKey,
  );
  final fastingFuture = preferences.get('wellness_fasting_session_v2');

  final profile = await profileFuture;
  final plan = profile == null
      ? null
      : await (() async {
          try {
            return await ref
                .read(planRepositoryProvider)
                .getForProfile(profile.uuid);
          } on Object {
            return null;
          }
        })();
  final canonicalOutput = await canonicalOutputFuture;
  final decisionMemories = await decisionMemoriesFuture;
  final weights = await weightsFuture;
  final latestBodyMeasurement = await latestBodyMeasurementFuture;
  final meals = await mealsFuture;
  final water = await waterFuture;
  final dailyLogs = await dailyLogsFuture;
  final consentedContexts = await consentedContextsFuture;
  final personalExperiments = await personalExperimentsFuture;
  final dietaryPreferences = await dietaryPreferencesFuture;
  final displayName = (await displayNameFuture)?.trim();
  final onboardingGoals = OnboardingGoalBindings.decode(
    await onboardingGoalsFuture,
  );
  final coachContextPreferences = CoachContextPreferences.decode(
    await coachContextPreferencesFuture,
  );
  final explicitMemories = await explicitMemoriesFuture;
  final goalSchedule = await goalScheduleFuture;
  dailyLogs.sort((left, right) => right.date.compareTo(left.date));
  final percentageGoals = PercentageNutritionGoals.resolve(
    calories: await caloriesGoalFuture,
    carbohydratesPercent: await carbsPercentFuture,
    proteinPercent: await proteinPercentFuture,
    fatPercent: await fatPercentFuture,
  );
  double? validGram(double value) => value > 0 && value <= 1000 ? value : null;
  final gramGoals = MacroGramGoals(
    protein: validGram(await proteinGramsFuture),
    carbohydrates: validGram(await carbsGramsFuture),
    fat: validGram(await fatGramsFuture),
  );
  final exercisePreferences = ExerciseCaloriePreferences(
    includeInRemainingGoal: await exerciseIncludedFuture == 'true',
    adjustMacroGoals: await exerciseMacrosFuture == 'true',
  );
  final activeFast = FastingSession.tryParse(await fastingFuture);

  final nutrition = _coachNutritionDays(meals);

  final latestWeightKg = weights.isEmpty
      ? profile?.currentWeight
      : weights.first.weight;
  final latestWaistCm = latestBodyMeasurement?.waistCm ?? profile?.waist;
  final latestNeckCm = latestBodyMeasurement?.neckCm ?? profile?.neck;
  final latestHipCm = latestBodyMeasurement?.hipsCm;
  final inferredGoalType = profile == null || latestWeightKg == null
      ? 'maintain'
      : profile.targetWeight < latestWeightKg
      ? 'lose'
      : profile.targetWeight > latestWeightKg
      ? 'gain'
      : 'maintain';
  final recommendation = profile == null || latestWeightKg == null
      ? null
      : PlanEngine.recommend(
          BodyProfile(
            age: profile.age,
            gender: profile.gender,
            height: profile.height,
            weight: latestWeightKg,
            targetWeight: profile.targetWeight,
            activityLevel: profile.activityLevel,
            exercises: profile.exercises,
            goalType: inferredGoalType,
            waistCm: latestWaistCm,
            neckCm: latestNeckCm,
            hipCm: latestHipCm,
          ),
          dietaryPreferences: dietaryPreferences,
        );
  double targetNumber(num? value) => value?.toDouble() ?? 0;
  String fallbackSource(num? override, num? recommended) => override != null
      ? 'saved_plan_override'
      : recommended != null
      ? 'saved_plan_recommendation'
      : 'body_profile_calculation';
  final hasSavedGoalContext =
      goalSchedule.targetFor(DateTime.now()) != null ||
      percentageGoals != null ||
      gramGoals.protein != null ||
      gramGoals.carbohydrates != null ||
      gramGoals.fat != null;
  final hasTargetContext = recommendation != null || hasSavedGoalContext;
  final targetResolution = hasTargetContext
      ? CoachNutritionGoalResolver.resolveWithSources(
          localDay: DateTime.now(),
          schedule: goalSchedule,
          percentageGoals: percentageGoals,
          gramGoals: gramGoals,
          fallback: <String, double>{
            'caloriesKcal': targetNumber(
              plan?.overrideCalories ??
                  plan?.recommendedCalories ??
                  recommendation?.targets.calories,
            ),
            'proteinG': targetNumber(
              plan?.overrideProtein ??
                  plan?.recommendedProtein ??
                  recommendation?.targets.protein,
            ),
            'carbsG': targetNumber(
              plan?.overrideCarbs ??
                  plan?.recommendedCarbs ??
                  recommendation?.targets.carbs,
            ),
            'fatG': targetNumber(
              plan?.overrideFats ??
                  plan?.recommendedFats ??
                  recommendation?.targets.fats,
            ),
            'fiberG': targetNumber(
              plan?.overrideFiber ??
                  plan?.recommendedFiber ??
                  recommendation?.targets.fiber,
            ),
            'waterMl': targetNumber(
              plan?.overrideWater ??
                  plan?.recommendedWater ??
                  recommendation?.targets.water,
            ),
          },
          fallbackSources: <String, String>{
            'caloriesKcal': fallbackSource(
              plan?.overrideCalories,
              plan?.recommendedCalories,
            ),
            'proteinG': fallbackSource(
              plan?.overrideProtein,
              plan?.recommendedProtein,
            ),
            'carbsG': fallbackSource(
              plan?.overrideCarbs,
              plan?.recommendedCarbs,
            ),
            'fatG': fallbackSource(plan?.overrideFats, plan?.recommendedFats),
            'fiberG': fallbackSource(
              plan?.overrideFiber,
              plan?.recommendedFiber,
            ),
            'waterMl': fallbackSource(
              plan?.overrideWater,
              plan?.recommendedWater,
            ),
          },
        )
      : null;
  final now = DateTime.now();
  final todayKey =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  final todayNutrition = nutrition
      .where((day) => day.day == todayKey)
      .firstOrNull;
  final todayWaterMl = water
      .where((entry) {
        final local = entry.occurredAt.toLocal();
        return local.year == now.year &&
            local.month == now.month &&
            local.day == now.day;
      })
      .fold<int>(0, (sum, entry) => sum + entry.amountMl);
  final verifiedEnergy = authoritativeExerciseEnergyForDay(
    connectedHealth,
    now,
  );
  final resolvedTargets = targetResolution?.targets;
  final exerciseResult = ExerciseCaloriePolicy.calculate(
    preferences: exercisePreferences,
    day: now,
    baseCalorieGoal:
        (resolvedTargets?['caloriesKcal'] as num?)?.toDouble() ?? 0,
    consumedCalories: todayNutrition?.calories ?? 0,
    baseProteinGoal: (resolvedTargets?['proteinG'] as num?)?.toDouble() ?? 0,
    baseCarbohydrateGoal: (resolvedTargets?['carbsG'] as num?)?.toDouble() ?? 0,
    baseFatGoal: (resolvedTargets?['fatG'] as num?)?.toDouble() ?? 0,
    energy: verifiedEnergy,
  );
  final newestManualSleep = dailyLogs
      .where((log) => log.sleepHours != null)
      .firstOrNull;
  final connectedSleep = connectedHealth?.deviceVerified == true
      ? connectedHealth!.signals
            .where(
              (signal) =>
                  signal.key == 'sleep' &&
                  signal.value.isFinite &&
                  signal.value > 0 &&
                  signal.value <= 14,
            )
            .firstOrNull
      : null;
  final fastingRemaining = activeFast?.targetReachedAt.toUtc().difference(
    now.toUtc(),
  );
  final bodyContextByDay = <String, Set<String>>{};
  for (final row in consentedContexts) {
    bodyContextByDay.putIfAbsent(row.dayKey, () => <String>{}).add(row.type);
  }
  for (final row in dailyLogs) {
    bodyContextByDay
        .putIfAbsent(row.dayKey, () => <String>{})
        .addAll(DailyBodyContextCodec.engineTypes(row.notes));
  }
  bodyContextByDay.removeWhere((_, types) => types.isEmpty);
  final bodyContextHistory =
      bodyContextByDay.entries.map((entry) {
          final types = entry.value.toList()..sort();
          return <String, Object?>{'day': entry.key, 'types': types};
        }).toList()
        ..sort((left, right) => '${right['day']}'.compareTo('${left['day']}'));
  final todayBodyContext = bodyContextByDay[todayKey]?.toList() ?? <String>[];
  todayBodyContext.sort();
  final todayContext = <String, Object?>{
    'day': todayKey,
    'nutrition': <String, Object?>{
      'consumedCaloriesKcal': todayNutrition?.calories ?? 0,
      'knownTotals': todayNutrition?.knownTotals.toList() ?? const <String>[],
      'waterMl': todayWaterMl,
    },
    'exerciseEnergy': <String, Object?>{
      'baseCaloriesKcal': exerciseResult.baseCalorieGoal,
      'verifiedBurnedKcal': verifiedEnergy?.kcal ?? 0,
      'burnSource': verifiedEnergy?.source ?? 'not_available',
      'burnObservedAt': verifiedEnergy?.observedAt.toUtc().toIso8601String(),
      'includedInRemaining': exercisePreferences.includeInRemainingGoal,
      'effectiveCalorieGoalKcal': exerciseResult.effectiveCalorieGoal,
      'netCaloriesKcal':
          (todayNutrition?.calories ?? 0) - (verifiedEnergy?.kcal ?? 0),
      'remainingCaloriesKcal': exerciseResult.remainingCalories,
      'manualExerciseChangesAllowance': false,
    },
    'sleep': connectedSleep != null
        ? <String, Object?>{
            'hours': connectedSleep.value,
            'source': 'connected_health',
            'deviceSource': connectedSleep.source,
            'observedAt': connectedSleep.observedAt.toUtc().toIso8601String(),
            'lastSyncAt': connectedHealth?.lastSyncAt
                ?.toUtc()
                .toIso8601String(),
          }
        : newestManualSleep == null
        ? const <String, Object?>{'status': 'not_recorded'}
        : <String, Object?>{
            'hours': newestManualSleep.sleepHours,
            'source': 'manual',
            'observedAt': newestManualSleep.date.toUtc().toIso8601String(),
          },
    'fasting': activeFast == null
        ? const <String, Object?>{'status': 'inactive'}
        : <String, Object?>{
            'status': fastingRemaining!.isNegative
                ? 'target_reached'
                : 'active',
            'startedAt': activeFast.startedAt.toUtc().toIso8601String(),
            'targetAt': activeFast.targetReachedAt.toUtc().toIso8601String(),
            'remainingMinutes': fastingRemaining.isNegative
                ? 0
                : fastingRemaining.inMinutes,
          },
    'bodyContext': <String, Object?>{'types': todayBodyContext},
  };
  final health = profile == null
      ? <String, Object?>{
          'status': 'profile_missing',
          'today': todayContext,
          if (targetResolution != null) ...{
            'dailyTargets': targetResolution.targets,
            'dailyTargetSources': targetResolution.sources,
          },
        }
      : <String, Object?>{
          ...const CoachHealthTools().calculate(
            age: profile.age,
            gender: profile.gender,
            heightCm: profile.height,
            currentWeightKg: latestWeightKg!,
            targetWeightKg: profile.targetWeight,
            activityLevel: profile.activityLevel,
            exercises: profile.exercises,
            waistCm: latestWaistCm,
            neckCm: latestNeckCm,
            hipCm: latestHipCm,
          ),
          'today': todayContext,
          if (targetResolution != null) ...{
            'dailyTargets': targetResolution.targets,
            'dailyTargetSources': targetResolution.sources,
            'mealTargets': CoachNutritionGoalResolver.mealTargets(goalSchedule),
          },
        };
  final activityHistory = _coachActivityHistory(dailyLogs, connectedHealth);

  final includeNutrition = coachContextPreferences.includes(
    CoachContextFocus.nutrition,
  );
  final includeTraining = coachContextPreferences.includes(
    CoachContextFocus.training,
  );
  final includeHabits = coachContextPreferences.includes(
    CoachContextFocus.habits,
  );
  final includeAnalytics = coachContextPreferences.includes(
    CoachContextFocus.analytics,
  );
  final selectedGoalNames =
      onboardingGoals.map((goal) => goal.name).toList(growable: false)..sort();
  final selectedGoalConsumers =
      onboardingGoals
          .expand(
            (goal) =>
                OnboardingGoalBindings.consumers[goal] ??
                const <OnboardingGoalConsumer>{},
          )
          .map((consumer) => consumer.name)
          .toSet()
          .toList(growable: false)
        ..sort();
  final scopedHealth = _scopeCoachHealth(
    health: health,
    includeNutrition: includeNutrition,
    includeTraining: includeTraining,
    includeHabits: includeHabits,
    includeAnalytics: includeAnalytics,
  );

  return CoachContextSnapshot(
    generatedAt: DateTime.now(),
    profile: profile == null
        ? <String, Object?>{
            'selectedGoals': selectedGoalNames,
            'goalConsumers': selectedGoalConsumers,
            if (includeNutrition)
              'dietaryPreferences': dietaryPreferences.toCoachContext(),
          }
        : {
            if (displayName != null && displayName.isNotEmpty)
              'displayName': displayName,
            'selectedGoals': selectedGoalNames,
            'goalConsumers': selectedGoalConsumers,
            if (includeNutrition || includeTraining || includeAnalytics) ...{
              'age': profile.age,
              'gender': profile.gender,
              'heightCm': profile.height,
              'currentWeightKg': latestWeightKg,
              'targetWeightKg': profile.targetWeight,
            },
            if (includeTraining) ...{
              'activityLevel': profile.activityLevel,
              'exercises': profile.exercises,
            },
            if (includeAnalytics) ...{
              'waistCm': latestWaistCm,
              'neckCm': latestNeckCm,
              'hipCm': latestHipCm,
              'chestCm': profile.chest,
              'armCm': profile.arm,
              'thighCm': profile.thigh,
            },
            if (includeNutrition)
              'dietaryPreferences': dietaryPreferences.toCoachContext(),
          },
    weights: !includeAnalytics
        ? const <CoachWeightPoint>[]
        : weights
              .map(
                (item) => CoachWeightPoint(
                  at: item.date,
                  kg: item.weight,
                  measurementContext: item.measurementContext,
                ),
              )
              .toList(growable: false),
    nutritionDays: includeNutrition ? nutrition : const <CoachNutritionDay>[],
    waterHistory: !includeNutrition
        ? const <Map<String, Object?>>[]
        : water
              .map(
                (item) => <String, Object?>{
                  'at': item.occurredAt.toUtc().toIso8601String(),
                  'amountMl': item.amountMl,
                },
              )
              .toList(growable: false),
    computedHealth: scopedHealth,
    canonicalIntelligence: !includeAnalytics || canonicalOutput == null
        ? const <String, Object?>{'status': 'unavailable', 'canPresent': false}
        : <String, Object?>{
            'status': canonicalOutput.brainResult.status.name,
            'canPresent': canonicalOutput.canPresent,
            'primaryMessage': canonicalOutput.primaryMessage,
            'explanation': canonicalOutput.explanation.take(6).toList(),
            'confidence': canonicalOutput.brainResult.confidence,
            'evidenceIds': canonicalOutput.brainResult.evidenceIds
                .take(12)
                .toList(),
            'missingData': canonicalOutput.brainResult.reconciliationIssues
                .take(8)
                .toList(),
            'bodyTwin': <String, Object?>{
              'status': canonicalOutput.bodyTwinResult.status.name,
              'canProceed': canonicalOutput.bodyTwinResult.canProceed,
              'integrityIssues': canonicalOutput.bodyTwinResult.integrityIssues
                  .take(8)
                  .toList(),
            },
            'adaptiveTdeeKcal': canonicalOutput.adaptiveTdeeKcal,
            'plateauRisk': canonicalOutput.plateauRisk,
            'physiologicalNoise': <String, Object?>{
              'observedScaleChangeKg':
                  canonicalOutput.noiseEstimate.observedScaleChangeKg,
              'estimatedTissueChangeKg':
                  canonicalOutput.noiseEstimate.estimatedTissueChangeKg,
              'waterAndGlycogenNoiseKg':
                  canonicalOutput.noiseEstimate.waterAndGlycogenNoiseKg,
              'confidence': canonicalOutput.noiseEstimate.confidence,
            },
            'forecast': canonicalOutput.forecast
                .take(4)
                .map(
                  (point) => <String, Object?>{
                    'days': point.days,
                    'projectedWeightKg': point.projectedWeightKg,
                    'projectedTissueChangeKg': point.projectedTissueChangeKg,
                    'confidence': point.confidence,
                  },
                )
                .toList(growable: false),
            if (canonicalOutput.brainResult.selectedAction case final action?)
              'oneBestAction': <String, Object?>{
                'id': action.id,
                'title': action.title,
                'rationale': action.rationale,
                'confidence': action.confidence,
                'expectedBenefit': action.expectedBenefit,
                'burden': action.burden,
                'evidenceIds': action.evidenceIds.take(8).toList(),
              },
          },
    decisionMemory: !includeAnalytics
        ? const <Map<String, Object?>>[]
        : decisionMemories
              .take(10)
              .map(
                (memory) => <String, Object?>{
                  'recommendationKey': memory.recommendationKey,
                  'title': memory.title,
                  'reason': memory.reason,
                  'confidence': memory.confidence,
                  'response': memory.response,
                  if (memory.outcome != null) 'outcome': memory.outcome,
                  if (memory.helpfulness != null)
                    'helpfulness': memory.helpfulness,
                  'surfacedAt': memory.surfacedAt.toUtc().toIso8601String(),
                },
              )
              .toList(growable: false),
    explicitMemories: explicitMemories,
    activityHistory: includeTraining || includeHabits
        ? activityHistory.take(14).toList(growable: false)
        : const <Map<String, Object?>>[],
    bodyContextHistory: includeHabits
        ? bodyContextHistory.take(42).toList(growable: false)
        : const <Map<String, Object?>>[],
    personalExperiments: !includeAnalytics
        ? const <Map<String, Object?>>[]
        : personalExperiments
              .take(6)
              .map(
                (experiment) => <String, Object?>{
                  'id': experiment.uuid,
                  'hypothesis': experiment.hypothesis,
                  'changedVariable': experiment.changedVariable,
                  'requiredData': experiment.requiredData,
                  'startedAt': experiment.startedAt.toUtc().toIso8601String(),
                  'endsAt': experiment.endsAt.toUtc().toIso8601String(),
                  'status': experiment.status,
                  if (experiment.adherence != null)
                    'adherence': experiment.adherence,
                  if (experiment.result != null) 'result': experiment.result,
                  'confidence': experiment.confidence,
                  'limitations': experiment.limitations,
                },
              )
              .toList(growable: false),
  );
});
