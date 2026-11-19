import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' show OrderingTerm;
import '../../core/units/measurement_units.dart';
import '../../data/repositories/preferences_repository.dart';
import '../nutrition/domain/nutrition_pace_intent.dart';
import '../../shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:body_intelligence_log/shared/widgets/calendar/bil_crystal_date_picker.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import '../../shared/widgets/bil_pearl_material.dart';
import '../../shared/widgets/bil_navigation_feedback.dart';
import 'fitness_goal_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router/bil_safe_return_button.dart';

import '../../app/localization/runtime_copy.dart';
import '../../app/theme/bil_semantic_icons.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../shared/widgets/repeating_step_action.dart';
import '../profile/providers/user_profile_provider.dart';
import '../profile/providers/profile_auth_identity_provider.dart';
import '../commerce/domain/commerce_entitlement.dart';
import '../commerce/domain/subscription_state.dart';
import '../commerce/providers/commerce_providers.dart';
import '../weight/providers/weight_provider.dart';
import '../weight/domain/weight_goal_progress.dart';
import '../visual_2026/bil_calm_visual_scope.dart';
part 'reference_goals_components.dart';
part 'reference_goals_validation.dart';
part 'reference_goals_owner_visit.dart';
part 'reference_goals_weight_editors.dart';

@visibleForTesting
String premiumGoalDestination(String featureRoute) => featureRoute;

class ReferenceGoalsPage extends ConsumerStatefulWidget {
  const ReferenceGoalsPage({super.key});

  @override
  ConsumerState<ReferenceGoalsPage> createState() => _ReferenceGoalsPageState();
}

class _ReferenceGoalsPageState extends ConsumerState<ReferenceGoalsPage> {
  String? weeklyGoal;
  double? weeklyPaceKg;
  int _goalOwnerEpoch = 0;
  String? _goalResolvedProfileUuid;
  String? activity;
  double? startingWeight;
  String? startingDate;
  bool hydrated = false;
  bool hydrating = false;
  Object? hydrateError;
  bool saving = false;
  bool _numberEditorOpen = false;

  // Extensions notify through this State instance; owner checks stay at call sites.
  void _setGoalState(VoidCallback update) => setState(update);

  String c(String key) {
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode;
    final translated = _copy[key]?[language];
    return translated ??
        RuntimeCopy.resolve(key, locale.toLanguageTag()) ??
        key;
  }

  @override
  void initState() {
    super.initState();
    _watchGoalOwner();
  }

  Future<void> updateProfileWeight(
    UserProfileData profile,
    _ReferenceGoalVisit visit, {
    double? current,
    double? target,
    String? activityValue,
  }) async {
    visit.check();
    // Capture repositories before awaiting; never resolve a later owner's
    // provider inside the write transaction with this owner's profile.
    final profiles = ref.read(userProfileRepositoryProvider);
    final goals = ref.read(goalRepositoryProvider);
    final weights = ref.read(weightRepositoryProvider);
    final latest = await profiles.getProfile();
    visit.check();
    if (latest == null || latest.uuid != profile.uuid) {
      throw StateError('reference_goals_profile_changed');
    }
    final resolvedCurrent = current ?? _currentWeightForGoals(latest);
    final resolvedTarget = target ?? latest.targetWeight;
    final activeGoal = target == null ? null : await goals.getActive();
    visit.check();
    await profiles.save(
      gender: latest.gender,
      age: latest.age,
      height: latest.height,
      currentWeight: resolvedCurrent,
      targetWeight: resolvedTarget,
      activityLevel: activityValue ?? latest.activityLevel,
      exercises: latest.exercises,
      medicalConditions: latest.medicalConditions,
      waist: latest.waist,
      neck: latest.neck,
      chest: latest.chest,
      arm: latest.arm,
      thigh: latest.thigh,
    );
    visit.check();
    if (current != null) {
      await weights.addWeight(
        current,
        date: DateTime.now(),
        measurementContext: 'unspecified',
      );
      visit.check();
    }
    if (target != null) {
      await goals.save(
        uuid: activeGoal?.uuid,
        profileUuid: latest.uuid,
        type: goalTypeForUpdate(
          currentWeightKg: resolvedCurrent,
          targetWeightKg: resolvedTarget,
          storedGoalType: activeGoal?.type,
          storedTargetWeightKg: activeGoal?.targetWeight,
        ),
        targetWeight: resolvedTarget,
        targetDate: activeGoal?.targetDate,
      );
      visit.check();
    }
  }

  void _refreshGoalInputs() {
    ref.invalidate(userProfileProvider);
    ref.invalidate(activeGoalProvider);
    ref.invalidate(latestWeightProvider);
    ref.invalidate(todayWeightProvider);
    ref.invalidate(weightHistoryProvider);
  }

  Future<void> _editGoalWeight(
    UserProfileData profile,
    MeasurementSystem system,
    _ReferenceGoalVisit visit,
  ) async {
    final value = await numberEditor(
      c('Goal Weight'),
      profile.targetWeight,
      20,
      500,
      system,
      visit,
    );
    if (value == null || !visit.current) {
      return;
    }
    final saved = await _writeGoal(
      visit,
      () => updateProfileWeight(profile, visit, target: value),
    );
    if (saved && visit.current) {
      _refreshGoalInputs();
    }
  }

  Future<void> chooseWeeklyGoal(
    UserProfileData profile,
    MeasurementSystem system,
    _ReferenceGoalVisit visit,
  ) async {
    if (!visit.current || saving) {
      return;
    }
    final goals = ref.read(goalRepositoryProvider);
    Goal? active;
    try {
      active = await goals.getActive();
      visit.check();
    } catch (_) {
      if (mounted && visit.current) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(c('Could not save changes.')),
            action: SnackBarAction(
              label: c('Retry'),
              onPressed: () => chooseWeeklyGoal(profile, system, visit),
            ),
          ),
        );
      }
      return;
    }
    if (!mounted || !visit.current) {
      return;
    }
    final direction = active?.type ?? 'maintain';
    final options = _weeklyOptionsForDirection(direction);
    if (options.isEmpty) {
      if (mounted && visit.current) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(c('Goal Weight')),
            action: SnackBarAction(
              label: c('Goal Weight'),
              onPressed: () => _editGoalWeight(profile, system, visit),
            ),
          ),
        );
      }
      return;
    }
    final directionLabel = direction == 'lose'
        ? 'Lose weight'
        : direction == 'gain'
        ? 'Gain weight'
        : 'Maintain weight';
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (choiceContext) => _ChoicePage(
          title: c('Weekly Goal'),
          options: options,
          // An incompatible manual legacy choice is displayed on the main page,
          // never forced into a new selector or silently replaced by its first row.
          selected: options.contains(weeklyGoal) ? weeklyGoal! : '',
          translate: (option) =>
              _goalWeeklyText(_weeklyPaceByOption[option], system),
          header: ListTile(
            title: Text(c(directionLabel)),
            trailing: TextButton(
              key: const Key('goals-weekly-edit-weight-goal'),
              onPressed: () => Navigator.pop(choiceContext, 'edit-weight-goal'),
              child: Text(c('Goal Weight')),
            ),
          ),
        ),
      ),
    );
    if (!mounted || !visit.current || selected == null) {
      return;
    }
    if (selected == 'edit-weight-goal') {
      await _editGoalWeight(profile, system, visit);
      return;
    }
    if (!options.contains(selected)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => BilPearlMaterialAlertDialog(
        title: Text(c('Are You Sure?')),
        content: Text(_goalWeeklyText(_weeklyPaceByOption[selected], system)),
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
    if (confirmed != true || !visit.current) {
      return;
    }
    final saved = await _writeGoal(visit, () async {
      final latestGoal = await goals.getActive();
      visit.check();
      if ((latestGoal?.type ?? 'maintain') != direction) {
        throw StateError('reference_goals_direction_changed');
      }
      final raw = await visit.preferences.get(NutritionPaceIntent.storageKey);
      visit.check();
      await visit.preferences.setManyInCurrentTransaction({
        'goals.weeklyRate': selected,
        NutritionPaceIntent.storageKey: referenceGoalWeeklyIntent(
          raw,
          selected,
        ),
      });
    }, retry: () => chooseWeeklyGoal(profile, system, visit));
    if (saved && visit.current) {
      setState(() {
        weeklyGoal = selected;
        weeklyPaceKg = _weeklyPaceByOption[selected];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);
    final authState = ref.watch(profileAuthIdentityProvider);
    final systemState = ref.watch(measurementSystemProvider);
    final profileState = ref.watch(userProfileProvider);
    final latestWeightState = ref.watch(latestWeightProvider);
    return BilCalmVisualScope(
      builder: (context) => PopScope(
        canPop: !saving,
        child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            leading: saving
                ? const IconButton(
                    onPressed: null,
                    icon: BilCrystalArrow(child: BackButtonIcon()),
                  )
                : const BilSafeReturnButton(fallbackLocation: '/dashboard'),
            title: Text(c('Goals')),
          ),
          body: profileState.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            loading: () => const Center(child: BilFeatureWelcomeStatus()),
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
              final system = systemState.isLoading
                  ? null
                  : systemState.asData?.value;
              if (systemState.hasError) {
                return Center(
                  child: FilledButton(
                    onPressed: () => ref.invalidate(measurementSystemProvider),
                    child: Text(c('Retry')),
                  ),
                );
              }
              final visit = _goalVisit(profile, database, authState);
              if (system == null || visit == null) {
                return const Center(child: BilFeatureWelcomeStatus());
              }
              final currentWeight = _currentWeightForGoals(
                profile,
                latestState: latestWeightState,
              );
              if (!hydrated && !hydrating && hydrateError == null) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _hydrateGoals(profile, visit),
                );
              }
              if (hydrating || (!hydrated && hydrateError == null)) {
                return const Center(child: BilFeatureWelcomeStatus());
              }
              if (hydrateError != null) {
                return Center(
                  child: FilledButton(
                    onPressed: () => _hydrateGoals(profile, visit),
                    child: Text(c('Retry')),
                  ),
                );
              }
              return AbsorbPointer(
                absorbing: saving,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    BilPearlMaterialCard(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _GoalRow(
                            label: c('Starting Weight'),
                            value: startingWeight == null
                                ? '—'
                                : '${_goalWeightText(startingWeight!, system)}${startingDate == null ? '' : ' · $startingDate'}',
                            onTap: () async {
                              final value = await startingWeightEditor(
                                startingWeight ?? profile.currentWeight,
                                system,
                                visit,
                              );
                              if (value == null || !visit.current) {
                                return;
                              }
                              final date = value.date
                                  ?.toIso8601String()
                                  .split('T')
                                  .first;
                              final repo = visit.preferences;
                              final saved = await _writeGoal(
                                visit,
                                () => repo.setManyInCurrentTransaction({
                                  'goals.startingWeight': '${value.weight}',
                                  'goals.startingDate': ?date,
                                }),
                              );
                              if (saved && visit.current) {
                                setState(() {
                                  startingWeight = value.weight;
                                  if (date != null) {
                                    startingDate = date;
                                  }
                                });
                              }
                            },
                          ),
                          _GoalRow(
                            label: c('Current Weight'),
                            value: _goalWeightText(currentWeight, system),
                            onTap: () async {
                              final value = await numberEditor(
                                c('Current Weight'),
                                currentWeight,
                                20,
                                500,
                                system,
                                visit,
                              );
                              if (value != null) {
                                final saved = await _writeGoal(
                                  visit,
                                  () => updateProfileWeight(
                                    profile,
                                    visit,
                                    current: value,
                                  ),
                                );
                                if (saved && visit.current) {
                                  _refreshGoalInputs();
                                }
                              }
                            },
                          ),
                          _GoalRow(
                            label: c('Goal Weight'),
                            value: _goalWeightText(
                              profile.targetWeight,
                              system,
                            ),
                            onTap: () =>
                                _editGoalWeight(profile, system, visit),
                          ),
                          _GoalRow(
                            label: c('Weekly Goal'),
                            value: _goalWeeklyText(weeklyPaceKg, system),
                            onTap: () =>
                                chooseWeeklyGoal(profile, system, visit),
                          ),
                          _GoalRow(
                            label: c('Activity Level'),
                            value: c(_activityLabels[activity] ?? '—'),
                            onTap: () async {
                              if (!visit.current) {
                                return;
                              }
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
                              if (selected == null || !visit.current) {
                                return;
                              }
                              final saved = await _writeGoal(
                                visit,
                                () => updateProfileWeight(
                                  profile,
                                  visit,
                                  activityValue: selected,
                                ),
                              );
                              if (saved && visit.current) {
                                setState(() => activity = selected);
                                _refreshGoalInputs();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: const Key('goals-methodology-sources'),
                        onPressed: () => context.push(
                          '/health-information-sources?topic=weight-planning',
                        ),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? 'منهجية التخطيط ومصدرها'
                              : '${c('Method')} · ${c('Source')}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Section(c('Nutrition Goals')),
                    BilPearlMaterialCard(
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
                            () => context.push(
                              '/settings/nutrition-goal-schedule',
                            ),
                          ),
                          _PremiumRow(
                            c('Calorie Goals By Meal'),
                            c(
                              'Stay on track with a calorie goal for each meal.',
                            ),
                            route: '/settings/nutrition-meal-calorie-goals',
                            stateKey: const Key(
                              'goals-meal-calories-entitlement-state',
                            ),
                          ),
                          _PremiumRow(
                            c('Show Carbs, Protein and Fat By Meal'),
                            c(
                              'View carbs, protein and fat by gram or percent.',
                            ),
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
                    BilPearlMaterialCard(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          const FitnessGoalProgressCard(),
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
      ),
    );
  }
}
