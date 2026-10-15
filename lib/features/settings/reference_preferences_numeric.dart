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
  final expectedUnit = NutritionGoalSnapshot.units[key];
  if (expectedUnit == null ||
      (key == 'goal.calories'
          ? suffix != '' && suffix != 'kcal'
          : key.endsWith('Percent')
          ? suffix != '%'
          : suffix != expectedUnit)) {
    return false;
  }
  final number = NutritionGoalSnapshot.parse(input);
  if (number == null || !number.isFinite || number < 0) return false;
  return validDashboardNutrientGoal(key, number);
}

class _StoredNumberState extends ConsumerState<_StoredNumber> {
  String? value;
  String? retainedDraft;
  bool loading = true;
  bool saving = false;
  Object? error;
  bool editorOpen = false;
  int _ownerEpoch = 0;
  int? _editorEpoch;
  ProviderSubscription<PreferencesRepository>? _ownerSubscription;
  bool _editorIsCurrent(PreferencesRepository repository) =>
      mounted &&
      _editorEpoch == _ownerEpoch &&
      identical(repository, ref.read(preferencesRepositoryProvider));
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
    _ownerSubscription = ref.listenManual(preferencesRepositoryProvider, (
      previous,
      next,
    ) {
      if (identical(previous, next)) return;
      _ownerEpoch++;
      retainedDraft = null;
    });
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
    _ownerSubscription?.close();
    _valueSubscription?.cancel();
    super.dispose();
  }

  static String _formatNumber(double value) =>
      _formatNutritionGoalNumber(value);

  Future<void> _saveMacroPercent(
    PreferencesRepository repository,
    double next,
  ) async {
    final atomic = await repository
        .watchSnapshot(NutritionGoalSnapshot.storageKeys)
        .first;
    final expected = {
      for (final key in NutritionGoalSnapshot.storageKeys) key: atomic[key],
    };
    final defaults = ref.read(nutritionGoalDefaultsProvider);
    double number(String key) => expected[key] == null
        ? defaults[key] ?? double.nan
        : double.tryParse(expected[key]!) ?? double.nan;
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
      isCurrent: () => _editorIsCurrent(repository),
      expected: expected,
      set: {
        ...changed.toPreferences(),
        for (final key in NutritionGoalSnapshot.macroKeys)
          'goal.origin.$key': 'manual_override',
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
    final atomic = await repository
        .watchSnapshot(NutritionGoalSnapshot.storageKeys)
        .first;
    final expected = {
      for (final key in NutritionGoalSnapshot.storageKeys) key: atomic[key],
    };
    if (draft.isEmpty) {
      throw const FormatException('Use the explicit restore action.');
    }
    final defaults = ref.read(nutritionGoalDefaultsProvider);
    double number(String key) => expected[key] == null
        ? defaults[key] ?? double.nan
        : double.tryParse(expected[key]!) ?? double.nan;
    final allocation = MacroGoalAllocation(
      number('goal.calories'),
      number('goal.carbsPercent'),
      number('goal.proteinPercent'),
      number('goal.fatPercent'),
    );
    final updated = allocation.withCalories(
      parseNutritionNumber(draft)!,
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
      isCurrent: () => _editorIsCurrent(repository),
      expected: expected,
      set: {
        ...updated.toPreferences(),
        'goal.macroEditor.v2': 'true',
        for (final key in NutritionGoalSnapshot.macroKeys)
          'goal.origin.$key': 'manual_override',
      },
    );
    if (!committed) throw StateError('Goals changed while editing.');
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final epoch = _ownerEpoch;
    try {
      final repository = ref.read(preferencesRepositoryProvider);
      final saved = await repository.get(widget.keyName);
      if (!mounted ||
          epoch != _ownerEpoch ||
          !identical(repository, ref.read(preferencesRepositoryProvider))) {
        return;
      }
      final candidate = saved;
      setState(() {
        value = candidate != null && _valid(candidate) ? candidate : null;
        loading = false;
      });
    } catch (caught) {
      if (mounted && epoch == _ownerEpoch) {
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
    final snapshotState = ref.watch(nutritionGoalSnapshotProvider);
    final resolved = ref
        .watch(nutritionGoalCurrentSnapshotProvider)
        ?.goals[widget.keyName];
    final displayed = resolved?.raw ?? resolved?.value?.toString();
    final displayNumber = resolved?.value;
    final displayText = displayNumber == null
        ? null
        : _formatNumber(displayNumber);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final lock = (_isMacroPercent || _isMacroGrams)
        ? ref.watch(_macroLockProvider(_lockKey))
        : const AsyncValue<bool>.data(false);
    return _responsiveGoalTile(
      context,
      ListTile(
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
                          final epoch = _ownerEpoch;
                          final snapshot = ref.read(
                            nutritionGoalCurrentSnapshotProvider,
                          );
                          final committed = await repository.mutateIfUnchanged(
                            expected: {_lockKey: snapshot?.original[_lockKey]},
                            set: {
                              _lockKey: lock.value == true ? 'false' : 'true',
                            },
                            isCurrent: () =>
                                mounted &&
                                epoch == _ownerEpoch &&
                                identical(
                                  repository,
                                  ref.read(preferencesRepositoryProvider),
                                ),
                          );
                          if (!committed) {
                            throw StateError('Goal lock changed. Retry.');
                          }
                        } on Object {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.strings.text(
                                    'Could not save changes.',
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                      },
              )
            : null,
        title: Text(_nutritionGoalText(context, widget.label)),
        trailing: loading || saving
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : error != null ||
                  resolved?.status == NutritionGoalStatus.storageFailure
            ? TextButton(
                onPressed: () {
                  ref.invalidate(nutritionGoalSnapshotProvider);
                  _load();
                },
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
        onTap:
            loading ||
                snapshotState.isLoading ||
                resolved?.status == NutritionGoalStatus.storageFailure ||
                saving ||
                error != null
            ? null
            : () async {
                if (editorOpen) return;
                editorOpen = true;
                _editorEpoch = _ownerEpoch;
                final editorRepository = ref.read(
                  preferencesRepositoryProvider,
                );
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
                          child: BilPearlAlertDialog(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _nutritionGoalText(context, widget.label),
                                  ),
                                ),
                                if (resolved != null)
                                  _GoalEditorBook(
                                    goal: resolved,
                                    label: widget.label,
                                    isCurrent: () =>
                                        _editorIsCurrent(editorRepository),
                                  ),
                              ],
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: controller,
                                    style: Theme.of(dialogContext)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Theme.of(
                                        dialogContext,
                                      ).colorScheme.surfaceContainerLow,
                                      suffixText: widget.suffix.isEmpty
                                          ? null
                                          : widget.suffix,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    autofocus: true,
                                    enabled: !dialogSaving,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    key: ValueKey(
                                      'restore-suggested-${widget.keyName}',
                                    ),
                                    onPressed: dialogSaving
                                        ? null
                                        : () async {
                                            setDialogState(
                                              () => dialogSaving = true,
                                            );
                                            try {
                                              final restored =
                                                  await _restoreGoalSuggestion(
                                                    context,
                                                    editorRepository,
                                                    widget.keyName,
                                                    () => _editorIsCurrent(
                                                      editorRepository,
                                                    ),
                                                  );
                                              if (restored &&
                                                  dialogContext.mounted) {
                                                Navigator.pop(
                                                  dialogContext,
                                                  '',
                                                );
                                              } else if (dialogContext
                                                  .mounted) {
                                                setDialogState(
                                                  () => dialogSaving = false,
                                                );
                                              }
                                            } on Object {
                                              if (dialogContext.mounted) {
                                                setDialogState(() {
                                                  dialogSaving = false;
                                                  dialogError = context.strings
                                                      .text(
                                                        'Could not save changes.',
                                                      );
                                                });
                                              }
                                            }
                                          },
                                    child: Text(
                                      arabic
                                          ? 'استعادة المقترح'
                                          : 'Restore suggestion',
                                    ),
                                  ),
                                  if (resolved?.needsReview == true)
                                    const _GoalEditorNotice(),
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
                                        if (!validStoredNutritionGoal(
                                          widget.keyName,
                                          widget.suffix,
                                          controller.text,
                                        )) {
                                          setDialogState(
                                            () => dialogError = context.strings
                                                .text(
                                                  'Review values and retry.',
                                                ),
                                          );
                                          return;
                                        }
                                        final draft = controller.text
                                            .trim()
                                            .replaceAll('٫', '.')
                                            .replaceAll(',', '.')
                                            .replaceAllMapped(
                                              RegExp(r'[٠-٩۰-۹]'),
                                              (match) {
                                                const arabic = '٠١٢٣٤٥٦٧٨٩';
                                                const persian = '۰۱۲۳۴۵۶۷۸۹';
                                                final digit = match[0]!;
                                                return '${arabic.contains(digit) ? arabic.indexOf(digit) : persian.indexOf(digit)}';
                                              },
                                            );
                                        if (draft.isEmpty || !_valid(draft)) {
                                          setDialogState(
                                            () => dialogError = context.strings
                                                .text(
                                                  'Review values and retry.',
                                                ),
                                          );
                                          return;
                                        }
                                        if ((_isMacroPercent ||
                                                _isMacroGrams) &&
                                            draft.isEmpty) {
                                          setDialogState(
                                            () => dialogError = context.strings
                                                .text(
                                                  'Review values and retry.',
                                                ),
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
                                          if (!_editorIsCurrent(repository)) {
                                            throw StateError(
                                              'Account changed while editing.',
                                            );
                                          }
                                          if (widget.keyName ==
                                              'goal.calories') {
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
                                              parseNutritionNumber(draft)!,
                                            );
                                          } else {
                                            final saved =
                                                await _saveAdditionalGoal(
                                                  context,
                                                  repository,
                                                  widget.keyName,
                                                  draft,
                                                  ref.read(
                                                    nutritionGoalDefaultsProvider,
                                                  ),
                                                  () => _editorIsCurrent(
                                                    repository,
                                                  ),
                                                );
                                            if (!saved) {
                                              if (dialogContext.mounted) {
                                                setDialogState(
                                                  () => dialogSaving = false,
                                                );
                                              }
                                              if (mounted) {
                                                setState(() => saving = false);
                                              }
                                              return;
                                            }
                                          }
                                          if (!_editorIsCurrent(repository)) {
                                            if (dialogContext.mounted) {
                                              Navigator.pop(dialogContext);
                                            }
                                            return;
                                          }
                                          if (dialogContext.mounted) {
                                            Navigator.pop(dialogContext, draft);
                                          }
                                        } catch (caught) {
                                          if (!_editorIsCurrent(
                                            editorRepository,
                                          )) {
                                            if (dialogContext.mounted) {
                                              Navigator.pop(dialogContext);
                                            }
                                            return;
                                          }
                                          if (dialogContext.mounted) {
                                            setDialogState(() {
                                              dialogSaving = false;
                                              dialogError =
                                                  caught is FormatException &&
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
                if (mounted && !_editorIsCurrent(editorRepository)) {
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
      ),
    );
  }
}
