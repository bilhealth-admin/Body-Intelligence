import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database_provider.dart';
import '../../../data/database/date_keys.dart';
import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../nutrition/domain/macro_gram_goals.dart';
import '../../nutrition/domain/percentage_nutrition_goals.dart';
import '../domain/coach_nutrition_goal_resolver.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../domain/coach_context_preferences.dart';
import '../domain/coach_context_snapshot.dart';
import '../services/coach_native_command_repository.dart';
import '../presentation/intelligence_center_page.dart'
    show coachNativeOwnerWitnessProvider, intelligenceConversationClockProvider;
import 'coach_health_adapter.dart';

/// The chat's existing brief needs a bounded view, not the complete analysis
/// context. Opening chat or asking for one sleep record must not load all food,
/// water, weight, experiments, or connected-health history as a side effect.
/// Rich context remains available on an explicit overview/analysis request.
final coachHealthBriefProvider =
    FutureProvider.autoDispose<CoachContextSnapshot>((ref) async {
      final database = ref.watch(databaseProvider);
      final preferences = ref.watch(preferencesRepositoryProvider);
      final daily = ref.watch(dailyLogRepositoryProvider);
      final weights = ref.watch(weightRepositoryProvider);
      final profiles = ref.watch(userProfileRepositoryProvider);
      final schedule = ref.watch(nutritionGoalScheduleRepositoryProvider);
      final witness = ref.watch(coachNativeOwnerWitnessProvider);
      var cancelled = false;
      void check() {
        if (cancelled ||
            !ref.mounted ||
            preferences.localOwnerId != database.localOwnerId ||
            witness != null && witness.readOwner() != database.localOwnerId) {
          throw const CoachNativeConflict(
            CoachNativeConflictReason.ownerChanged,
          );
        }
      }

      final ownerChanges = witness?.changes.listen((next) {
        if (next != database.localOwnerId) cancelled = true;
      }, onError: (Object _, StackTrace _) => cancelled = true);
      // Subscriptions observe table updates only; they do not read table rows.
      final updates = database
          .tableUpdates(
            TableUpdateQuery.onAllTables([
              database.dailyLogs,
              database.weightEntries,
              database.userProfile,
              database.meals,
              database.mealItems,
              database.foods,
              database.preferences,
            ]),
          )
          .listen((_) {
            if (ref.mounted) ref.invalidateSelf();
          });
      String? allowedRaw;
      var permissionsRead = false;
      final permissionChanges = preferences
          .watch(CoachContextPreferences.storageKey)
          .listen((next) {
            if (permissionsRead && next != allowedRaw) {
              cancelled = true;
              if (ref.mounted) ref.invalidateSelf();
            }
          }, onError: (Object _, StackTrace _) => cancelled = true);
      ref.onDispose(() {
        cancelled = true;
        unawaited(ownerChanges?.cancel());
        unawaited(updates.cancel());
        unawaited(permissionChanges.cancel());
      });
      // Use the same civil clock as Coach commands. Production keeps the device
      // clock; frozen local sessions/tests cannot accidentally read tomorrow.
      final now = ref.watch(intelligenceConversationClockProvider)();
      final today = healthCivilDay(now);
      allowedRaw = await checkedHealthAwait(
        () => preferences.get(CoachContextPreferences.storageKey),
        check,
      );
      permissionsRead = true;
      final allowed = CoachContextPreferences.decode(allowedRaw);
      final weightPoints = <CoachWeightPoint>[];
      final nutrition = <CoachNutritionDay>[];
      final activity = <Map<String, Object?>>[];
      final profile = <String, Object?>{};
      final computed = <String, Object?>{};
      if (allowed.includes(CoachContextFocus.analytics) ||
          allowed.includes(CoachContextFocus.nutrition)) {
        final saved = await checkedHealthAwait(profiles.getProfile, check);
        if (saved != null) profile['profileSaved'] = true;
      }
      if (allowed.includes(CoachContextFocus.analytics)) {
        for (var offset = 0; offset < 7; offset++) {
          final day = DateTime(today.year, today.month, today.day - offset);
          final weight = await checkedHealthAwait(
            () => weights.getForDay(day),
            check,
          );
          if (weight != null &&
              weight.weight.isFinite &&
              weight.weight >= 20 &&
              weight.weight <= 500) {
            weightPoints.add(
              CoachWeightPoint(
                at: weight.date,
                kg: weight.weight,
                measurementContext: weight.measurementContext,
              ),
            );
          }
        }
      }
      if (allowed.includes(CoachContextFocus.nutrition)) {
        final ledger = await checkedHealthAwait(
          () => daily.readLedger(today),
          check,
        );
        final known = <String>{
          if (ledger.calories != null) 'caloriesKcal',
          if (ledger.protein != null) 'proteinG',
          if (ledger.carbohydrates != null) 'carbsG',
          if (ledger.fat != null) 'fatG',
        };
        if (known.isNotEmpty) {
          nutrition.add(
            CoachNutritionDay(
              day: dayKeyFor(today),
              meals: const [],
              calories: ledger.calories ?? 0,
              protein: ledger.protein ?? 0,
              carbs: ledger.carbohydrates ?? 0,
              fat: ledger.fat ?? 0,
              sodium: 0,
              knownTotals: known,
            ),
          );
        }
        final savedSchedule = await checkedHealthAwait(schedule.read, check);
        final savedGoals = <String, double>{};
        for (final key in defaultNutritionGoalPreferenceKeys) {
          final raw = await checkedHealthAwait(
            () => preferences.get(key),
            check,
          );
          final value = double.tryParse(raw ?? '');
          if (value != null && value.isFinite) savedGoals[key] = value;
        }
        final percentages = PercentageNutritionGoals.resolve(
          calories: savedGoals['goal.calories'] ?? 0,
          carbohydratesPercent: savedGoals['goal.carbsPercent'] ?? 0,
          proteinPercent: savedGoals['goal.proteinPercent'] ?? 0,
          fatPercent: savedGoals['goal.fatPercent'] ?? 0,
        );
        double? validGram(String key) {
          final value = savedGoals[key];
          return value != null && value > 0 && value <= 1000 ? value : null;
        }

        if (savedSchedule.targetFor(today) != null || percentages != null) {
          computed['dailyTargets'] = CoachNutritionGoalResolver.resolve(
            localDay: today,
            fallback: const {},
            schedule: savedSchedule,
            percentageGoals: percentages,
            gramGoals: MacroGramGoals(
              protein: validGram('goal.proteinGrams'),
              carbohydrates: validGram('goal.carbsGrams'),
              fat: validGram('goal.fatGrams'),
            ),
          );
        }
      }
      if (allowed.includes(CoachContextFocus.habits) ||
          allowed.includes(CoachContextFocus.training)) {
        final log = await checkedHealthAwait(
          () => daily.getForDay(today),
          check,
        );
        if (log != null) {
          activity.add({
            'day': dayKeyFor(today),
            if (allowed.includes(CoachContextFocus.habits) &&
                log.sleepHours != null)
              'sleepHours': log.sleepHours,
            if (allowed.includes(CoachContextFocus.training) &&
                log.steps != null)
              'steps': log.steps,
          });
        }
      }
      final finalAllowed = await checkedHealthAwait(
        () => preferences.get(CoachContextPreferences.storageKey),
        check,
      );
      if (finalAllowed != allowedRaw) {
        throw StateError('Coach brief context changed');
      }
      check();
      return CoachContextSnapshot(
        generatedAt: now,
        profile: profile,
        weights: weightPoints,
        nutritionDays: nutrition,
        waterHistory: const [],
        computedHealth: computed,
        activityHistory: activity,
      );
    });
