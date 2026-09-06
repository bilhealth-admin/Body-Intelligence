import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/localization/runtime_copy_nutrition_goal_schedule.dart';
import '../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../profile/providers/user_profile_provider.dart';

class NutritionGoalSchedulePage extends ConsumerStatefulWidget {
  const NutritionGoalSchedulePage({super.key});

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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _text(context, NutritionGoalScheduleRuntimeCopy.scheduledGoals),
        ),
      ),
      body: schedule.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            _text(context, NutritionGoalScheduleRuntimeCopy.goalsUnavailable),
          ),
        ),
        data: (value) => ListView(
          children: [
            _section(
              context,
              NutritionGoalScheduleRuntimeCopy.differentGoalsByDay,
            ),
            for (var day = 1; day <= 7; day++)
              _targetTile(
                context,
                _weekday(context, day),
                value.dayTargets[day],
                _savingTarget == null
                    ? () => _editAndSave(
                        operationKey: 'day:$day',
                        initial: value.dayTargets[day],
                        save: (target) => ref
                            .read(nutritionGoalScheduleRepositoryProvider)
                            .saveDay(day, target),
                      )
                    : null,
                isSaving: _savingTarget == 'day:$day',
              ),
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
                        initial: value.mealTargets[meal.$1],
                        save: (target) => ref
                            .read(nutritionGoalScheduleRepositoryProvider)
                            .saveMeal(meal.$1, target),
                      )
                    : null,
                isSaving: _savingTarget == 'meal:${meal.$1}',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAndSave({
    required String operationKey,
    required NutritionGoalTarget? initial,
    required Future<void> Function(NutritionGoalTarget? target) save,
  }) async {
    final result = await _edit(context, initial);
    if (!result.$1 || !mounted) return;

    setState(() => _savingTarget = operationKey);
    try {
      await save(result.$2);
    } catch (_) {
      if (!mounted) return;
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
  }) => ListTile(
    title: Text(title),
    subtitle: Text(
      target == null
          ? _text(context, NutritionGoalScheduleRuntimeCopy.useDefaultGoal)
          : NutritionGoalScheduleRuntimeCopy.formatGoalSummary(
              locale: Localizations.localeOf(context),
              calories: target.calories.toStringAsFixed(0),
              carbs: target.carbsGrams.toStringAsFixed(1),
              protein: target.proteinGrams.toStringAsFixed(1),
              fat: target.fatGrams.toStringAsFixed(1),
            ),
    ),
    trailing: isSaving
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );

  Future<(bool, NutritionGoalTarget?)> _edit(
    BuildContext context,
    NutritionGoalTarget? initial,
  ) async {
    final values = [
      TextEditingController(text: '${initial?.calories ?? 2000}'),
      TextEditingController(text: '${initial?.carbsGrams ?? 225}'),
      TextEditingController(text: '${initial?.proteinGrams ?? 150}'),
      TextEditingController(text: '${initial?.fatGrams ?? 55.56}'),
    ];
    final result = await showDialog<(bool, NutritionGoalTarget?)>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(
              _text(context, NutritionGoalScheduleRuntimeCopy.editGoal),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in const <(String, int)>[
                  (NutritionGoalScheduleRuntimeCopy.calories, 0),
                  (NutritionGoalScheduleRuntimeCopy.carbohydratesGrams, 1),
                  (NutritionGoalScheduleRuntimeCopy.proteinGrams, 2),
                  (NutritionGoalScheduleRuntimeCopy.fatGrams, 3),
                ])
                  TextField(
                    controller: values[entry.$2],
                    keyboardType: const TextInputType.numberWithOptions(
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
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, (true, null)),
                child: Text(
                  _text(context, NutritionGoalScheduleRuntimeCopy.useDefault),
                ),
              ),
              FilledButton(
                onPressed: () {
                  final numbers = values
                      .map(
                        (controller) => double.tryParse(controller.text.trim()),
                      )
                      .toList();
                  if (numbers.any((number) => number == null)) {
                    setDialogState(
                      () => error = _text(
                        context,
                        NutritionGoalScheduleRuntimeCopy.enterValidNumbers,
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
    for (final controller in values) {
      controller.dispose();
    }
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
