import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/runtime_copy.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../commerce/domain/commerce_entitlement.dart';
import '../commerce/providers/commerce_providers.dart';
import '../weight/providers/weight_provider.dart';
import '../weight/domain/weight_goal_progress.dart';

part 'reference_goals_components.dart';

@visibleForTesting
String premiumGoalDestination(bool active, String featureRoute) =>
    active ? featureRoute : '/plans';

@visibleForTesting
({String? weeklyGoal, double? startingWeight, String? startingDate})
validateStoredGoalPreferences({
  required String? weeklyGoal,
  required String? startingWeight,
  required String? startingDate,
  required DateTime now,
}) {
  final parsedWeight = double.tryParse(startingWeight ?? '');
  final dateMatch = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})$',
  ).firstMatch(startingDate ?? '');
  final year = int.tryParse(dateMatch?.group(1) ?? '');
  final month = int.tryParse(dateMatch?.group(2) ?? '');
  final day = int.tryParse(dateMatch?.group(3) ?? '');
  final parsedDate = year == null || month == null || day == null
      ? null
      : DateTime(year, month, day);
  final canonicalDate =
      parsedDate != null &&
      parsedDate.year == year &&
      parsedDate.month == month &&
      parsedDate.day == day;
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final validDate = canonicalDate && !parsedDate.isAfter(endOfToday)
      ? '${parsedDate.year.toString().padLeft(4, '0')}-'
            '${parsedDate.month.toString().padLeft(2, '0')}-'
            '${parsedDate.day.toString().padLeft(2, '0')}'
      : null;
  return (
    weeklyGoal: _weeklyOptions.contains(weeklyGoal) ? weeklyGoal : null,
    startingWeight:
        parsedWeight != null &&
            parsedWeight.isFinite &&
            parsedWeight >= 20 &&
            parsedWeight <= 500
        ? parsedWeight
        : null,
    startingDate: validDate,
  );
}

class ReferenceGoalsPage extends ConsumerStatefulWidget {
  const ReferenceGoalsPage({super.key});

  @override
  ConsumerState<ReferenceGoalsPage> createState() => _ReferenceGoalsPageState();
}

class _ReferenceGoalsPageState extends ConsumerState<ReferenceGoalsPage> {
  String? weeklyGoal;
  String? activity;
  double? startingWeight;
  String? startingDate;
  bool hydrated = false;
  bool hydrating = false;
  Object? hydrateError;
  bool saving = false;
  bool _numberEditorOpen = false;

  String c(String key) {
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode;
    final translated = _copy[key]?[language];
    return translated ??
        RuntimeCopy.resolve(key, locale.toLanguageTag()) ??
        key;
  }

  Future<void> hydrate(String profileActivity) async {
    if (hydrated || hydrating) return;
    setState(() {
      hydrating = true;
      hydrateError = null;
    });
    final repo = ref.read(preferencesRepositoryProvider);
    try {
      final values = await Future.wait([
        repo.get('goals.weeklyRate'),
        repo.get('goals.startingWeight'),
        repo.get('goals.startingDate'),
      ]);
      if (!mounted) return;
      final validated = validateStoredGoalPreferences(
        weeklyGoal: values[0],
        startingWeight: values[1],
        startingDate: values[2],
        now: DateTime.now(),
      );
      setState(() {
        weeklyGoal = validated.weeklyGoal;
        startingWeight = validated.startingWeight;
        startingDate = validated.startingDate;
        activity = profileActivity;
        hydrated = true;
      });
    } catch (error) {
      if (mounted) setState(() => hydrateError = error);
    } finally {
      if (mounted) setState(() => hydrating = false);
    }
  }

  Future<bool> _write(Future<void> Function() operation) async {
    if (saving) return false;
    setState(() => saving = true);
    try {
      await operation();
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(c('Could not save changes.'))));
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<double?> numberEditor(
    String title,
    double initial,
    double min,
    double max,
  ) async {
    if (_numberEditorOpen) return null;
    _numberEditorOpen = true;
    final controller = TextEditingController(text: initial.toStringAsFixed(1));
    double? result;
    try {
      result = await showModalBottomSheet<double>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final value = double.tryParse(
                        controller.text.replaceAll(',', '.'),
                      );
                      if (value != null && value >= min && value <= max) {
                        Navigator.pop(sheetContext, value);
                      }
                    },
                    icon: const Icon(Icons.check_rounded),
                  ),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: false,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: c('Kilograms'),
                  suffixText: c('kg'),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      // The modal's editable subtree can remain attached through its reverse
      // transition. Disposing the controller before that subtree is removed
      // can make the next route reuse a child that is still being detached.
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      controller.dispose();
      _numberEditorOpen = false;
    }
    return result;
  }

  Future<({double weight, DateTime date})?> startingWeightEditor(
    double initial,
  ) async {
    if (_numberEditorOpen) return null;
    _numberEditorOpen = true;
    final controller = TextEditingController(text: initial.toStringAsFixed(1));
    var date = DateTime.tryParse(startingDate ?? '') ?? DateTime.now();
    ({double weight, DateTime date})? result;
    try {
      result = await showModalBottomSheet<({double weight, DateTime date})>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    Expanded(
                      child: Text(
                        c('Starting Weight'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final weight = double.tryParse(
                          controller.text.replaceAll(',', '.'),
                        );
                        if (weight != null && weight >= 20 && weight <= 500) {
                          Navigator.pop(sheetContext, (
                            weight: weight,
                            date: date,
                          ));
                        }
                      },
                      icon: const Icon(Icons.check_rounded),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('goals-starting-weight-input'),
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: c('Kilograms'),
                    suffixText: c('kg'),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  key: const Key('goals-starting-date'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(c('Starting Date')),
                  subtitle: Text(
                    MaterialLocalizations.of(context).formatMediumDate(date),
                  ),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: sheetContext,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (selected != null) setSheetState(() => date = selected);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      controller.dispose();
      _numberEditorOpen = false;
    }
    return result;
  }

  Future<void> updateProfileWeight(
    UserProfileData profile, {
    double? current,
    double? target,
    String? activityValue,
  }) async {
    final resolvedCurrent =
        current ??
        ref.read(effectiveCurrentWeightProvider) ??
        profile.currentWeight;
    final resolvedTarget = target ?? profile.targetWeight;
    // Read the durable row directly instead of relying on AsyncValue.value.
    // This page can be opened before activeGoalProvider has emitted, and using
    // a transient null there would create a duplicate goal rather than update
    // the existing Health Goal.
    final goalRepository = ref.read(goalRepositoryProvider);
    final activeGoal = target == null ? null : await goalRepository.getActive();
    await ref.read(databaseProvider).transaction(() async {
      await ref
          .read(userProfileRepositoryProvider)
          .save(
            gender: profile.gender,
            age: profile.age,
            height: profile.height,
            currentWeight: resolvedCurrent,
            targetWeight: resolvedTarget,
            activityLevel: activityValue ?? activity ?? profile.activityLevel,
            exercises: profile.exercises,
            medicalConditions: profile.medicalConditions,
            waist: profile.waist,
            neck: profile.neck,
            chest: profile.chest,
            arm: profile.arm,
            thigh: profile.thigh,
          );
      if (current != null) {
        await ref
            .read(weightRepositoryProvider)
            .addWeight(
              current,
              date: DateTime.now(),
              measurementContext: 'unspecified',
            );
      }
      if (target != null) {
        await goalRepository.save(
          uuid: activeGoal?.uuid,
          profileUuid: profile.uuid,
          type: goalTypeForUpdate(
            currentWeightKg: resolvedCurrent,
            targetWeightKg: resolvedTarget,
            storedGoalType: activeGoal?.type,
            storedTargetWeightKg: activeGoal?.targetWeight,
          ),
          targetWeight: resolvedTarget,
          targetDate: activeGoal?.targetDate,
        );
      }
    });
    ref.invalidate(userProfileProvider);
    ref.invalidate(activeGoalProvider);
    ref.invalidate(latestWeightProvider);
    ref.invalidate(todayWeightProvider);
    ref.invalidate(weightHistoryProvider);
  }

  Future<void> chooseWeeklyGoal() async {
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _ChoicePage(
          title: c('Weekly Goal'),
          options: _weeklyOptions,
          selected: weeklyGoal ?? '',
          translate: c,
        ),
      ),
    );
    if (selected == null || selected == weeklyGoal || !mounted || saving) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(c('Are You Sure?')),
        content: Text(
          c(
            'Updating your weekly goal will remove any custom goals. Would you like to continue?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(c('No')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(c('Yes')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final saved = await _write(
      () => ref
          .read(preferencesRepositoryProvider)
          .set('goals.weeklyRate', selected),
    );
    if (saved && mounted) setState(() => weeklyGoal = selected);
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileProvider);
    final effectiveCurrentWeight = ref.watch(effectiveCurrentWeightProvider);
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(centerTitle: true, title: Text(c('Goals'))),
        body: profileState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(userProfileProvider),
              child: Text(c('Retry')),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return Center(child: Text(c('Complete your profile first.')));
            }
            final currentWeight =
                effectiveCurrentWeight ?? profile.currentWeight;
            if (!hydrated && !hydrating && hydrateError == null) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => hydrate(profile.activityLevel),
              );
            }
            if (hydrating || (!hydrated && hydrateError == null)) {
              return const Center(child: CircularProgressIndicator());
            }
            if (hydrateError != null) {
              return Center(
                child: FilledButton(
                  onPressed: () => hydrate(profile.activityLevel),
                  child: Text(c('Retry')),
                ),
              );
            }
            return AbsorbPointer(
              absorbing: saving,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _GoalRow(
                          label: c('Starting Weight'),
                          value: startingWeight == null
                              ? '—'
                              : '${startingWeight!.toStringAsFixed(1)} ${c('kg')}${startingDate == null ? '' : ' · $startingDate'}',
                          onTap: () async {
                            final value = await startingWeightEditor(
                              startingWeight ?? profile.currentWeight,
                            );
                            if (value == null) return;
                            final date = value.date
                                .toIso8601String()
                                .split('T')
                                .first;
                            final repo = ref.read(
                              preferencesRepositoryProvider,
                            );
                            final saved = await _write(
                              () => repo.setMany({
                                'goals.startingWeight': '${value.weight}',
                                'goals.startingDate': date,
                              }),
                            );
                            if (saved && mounted) {
                              setState(() {
                                startingWeight = value.weight;
                                startingDate = date;
                              });
                            }
                          },
                        ),
                        _GoalRow(
                          label: c('Current Weight'),
                          value:
                              '${currentWeight.toStringAsFixed(1)} ${c('kg')}',
                          onTap: () async {
                            final value = await numberEditor(
                              c('Current Weight'),
                              currentWeight,
                              20,
                              500,
                            );
                            if (value != null) {
                              await _write(
                                () => updateProfileWeight(
                                  profile,
                                  current: value,
                                ),
                              );
                            }
                          },
                        ),
                        _GoalRow(
                          label: c('Goal Weight'),
                          value:
                              '${profile.targetWeight.toStringAsFixed(1)} ${c('kg')}',
                          onTap: () async {
                            final value = await numberEditor(
                              c('Goal Weight'),
                              profile.targetWeight,
                              20,
                              500,
                            );
                            if (value != null) {
                              await _write(
                                () =>
                                    updateProfileWeight(profile, target: value),
                              );
                            }
                          },
                        ),
                        _GoalRow(
                          label: c('Weekly Goal'),
                          value: weeklyGoal == null ? '—' : c(weeklyGoal!),
                          onTap: chooseWeeklyGoal,
                        ),
                        _GoalRow(
                          label: c('Activity Level'),
                          value: c(_activityLabels[activity] ?? '—'),
                          onTap: () async {
                            final selected = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _ChoicePage(
                                  title: c('Activity Level'),
                                  options: _activityLabels.keys.toList(),
                                  selected: activity ?? '',
                                  translate: (key) =>
                                      c(_activityLabels[key] ?? key),
                                ),
                              ),
                            );
                            if (selected == null) return;
                            final saved = await _write(
                              () => updateProfileWeight(
                                profile,
                                activityValue: selected,
                              ),
                            );
                            if (saved && mounted) {
                              setState(() => activity = selected);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(c('Nutrition Goals')),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _LinkRow(
                          c('Calorie, Carbs, Protein and Fat Goals'),
                          c('Customize your default or daily goals.'),
                          () => context.push('/settings/nutrition-goals'),
                        ),
                        _LinkRow(
                          c('Different goals by day'),
                          c(
                            'Set calories and macros for each day of the week.',
                          ),
                          () =>
                              context.push('/settings/nutrition-goal-schedule'),
                        ),
                        _PremiumRow(
                          c('Calorie Goals By Meal'),
                          c('Stay on track with a calorie goal for each meal.'),
                          route: '/settings/nutrition-meal-calorie-goals',
                          stateKey: const Key(
                            'goals-meal-calories-entitlement-state',
                          ),
                        ),
                        _PremiumRow(
                          c('Show Carbs, Protein and Fat By Meal'),
                          c('View carbs, protein and fat by gram or percent.'),
                          route: '/settings/diary/macro-display',
                          stateKey: const Key(
                            'goals-meal-macros-entitlement-state',
                          ),
                        ),
                        _LinkRow(
                          c('Additional Nutrient Goals'),
                          null,
                          () => context.push('/settings/nutrition-goals'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(c('Fitness Goals')),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        const _StoredFitnessNumber(
                          'goals.workoutsPerWeek',
                          'Workouts/Week',
                        ),
                        const _StoredFitnessNumber(
                          'goals.minutesPerWorkout',
                          'Minutes/Workout',
                        ),
                        _PremiumRow(
                          c('Exercise Calories'),
                          c(
                            'Decide whether to adjust daily goals when you exercise.',
                          ),
                          route: '/settings/exercise-calories',
                          stateKey: const Key(
                            'goals-exercise-calories-entitlement-state',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

const _weeklyOptions = [
  'Lose 0.2 kg per week',
  'Lose 0.5 kg per week',
  'Lose 0.8 kg per week',
  'Lose 1 kg per week',
  'Maintain weight',
  'Gain 0.2 kg per week',
  'Gain 0.5 kg per week',
];
const _activityLabels = {
  'sedentary': 'Not Very Active',
  'light': 'Lightly Active',
  'moderate': 'Active',
  'active': 'Very Active',
  'very_active': 'Very Active',
};
