import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../engine/body_profile.dart';
import '../../../engine/plan_engine.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../foods/providers/food_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../domain/coach_context_snapshot.dart';
import '../domain/coach_nutrition_goal_resolver.dart';
import '../../nutrition/domain/macro_gram_goals.dart';
import '../../nutrition/domain/percentage_nutrition_goals.dart';
import 'coach_health_tools.dart';

final coachContextSnapshotProvider =
    FutureProvider.autoDispose<CoachContextSnapshot>((ref) async {
      final profile = await (() async {
        try {
          return await ref.read(userProfileRepositoryProvider).getProfile();
        } on Object {
          return null;
        }
      })();
      final weights = await (() async {
        try {
          return await ref.read(weightRepositoryProvider).getAll();
        } on Object {
          return <WeightEntry>[];
        }
      })();
      final meals = await (() async {
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
      final water = await (() async {
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
      final preferences = ref.read(preferencesRepositoryProvider);
      final displayName = (await preferences.get('displayName'))?.trim();
      final goalSchedule = await ref
          .read(nutritionGoalScheduleRepositoryProvider)
          .read();
      Future<double> storedNumber(String key) async =>
          double.tryParse(await preferences.get(key) ?? '') ?? 0;
      final percentageGoals = PercentageNutritionGoals.resolve(
        calories: await storedNumber('goal.calories'),
        carbohydratesPercent: await storedNumber('goal.carbsPercent'),
        proteinPercent: await storedNumber('goal.proteinPercent'),
        fatPercent: await storedNumber('goal.fatPercent'),
      );
      double? validGram(double value) =>
          value > 0 && value <= 1000 ? value : null;
      final gramGoals = MacroGramGoals(
        protein: validGram(await storedNumber('goal.proteinGrams')),
        carbohydrates: validGram(await storedNumber('goal.carbsGrams')),
        fat: validGram(await storedNumber('goal.fatGrams')),
      );

      final byDay = <String, List<MealWithItems>>{};
      for (final meal in meals) {
        final date = meal.meal.date;
        final day =
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
        byDay.putIfAbsent(day, () => []).add(meal);
      }
      final nutrition = <CoachNutritionDay>[];
      for (final entry in byDay.entries) {
        var calories = 0.0;
        var protein = 0.0;
        var carbs = 0.0;
        var fat = 0.0;
        var sodium = 0.0;
        final mealJson = <Map<String, Object?>>[];
        for (final meal in entry.value) {
          final items = <Map<String, Object?>>[];
          for (final item in meal.items) {
            calories += item.calories;
            protein += item.protein;
            carbs += item.carbs;
            fat += item.fats;
            sodium += item.sodium;
            items.add({
              'itemId': item.id,
              'food': meal.foodsById[item.foodId]?.name ?? 'historical-food',
              'quantity': item.quantity,
              'caloriesKcal': item.calories,
              'proteinG': item.protein,
              'carbsG': item.carbs,
              'fatG': item.fats,
              'sodiumMg': item.sodium,
            });
          }
          mealJson.add({
            'type': meal.meal.type,
            'name': meal.meal.name,
            'items': items,
          });
        }
        nutrition.add(
          CoachNutritionDay(
            day: entry.key,
            meals: mealJson,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            sodium: sodium,
          ),
        );
      }
      nutrition.sort((a, b) => b.day.compareTo(a.day));

      final latestWeightKg = weights.isEmpty
          ? profile?.currentWeight
          : weights.first.weight;
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
              ),
            );
      double targetNumber(num value) => value.toDouble();
      final health = profile == null
          ? const <String, Object?>{'status': 'profile_missing'}
          : <String, Object?>{
              ...const CoachHealthTools().calculate(
                age: profile.age,
                gender: profile.gender,
                heightCm: profile.height,
                currentWeightKg: profile.currentWeight,
                targetWeightKg: profile.targetWeight,
                activityLevel: profile.activityLevel,
                exercises: profile.exercises,
                waistCm: profile.waist,
              ),
              if (recommendation != null) ...{
                'dailyTargets': CoachNutritionGoalResolver.resolve(
                  localDay: DateTime.now(),
                  schedule: goalSchedule,
                  percentageGoals: percentageGoals,
                  gramGoals: gramGoals,
                  fallback: <String, double>{
                    'caloriesKcal': targetNumber(
                      plan?.overrideCalories ??
                          plan?.recommendedCalories ??
                          recommendation.targets.calories,
                    ),
                    'proteinG': targetNumber(
                      plan?.overrideProtein ??
                          plan?.recommendedProtein ??
                          recommendation.targets.protein,
                    ),
                    'carbsG': targetNumber(
                      plan?.overrideCarbs ??
                          plan?.recommendedCarbs ??
                          recommendation.targets.carbs,
                    ),
                    'fatG': targetNumber(
                      plan?.overrideFats ??
                          plan?.recommendedFats ??
                          recommendation.targets.fats,
                    ),
                    'fiberG': targetNumber(
                      plan?.overrideFiber ??
                          plan?.recommendedFiber ??
                          recommendation.targets.fiber,
                    ),
                    'waterMl': targetNumber(
                      plan?.overrideWater ??
                          plan?.recommendedWater ??
                          recommendation.targets.water,
                    ),
                  },
                ),
                'mealTargets': CoachNutritionGoalResolver.mealTargets(
                  goalSchedule,
                ),
              },
            };
      return CoachContextSnapshot(
        generatedAt: DateTime.now(),
        profile: profile == null
            ? const <String, Object?>{}
            : {
                if (displayName != null && displayName.isNotEmpty)
                  'displayName': displayName,
                'age': profile.age,
                'gender': profile.gender,
                'heightCm': profile.height,
                'currentWeightKg': profile.currentWeight,
                'targetWeightKg': profile.targetWeight,
                'activityLevel': profile.activityLevel,
                'exercises': profile.exercises,
                'waistCm': profile.waist,
                'neckCm': profile.neck,
                'chestCm': profile.chest,
                'armCm': profile.arm,
                'thighCm': profile.thigh,
              },
        weights: weights
            .map((item) => CoachWeightPoint(at: item.date, kg: item.weight))
            .toList(growable: false),
        nutritionDays: nutrition,
        waterHistory: water
            .map(
              (item) => <String, Object?>{
                'at': item.occurredAt.toUtc().toIso8601String(),
                'amountMl': item.amountMl,
              },
            )
            .toList(growable: false),
        computedHealth: health,
      );
    });
