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
  return validDashboardNutrientGoal(key, number);
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
  if (stored['goal.macroEditor.v2'] == 'true') return null;
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
  bool get _isMacroGrams => const {
    'goal.carbsGrams',
    'goal.proteinGrams',
    'goal.fatGrams',
  }.contains(widget.keyName);
  MacroGoal get _macro => widget.keyName.contains('protein')
      ? MacroGoal.protein
      : widget.keyName.contains('fat')
      ? MacroGoal.fat
      : MacroGoal.carbohydrate;
  String get _lockKey => 'goal.lock.${MacroGoalAllocation.key(_macro)}';

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
          final candidate = saved;
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
    const keys = [
      'goal.calories',
      'goal.carbsPercent',
      'goal.proteinPercent',
      'goal.fatPercent',
      'goal.macroLastEdited',
      'goal.lock.carbs',
      'goal.lock.protein',
      'goal.lock.fat',
    ];
    final read = await Future.wait(keys.map(repository.get));
    final expected = {for (var i = 0; i < keys.length; i++) keys[i]: read[i]};
    final defaults = ref.read(nutritionGoalDefaultsProvider);
    double number(String key) =>
        double.tryParse(expected[key] ?? '') ?? defaults[key] ?? double.nan;
    final allocation = MacroGoalAllocation(
      number('goal.calories'),
      number('goal.carbsPercent'),
      number('goal.proteinPercent'),
      number('goal.fatPercent'),
    );
    final previous = MacroGoal.values
        .where(
          (item) =>
              MacroGoalAllocation.key(item) == expected['goal.macroLastEdited'],
        )
        .firstOrNull;
    final changed = allocation.edit(
      _macro,
      next,
      inGrams: _isMacroGrams,
      previous: previous,
      locked: {
        for (final item in MacroGoal.values)
          if (expected['goal.lock.${MacroGoalAllocation.key(item)}'] == 'true')
            item,
      },
    );
    final committed = await repository.mutateIfUnchanged(
      expected: expected,
      set: {
        ...changed.toPreferences(),
        'goal.macroLastEdited': MacroGoalAllocation.key(_macro),
        'goal.macroEditor.v2': 'true',
        'goal.lockMode.${MacroGoalAllocation.key(_macro)}': _isMacroGrams
            ? 'grams'
            : 'percent',
      },
    );
    if (!committed) throw StateError('Goals changed while editing. Retry.');
  }

  Future<void> _saveCalories(
    PreferencesRepository repository,
    String draft,
  ) async {
    const keys = [
      'goal.calories',
      'goal.carbsPercent',
      'goal.proteinPercent',
      'goal.fatPercent',
      'goal.carbsGrams',
      'goal.proteinGrams',
      'goal.fatGrams',
      'goal.macroLastEdited',
      'goal.macroEditor.v2',
      'goal.lock.carbs',
      'goal.lock.protein',
      'goal.lock.fat',
      'goal.lockMode.carbs',
      'goal.lockMode.protein',
      'goal.lockMode.fat',
    ];
    final read = await Future.wait(keys.map(repository.get));
    final expected = {for (var i = 0; i < keys.length; i++) keys[i]: read[i]};
    if (draft.isEmpty) {
      final committed = await repository.mutateIfUnchanged(
        expected: expected,
        remove: keys,
      );
      if (!committed) throw StateError('Goals changed while editing.');
      return;
    }
    final defaults = ref.read(nutritionGoalDefaultsProvider);
    double number(String key) =>
        double.tryParse(expected[key] ?? '') ?? defaults[key] ?? double.nan;
    final allocation = MacroGoalAllocation(
      number('goal.calories'),
      number('goal.carbsPercent'),
      number('goal.proteinPercent'),
      number('goal.fatPercent'),
    );
    final updated = allocation.withCalories(
      double.parse(draft),
      locked: {
        for (final item in MacroGoal.values)
          if (expected['goal.lock.${MacroGoalAllocation.key(item)}'] == 'true')
            item,
      },
      gramLocks: {
        for (final item in MacroGoal.values)
          if (expected['goal.lockMode.${MacroGoalAllocation.key(item)}'] ==
              'grams')
            item,
      },
    );
    final committed = await repository.mutateIfUnchanged(
      expected: expected,
      set: {...updated.toPreferences(), 'goal.macroEditor.v2': 'true'},
    );
    if (!committed) throw StateError('Goals changed while editing.');
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repository = ref.read(preferencesRepositoryProvider);
      final saved = await repository.get(widget.keyName);
      if (!mounted ||
          !identical(repository, ref.read(preferencesRepositoryProvider))) {
        return;
      }
      final candidate = saved;
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
  Widget build(BuildContext context) {
    ref.listen(preferencesRepositoryProvider, (previous, next) {
      _valueSubscription?.cancel();
      value = null;
      _valueSubscription = next.watch(widget.keyName).listen((saved) {
        if (mounted && !saving && !editorOpen) {
          setState(() => value = saved != null && _valid(saved) ? saved : null);
        }
      });
      if (!editorOpen) unawaited(_load());
    });
    final defaults = ref.watch(nutritionGoalDefaultsProvider);
    final reference = defaults[widget.keyName];
    final displayed = value ?? widget.defaultValue ?? reference?.toString();
    final displayNumber = double.tryParse(displayed ?? '');
    final displayText = displayNumber == null
        ? null
        : _formatNumber(displayNumber);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final lock = (_isMacroPercent || _isMacroGrams)
        ? ref.watch(_macroLockProvider(_lockKey))
        : const AsyncValue<bool>.data(false);
    return ListTile(
      key: ValueKey('nutrition-goal-${widget.keyName}'),
      leading: (_isMacroPercent || _isMacroGrams)
          ? IconButton(
              tooltip: arabic
                  ? 'تثبيت / تحرير هذا العنصر'
                  : 'Lock / unlock this macro',
              icon: Icon(
                lock.value == true
                    ? Icons.lock_outline
                    : Icons.lock_open_outlined,
                size: 19,
              ),
              onPressed: saving || lock.isLoading || lock.hasError
                  ? null
                  : () async {
                      final repository = ref.read(
                        preferencesRepositoryProvider,
                      );
                      try {
                        await repository.set(
                          _lockKey,
                          lock.value == true ? 'false' : 'true',
                        );
                      } on Object {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.strings.text('Could not save changes.'),
                              ),
                            ),
                          );
                        }
                      }
                    },
            )
          : null,
      subtitle: reference == null
          ? null
          : Text(
              '${arabic ? (NutrientDailyReferences.values.containsKey(widget.keyName) ? 'مرجع الملصق اليومي العام (FDA)، قابل للتعديل' : 'المقترح من ملفك ونشاطك، قابل للتعديل') : (NutrientDailyReferences.values.containsKey(widget.keyName) ? 'General FDA label reference, editable' : 'Suggested from your profile and activity, editable')}: ${_formatNumber(reference)} ${widget.suffix}',
            ),
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
                displayText == null
                    ? '—'
                    : widget.suffix == '%'
                    ? '$displayText%'
                    : '$displayText${widget.suffix.isEmpty ? '' : ' ${widget.suffix}'}',
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
              final editorRepository = ref.read(preferencesRepositoryProvider);
              final controller = TextEditingController(
                text: retainedDraft ?? displayed ?? '',
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
                          title: Text(
                            _nutritionGoalText(context, widget.label),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.keyName == 'goal.calories')
                                Text(
                                  arabic
                                      ? 'تغيير السعرات يحافظ على العناصر المثبتة. إفراغ الحقل يعيد السعرات والماكروز والتثبيت إلى اقتراح ملفك.'
                                      : 'Changing calories preserves locked targets. Clearing restores profile calorie and macro suggestions and removes locks.',
                                ),
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
                                      final draft = controller.text
                                          .trim()
                                          .replaceAll('٫', '.')
                                          .replaceAll(',', '.')
                                          .replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (
                                            match,
                                          ) {
                                            const arabic = '٠١٢٣٤٥٦٧٨٩';
                                            const persian = '۰۱۲۳۴۵۶۷۸۹';
                                            final digit = match[0]!;
                                            return '${arabic.contains(digit) ? arabic.indexOf(digit) : persian.indexOf(digit)}';
                                          });
                                      if (draft.isNotEmpty && !_valid(draft)) {
                                        setDialogState(
                                          () => dialogError = context.strings
                                              .text('Review values and retry.'),
                                        );
                                        return;
                                      }
                                      if ((_isMacroPercent || _isMacroGrams) &&
                                          draft.isEmpty) {
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
                                        final repository = editorRepository;
                                        if (!mounted ||
                                            !identical(
                                              repository,
                                              ref.read(
                                                preferencesRepositoryProvider,
                                              ),
                                            )) {
                                          throw StateError(
                                            'Account changed while editing.',
                                          );
                                        }
                                        if (widget.keyName == 'goal.calories') {
                                          await _saveCalories(
                                            repository,
                                            draft,
                                          );
                                        } else if (draft.isEmpty) {
                                          await repository.remove(
                                            widget.keyName,
                                          );
                                        } else if (_isMacroPercent ||
                                            _isMacroGrams) {
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
                                        if (!mounted ||
                                            !identical(
                                              repository,
                                              ref.read(
                                                preferencesRepositoryProvider,
                                              ),
                                            )) {
                                          if (dialogContext.mounted) {
                                            Navigator.pop(dialogContext);
                                          }
                                          return;
                                        }
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext, draft);
                                        }
                                      } catch (_) {
                                        if (dialogContext.mounted) {
                                          setDialogState(() {
                                            dialogSaving = false;
                                            dialogError =
                                                (_isMacroPercent ||
                                                    _isMacroGrams ||
                                                    widget.keyName ==
                                                        'goal.calories')
                                                ? (arabic
                                                      ? 'راجع مجموع الطاقة وحرّر عنصرًا عند الحاجة، ثم أعد المحاولة. لم تُغيّر العناصر المثبتة.'
                                                      : 'Review the energy total and unlock a macro if needed, then retry. Locked targets were not changed.')
                                                : context.strings.text(
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
              if (mounted &&
                  !identical(
                    editorRepository,
                    ref.read(preferencesRepositoryProvider),
                  )) {
                setState(() {
                  retainedDraft = null;
                  saving = false;
                  value = null;
                });
                await _load();
                return;
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
}
