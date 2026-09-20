part of 'reference_preferences_pages.dart';

class _StoredNumber extends ConsumerStatefulWidget {
  const _StoredNumber(this.keyName, this.label, this.defaultValue, this.suffix);
  final String keyName;
  final String label;
  final String? defaultValue;
  final String suffix;
  @override
  ConsumerState<_StoredNumber> createState() => _StoredNumberState();
}

@visibleForTesting
bool validStoredNutritionGoal(String key, String suffix, String input) {
  final number = double.tryParse(input);
  if (number == null || !number.isFinite || number < 0) return false;
  if (key == 'goal.calories') return number >= 1 && number <= 10000;
  if (key.endsWith('Percent') || suffix == '%') return number <= 100;
  if (suffix == 'mg') return number <= 1000000;
  return number <= 10000;
}

typedef MacroPercentages = ({double carbs, double protein, double fat});

String _formatNutritionGoalNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

MacroPercentages normalizeMacroPercentages({double? carbs, double? fat}) {
  final carbsAnchor = carbs;
  final fatAnchor = fat;
  if (carbsAnchor == null ||
      fatAnchor == null ||
      !carbsAnchor.isFinite ||
      !fatAnchor.isFinite ||
      carbsAnchor < 0 ||
      fatAnchor < 0 ||
      carbsAnchor > 100 ||
      fatAnchor > 100 ||
      carbsAnchor + fatAnchor > 100) {
    return (carbs: 45, protein: 30, fat: 25);
  }
  return (
    carbs: carbsAnchor,
    protein: 100 - carbsAnchor - fatAnchor,
    fat: fatAnchor,
  );
}

Map<String, String> nutritionGoalSnapshotForCalories({
  required double calories,
  double? carbsPercent,
  double? fatPercent,
}) {
  final macros = normalizeMacroPercentages(
    carbs: carbsPercent,
    fat: fatPercent,
  );
  return {
    'goal.calories': _formatNutritionGoalNumber(calories),
    'goal.carbsPercent': _formatNutritionGoalNumber(macros.carbs),
    'goal.proteinPercent': _formatNutritionGoalNumber(macros.protein),
    'goal.fatPercent': _formatNutritionGoalNumber(macros.fat),
    'goal.carbsGrams': _formatNutritionGoalNumber(
      calories * macros.carbs / 400,
    ),
    'goal.proteinGrams': _formatNutritionGoalNumber(
      calories * macros.protein / 400,
    ),
    'goal.fatGrams': _formatNutritionGoalNumber(calories * macros.fat / 900),
  };
}

/// Returns the canonical seven-key nutrition goal when a persisted snapshot
/// needs repair, otherwise `null`.
///
/// Older builds allowed independently saved macro percentages, so an upgrade
/// can contain totals above 100% or percentages without their derived grams.
/// Carbohydrate and fat are the user's anchors and protein is the remainder.
@visibleForTesting
Map<String, String>? nutritionGoalRepairSnapshot(Map<String, String?> stored) {
  final calories = double.tryParse(stored['goal.calories'] ?? '');
  if (calories == null ||
      !calories.isFinite ||
      calories < 1 ||
      calories > 10000) {
    return null;
  }
  final canonical = nutritionGoalSnapshotForCalories(
    calories: calories,
    carbsPercent: double.tryParse(stored['goal.carbsPercent'] ?? ''),
    fatPercent: double.tryParse(stored['goal.fatPercent'] ?? ''),
  );
  final unchanged = canonical.entries.every(
    (entry) => stored[entry.key] == entry.value,
  );
  return unchanged ? null : canonical;
}

class _StoredNumberState extends ConsumerState<_StoredNumber> {
  String? value;
  String? retainedDraft;
  bool loading = true;
  bool saving = false;
  Object? error;
  bool editorOpen = false;
  StreamSubscription<String?>? _valueSubscription;

  static const _macroPercentKeys = {
    'goal.carbsPercent',
    'goal.proteinPercent',
    'goal.fatPercent',
  };

  bool get _isMacroPercent => _macroPercentKeys.contains(widget.keyName);

  bool _valid(String input) {
    return validStoredNutritionGoal(widget.keyName, widget.suffix, input);
  }

  @override
  void initState() {
    super.initState();
    _load();
    // Macro edits are committed atomically by their sibling row (for
    // example, changing carbs recomputes protein).  Watching the preference
    // keeps every row in sync immediately instead of requiring a page reload.
    _valueSubscription = ref
        .read(preferencesRepositoryProvider)
        .watch(widget.keyName)
        .listen((saved) {
          if (!mounted || saving || editorOpen) return;
          final candidate = saved ?? widget.defaultValue;
          final next = candidate != null && _valid(candidate)
              ? candidate
              : null;
          if (next != value) setState(() => value = next);
        });
  }

  @override
  void dispose() {
    _valueSubscription?.cancel();
    super.dispose();
  }

  static String _formatNumber(double value) =>
      _formatNutritionGoalNumber(value);

  Future<void> _saveMacroPercent(
    PreferencesRepository repository,
    double next,
  ) async {
    final stored = await Future.wait([
      repository.get('goal.carbsPercent'),
      repository.get('goal.proteinPercent'),
      repository.get('goal.fatPercent'),
      repository.get('goal.calories'),
    ]);
    var carbs = double.tryParse(stored[0] ?? '') ?? 45;
    var protein = double.tryParse(stored[1] ?? '') ?? 30;
    var fat = double.tryParse(stored[2] ?? '') ?? 25;
    if (widget.keyName == 'goal.carbsPercent') carbs = next;
    if (widget.keyName == 'goal.proteinPercent') protein = next;
    if (widget.keyName == 'goal.fatPercent') fat = next;

    // Keep the three-way split closed at 100% after every edit.  The field
    // being edited is authoritative; protein is the balancing remainder for
    // carbs/fat edits, while fat is the remainder for a direct protein edit.
    if (widget.keyName == 'goal.proteinPercent') {
      fat = 100 - carbs - protein;
    } else {
      protein = 100 - carbs - fat;
    }
    if (![carbs, protein, fat].every((item) => item.isFinite && item >= 0)) {
      throw const FormatException('Macro percentages must total 100%.');
    }
    if ((carbs + protein + fat - 100).abs() > 0.001) {
      throw const FormatException('Macro percentages must total 100%.');
    }
    final values = <String, String>{
      'goal.carbsPercent': _formatNumber(carbs),
      'goal.proteinPercent': _formatNumber(protein),
      'goal.fatPercent': _formatNumber(fat),
    };
    final calories = double.tryParse(stored[3] ?? '');
    if (calories != null && calories.isFinite && calories > 0) {
      values.addAll({
        'goal.carbsGrams': _formatNumber(calories * carbs / 400),
        'goal.proteinGrams': _formatNumber(calories * protein / 400),
        'goal.fatGrams': _formatNumber(calories * fat / 900),
      });
    }
    await repository.setMany(values);
  }

  Future<void> _saveCalories(
    PreferencesRepository repository,
    String draft,
  ) async {
    if (draft.isEmpty) {
      await repository.mutate(
        remove: [
          widget.keyName,
          'goal.carbsGrams',
          'goal.proteinGrams',
          'goal.fatGrams',
        ],
      );
      return;
    }
    final calories = double.parse(draft);
    final stored = await Future.wait([
      repository.get('goal.carbsPercent'),
      repository.get('goal.fatPercent'),
    ]);
    final snapshot = nutritionGoalSnapshotForCalories(
      calories: calories,
      carbsPercent: double.tryParse(stored[0] ?? ''),
      fatPercent: double.tryParse(stored[1] ?? ''),
    );
    // setMany is one database transaction, so the calorie target, repaired
    // percentages, and derived grams are never observed as a partial plan.
    await repository.setMany(snapshot);
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final saved = await ref
          .read(preferencesRepositoryProvider)
          .get(widget.keyName);
      if (!mounted) return;
      final candidate = saved ?? widget.defaultValue;
      setState(() {
        value = candidate != null && _valid(candidate) ? candidate : null;
        loading = false;
      });
    } catch (caught) {
      if (mounted) {
        setState(() {
          loading = false;
          error = caught;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(_nutritionGoalText(context, widget.label)),
    trailing: loading || saving
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : error != null
        ? TextButton(
            onPressed: _load,
            child: Text(context.strings.text('Retry')),
          )
        : Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value == null
                  ? '—'
                  : widget.suffix == '%'
                  ? '$value%'
                  : '$value${widget.suffix.isEmpty ? '' : ' ${widget.suffix}'}',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF0A6FF5),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
    onTap: loading || saving || error != null
        ? null
        : () async {
            if (editorOpen) return;
            editorOpen = true;
            final controller = TextEditingController(
              text: retainedDraft ?? value ?? '',
            );
            String? next;
            try {
              next = await showDialog<String>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) {
                  var dialogSaving = false;
                  String? dialogError;
                  return StatefulBuilder(
                    builder: (dialogContext, setDialogState) => PopScope(
                      canPop: !dialogSaving,
                      child: AlertDialog(
                        title: Text(_nutritionGoalText(context, widget.label)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: controller,
                              autofocus: true,
                              enabled: !dialogSaving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                            if (dialogError != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                dialogError!,
                                style: TextStyle(
                                  color: Theme.of(
                                    dialogContext,
                                  ).colorScheme.error,
                                ),
                              ),
                            ],
                            if (dialogSaving) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(),
                            ],
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: dialogSaving
                                ? null
                                : () => Navigator.pop(dialogContext),
                            child: Text(context.strings.text('Cancel')),
                          ),
                          FilledButton(
                            onPressed: dialogSaving
                                ? null
                                : () async {
                                    final draft = controller.text.trim();
                                    if (draft.isNotEmpty && !_valid(draft)) {
                                      setDialogState(
                                        () => dialogError = context.strings
                                            .text('Review values and retry.'),
                                      );
                                      return;
                                    }
                                    if (_isMacroPercent && draft.isEmpty) {
                                      setDialogState(
                                        () => dialogError = context.strings
                                            .text('Review values and retry.'),
                                      );
                                      return;
                                    }
                                    setDialogState(() {
                                      dialogSaving = true;
                                      dialogError = null;
                                    });
                                    if (mounted) {
                                      setState(() => saving = true);
                                    }
                                    try {
                                      final repository = ref.read(
                                        preferencesRepositoryProvider,
                                      );
                                      if (widget.keyName == 'goal.calories') {
                                        await _saveCalories(repository, draft);
                                      } else if (draft.isEmpty) {
                                        await repository.remove(widget.keyName);
                                      } else if (_isMacroPercent) {
                                        await _saveMacroPercent(
                                          repository,
                                          double.parse(draft),
                                        );
                                      } else {
                                        await repository.set(
                                          widget.keyName,
                                          draft,
                                        );
                                      }
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext, draft);
                                      }
                                    } catch (_) {
                                      if (dialogContext.mounted) {
                                        setDialogState(() {
                                          dialogSaving = false;
                                          dialogError = context.strings.text(
                                            'Could not save changes.',
                                          );
                                        });
                                      }
                                      if (mounted) {
                                        setState(() => saving = false);
                                      }
                                    }
                                  },
                            child: Text(context.strings.text('Save')),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            } finally {
              await WidgetsBinding.instance.endOfFrame;
              await Future<void>.delayed(const Duration(milliseconds: 250));
              controller.dispose();
              editorOpen = false;
            }
            final saved = next;
            if (saved == null || !mounted || !context.mounted) {
              return;
            }
            setState(() {
              value = saved.isEmpty ? null : saved;
              retainedDraft = null;
              saving = false;
            });
          },
  );
}
