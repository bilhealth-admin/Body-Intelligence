import '../../shared/widgets/bil_pearl_feature_welcome.dart';
import '../../shared/widgets/bil_pearl_material.dart';
import '../../shared/widgets/bil_navigation_feedback.dart';
import '../../shared/widgets/bil_controller_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/localization/runtime_copy_nutrition_goal_schedule.dart';
import '../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../profile/providers/user_profile_provider.dart';
import '../daily_log/providers/daily_log_provider.dart';
import '../nutrition/providers/nutrition_goal_snapshot_provider.dart';

class NutritionGoalSchedulePage extends ConsumerStatefulWidget {
  const NutritionGoalSchedulePage({super.key, this.initialMeal});
  final String? initialMeal;

  @override
  ConsumerState<NutritionGoalSchedulePage> createState() =>
      _NutritionGoalSchedulePageState();
}

class _NutritionGoalSchedulePageState
    extends ConsumerState<NutritionGoalSchedulePage> {
  String? _savingTarget;

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(nutritionGoalScheduleProvider);
    final mealFocus = const {
      'breakfast',
      'lunch',
      'dinner',
      'snack',
    }.contains(widget.initialMeal);
    final defaultGoal = mealFocus
        ? null
        : ref.watch(defaultNutritionGoalTargetProvider);
    final defaultLoading =
        !mealFocus &&
        defaultGoal == null &&
        ref.watch(nutritionGoalSnapshotProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _text(
            context,
            mealFocus
                ? NutritionGoalScheduleRuntimeCopy.goalsByMeal
                : NutritionGoalScheduleRuntimeCopy.scheduledGoals,
          ),
        ),
      ),
      body: schedule.when(
        loading: () => const Center(child: BilFeatureWelcomeStatus()),
        error: (_, _) => Center(
          child: Text(
            _text(context, NutritionGoalScheduleRuntimeCopy.goalsUnavailable),
          ),
        ),
        data: (value) => ListView(
          children: [
            if (!mealFocus) ...[
              _section(
                context,
                NutritionGoalScheduleRuntimeCopy.differentGoalsByDay,
              ),
              for (var day = 1; day <= 7; day++)
                _targetTile(
                  context,
                  _weekday(context, day),
                  value.dayTargets[day],
                  _savingTarget == null &&
                          (value.dayTargets[day] != null || defaultGoal != null)
                      ? () => _editAndSave(
                          operationKey: 'day:$day',
                          initial: value.dayTargets[day] ?? defaultGoal!,
                          usesDefault: value.dayTargets[day] == null,
                          save: (repository, target, isCurrent) => repository
                              .saveDay(day, target, isCurrent: isCurrent),
                        )
                      : null,
                  isSaving: _savingTarget == 'day:$day',
                  isLoading: value.dayTargets[day] == null && defaultLoading,
                  unavailable:
                      value.dayTargets[day] == null &&
                      defaultGoal == null &&
                      !defaultLoading,
                ),
            ],
            _section(context, NutritionGoalScheduleRuntimeCopy.goalsByMeal),
            for (final meal in const <(String, String)>[
              ('breakfast', NutritionGoalScheduleRuntimeCopy.breakfast),
              ('lunch', NutritionGoalScheduleRuntimeCopy.lunch),
              ('dinner', NutritionGoalScheduleRuntimeCopy.dinner),
              ('snack', NutritionGoalScheduleRuntimeCopy.snack),
            ])
              _targetTile(
                context,
                _text(context, meal.$2),
                value.mealTargets[meal.$1],
                _savingTarget == null
                    ? () => _editAndSave(
                        operationKey: 'meal:${meal.$1}',
                        // Meal defaults have a separate calorie-only contract.
                        // Preserve the existing meal editor template here.
                        initial:
                            value.mealTargets[meal.$1] ??
                            const NutritionGoalTarget(
                              calories: 2000,
                              carbsPercent: 45,
                              proteinPercent: 30,
                              fatPercent: 25,
                            ),
                        save: (repository, target, isCurrent) => repository
                            .saveMeal(meal.$1, target, isCurrent: isCurrent),
                      )
                    : null,
                isSaving: _savingTarget == 'meal:${meal.$1}',
                key: Key('nutrition-meal-goal-${meal.$1}'),
                selected: mealFocus && widget.initialMeal == meal.$1,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAndSave({
    required String operationKey,
    required NutritionGoalTarget initial,
    bool usesDefault = false,
    required Future<void> Function(
      NutritionGoalScheduleRepository repository,
      NutritionGoalTarget? target,
      bool Function() isCurrent,
    )
    save,
  }) async {
    final repository = ref.read(nutritionGoalScheduleRepositoryProvider);
    final preferences = ref.read(preferencesRepositoryProvider);
    final owner = preferences.localOwnerId;
    final visit = ref.read(nutritionGoalOwnerVisitProvider);
    final schedule = ref.read(nutritionGoalScheduleProvider).asData?.value;
    bool isCurrent() =>
        mounted &&
        schedule != null &&
        identical(visit, ref.read(nutritionGoalOwnerVisitProvider)) &&
        identical(preferences, ref.read(preferencesRepositoryProvider)) &&
        owner == ref.read(preferencesRepositoryProvider).localOwnerId &&
        identical(
          repository,
          ref.read(nutritionGoalScheduleRepositoryProvider),
        ) &&
        identical(
          schedule,
          ref.read(nutritionGoalScheduleProvider).asData?.value,
        ) &&
        (!usesDefault ||
            _sameGoal(initial, ref.read(defaultNutritionGoalTargetProvider)));
    if (!isCurrent()) return;
    final result = await _edit(context, initial, isCurrent, usesDefault);
    if (!mounted || !result.$1 || !isCurrent()) return;

    setState(() => _savingTarget = operationKey);
    try {
      await save(repository, result.$2, isCurrent);
    } catch (_) {
      if (!mounted || !isCurrent()) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _text(
                context,
                NutritionGoalScheduleRuntimeCopy.goalCouldNotBeSaved,
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _savingTarget = null);
    }
  }

  Widget _section(BuildContext context, String source) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      _text(context, source),
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );

  Widget _targetTile(
    BuildContext context,
    String title,
    NutritionGoalTarget? target,
    VoidCallback? onTap, {
    bool isSaving = false,
    bool isLoading = false,
    bool unavailable = false,
    Key? key,
    bool selected = false,
  }) => ListTile(
    key: key,
    selected: selected,
    title: Text(title),
    subtitle: Text(
      target == null
          ? _text(
              context,
              unavailable
                  ? NutritionGoalScheduleRuntimeCopy.goalsUnavailable
                  : NutritionGoalScheduleRuntimeCopy.useDefaultGoal,
            )
          : NutritionGoalScheduleRuntimeCopy.formatGoalSummary(
              locale: Localizations.localeOf(context),
              calories: target.calories,
              carbs: target.carbsGrams,
              protein: target.proteinGrams,
              fat: target.fatGrams,
            ),
    ),
    trailing: isSaving || isLoading
        ? const SizedBox.square(dimension: 20, child: BilFeatureWelcomeStatus())
        : const BilNavigationFeedback(child: Icon(Icons.chevron_right_rounded)),
    onTap: onTap,
  );

  Future<(bool, NutritionGoalTarget?)> _edit(
    BuildContext context,
    NutritionGoalTarget initial,
    bool Function() isCurrent,
    bool usesDefault,
  ) async {
    final values = [
      TextEditingController(
        text: _editableGoalNumber(context, initial.calories),
      ),
      TextEditingController(
        text: _editableGoalNumber(context, initial.carbsGrams),
      ),
      TextEditingController(
        text: _editableGoalNumber(context, initial.proteinGrams),
      ),
      TextEditingController(
        text: _editableGoalNumber(context, initial.fatGrams),
      ),
    ];
    final originalText = values.map((value) => value.text).toList();
    final result = await showBilControllerDialog<(bool, NutritionGoalTarget?)>(
      context: context,
      controllers: values,
      builder: (dialogContext) {
        String? error;
        return Consumer(
          builder: (context, dialogRef, _) {
            dialogRef.watch(nutritionGoalOwnerVisitProvider);
            dialogRef.watch(nutritionGoalScheduleProvider);
            if (usesDefault) {
              dialogRef.watch(defaultNutritionGoalTargetProvider);
            }
            final current = isCurrent();
            return StatefulBuilder(
              builder: (dialogContext, setDialogState) =>
                  BilPearlMaterialAlertDialog(
                    scrollable: true,
                    title: Text(
                      _text(context, NutritionGoalScheduleRuntimeCopy.editGoal),
                    ),
                    content: !current
                        ? Text(
                            _text(
                              context,
                              NutritionGoalScheduleRuntimeCopy.goalsUnavailable,
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final entry in const <(String, int)>[
                                (NutritionGoalScheduleRuntimeCopy.calories, 0),
                                (
                                  NutritionGoalScheduleRuntimeCopy
                                      .carbohydratesGrams,
                                  1,
                                ),
                                (
                                  NutritionGoalScheduleRuntimeCopy.proteinGrams,
                                  2,
                                ),
                                (NutritionGoalScheduleRuntimeCopy.fatGrams, 3),
                              ])
                                TextField(
                                  controller: values[entry.$2],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: _text(context, entry.$1),
                                  ),
                                ),
                              if (error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    error!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        dialogContext,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                    actions: [
                      TextButton(
                        onPressed: current
                            ? () => Navigator.pop(dialogContext, (true, null))
                            : null,
                        child: Text(
                          _text(
                            context,
                            NutritionGoalScheduleRuntimeCopy.useDefault,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: !current
                            ? null
                            : () {
                                if (!isCurrent()) return;
                                if (List.generate(
                                  values.length,
                                  (index) =>
                                      values[index].text == originalText[index],
                                ).every((unchanged) => unchanged)) {
                                  Navigator.pop(dialogContext, (true, initial));
                                  return;
                                }
                                final numbers = values
                                    .map(
                                      (controller) => _parseGoalNumber(
                                        context,
                                        controller.text,
                                      ),
                                    )
                                    .toList();
                                if (numbers.any((number) => number == null)) {
                                  setDialogState(
                                    () => error = _text(
                                      context,
                                      NutritionGoalScheduleRuntimeCopy
                                          .enterValidNumbers,
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  final target = NutritionGoalTarget.fromGrams(
                                    calories: numbers[0]!,
                                    carbsGrams: numbers[1]!,
                                    proteinGrams: numbers[2]!,
                                    fatGrams: numbers[3]!,
                                  );
                                  Navigator.pop(dialogContext, (true, target));
                                } on ArgumentError {
                                  setDialogState(
                                    () => error = _text(
                                      context,
                                      NutritionGoalScheduleRuntimeCopy
                                          .macroGramsMustMatchCalories,
                                    ),
                                  );
                                }
                              },
                        child: Text(
                          _text(context, NutritionGoalScheduleRuntimeCopy.save),
                        ),
                      ),
                    ],
                  ),
            );
          },
        );
      },
    );
    return result ?? (false, null);
  }
}

String _weekday(BuildContext context, int weekday) {
  final monday = DateTime(2026, 1, 5 + weekday - 1);
  return DateFormat(
    'EEEE',
    Localizations.localeOf(context).toLanguageTag(),
  ).format(monday);
}

String _text(BuildContext context, String source) =>
    NutritionGoalScheduleRuntimeCopy.text(
      source,
      Localizations.localeOf(context),
    );

String _editableGoalNumber(BuildContext context, num value) =>
    NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toLanguageTag(),
      decimalDigits: (value - value.round()).abs() < 0.005 ? 0 : 2,
    ).format(value);

double? _parseGoalNumber(BuildContext context, String source) {
  final value = source.trim();
  if (value.isEmpty) return null;
  final localized = NumberFormat.decimalPattern(
    Localizations.localeOf(context).toLanguageTag(),
  ).tryParse(value);
  return localized?.toDouble() ?? double.tryParse(value);
}

bool _sameGoal(NutritionGoalTarget initial, NutritionGoalTarget? current) =>
    current != null &&
    initial.calories == current.calories &&
    initial.carbsPercent == current.carbsPercent &&
    initial.proteinPercent == current.proteinPercent &&
    initial.fatPercent == current.fatPercent;
