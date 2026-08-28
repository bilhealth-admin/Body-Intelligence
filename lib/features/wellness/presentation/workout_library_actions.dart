part of 'wellness_tools_pages.dart';

extension _WorkoutLibraryActions on _WorkoutLibraryPageState {
  Future<void> _loadSortOrder() async {
    final preferences = await SharedPreferences.getInstance();
    if (mounted) {
      _updateState(
        () => sortDescending =
            preferences.getBool(_WorkoutLibraryPageState._sortDescendingKey) ??
            false,
      );
    }
  }

  Future<void> _chooseSortOrder() async {
    var draft = sortDescending;
    var sheetSaving = false;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => PopScope(
          canPop: !sheetSaving,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(tr('Display options', 'خيارات العرض')),
                  subtitle: Text(tr('Exercise sort order', 'ترتيب التمارين')),
                ),
                ListTile(
                  title: Text(tr('A to Z', 'من أ إلى ي')),
                  trailing: draft ? null : const Icon(Icons.check_rounded),
                  onTap: sheetSaving
                      ? null
                      : () => setSheetState(() => draft = false),
                ),
                ListTile(
                  title: Text(tr('Z to A', 'من ي إلى أ')),
                  trailing: draft ? const Icon(Icons.check_rounded) : null,
                  onTap: sheetSaving
                      ? null
                      : () => setSheetState(() => draft = true),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: sheetSaving
                              ? null
                              : () => Navigator.pop(sheetContext),
                          child: Text(tr('Cancel', 'إلغاء')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: sheetSaving
                              ? null
                              : () async {
                                  setSheetState(() => sheetSaving = true);
                                  _updateState(() => customMutationBusy = true);
                                  try {
                                    final writer = widget.sortOrderWriter;
                                    final saved = writer != null
                                        ? await writer(draft)
                                        : await (await SharedPreferences.getInstance())
                                              .setBool(
                                                _WorkoutLibraryPageState
                                                    ._sortDescendingKey,
                                                draft,
                                              );
                                    if (!saved) {
                                      throw StateError(
                                        'preference write rejected',
                                      );
                                    }
                                    if (!mounted || !sheetContext.mounted) {
                                      return;
                                    }
                                    _updateState(() => sortDescending = draft);
                                    Navigator.pop(sheetContext);
                                  } catch (_) {
                                    if (sheetContext.mounted) {
                                      setSheetState(() => sheetSaving = false);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            tr(
                                              'Could not save display options.',
                                              'تعذر حفظ خيارات العرض.',
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      _updateState(
                                        () => customMutationBusy = false,
                                      );
                                    }
                                  }
                                },
                          child: sheetSaving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(tr('Save', 'حفظ')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadHistory() async {
    if (mounted) _updateState(() => historyLoading = true);
    try {
      final logs = await ref.read(dailyLogRepositoryProvider).getAll();
      final parsed = <_WorkoutHistoryEntry>[];
      final latestAllowed = DateTime.now().add(const Duration(minutes: 5));
      for (final log in logs) {
        final raw = log.exerciseNotes?.trim();
        if (raw == null || raw.isEmpty) continue;
        for (final line in const LineSplitter().convert(raw)) {
          try {
            final value = jsonDecode(line);
            if (value is! Map<String, dynamic>) continue;
            final rawId = value['id'];
            final rawName = value['name'];
            final rawMinutes = value['minutes'];
            final rawRecordedAt = value['recordedAt'];
            if (rawId is! String ||
                rawName is! String ||
                rawMinutes is! int ||
                rawRecordedAt is! String) {
              continue;
            }
            final id = rawId.trim();
            final name = rawName.trim();
            final timestamp = DateTime.tryParse(rawRecordedAt)?.toLocal();
            if (id.isEmpty ||
                id.length > 128 ||
                name.isEmpty ||
                name.length > 200 ||
                rawMinutes < 5 ||
                rawMinutes > 120 ||
                timestamp == null ||
                timestamp.isAfter(latestAllowed)) {
              continue;
            }
            parsed.add(
              _WorkoutHistoryEntry(
                id: id,
                name: name,
                minutes: rawMinutes,
                date: timestamp,
              ),
            );
          } catch (_) {
            // Legacy free-form notes remain stored, but are not reusable.
          }
        }
      }
      parsed.sort((a, b) => b.date.compareTo(a.date));
      final recent = parsed.take(200).toList(growable: false);
      if (mounted) {
        _updateState(() {
          history = recent;
          historyLoading = false;
          historyError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        _updateState(() {
          historyLoading = false;
          historyError = tr(
            'Could not load exercise history.',
            'تعذر تحميل سجل التمارين.',
          );
        });
      }
    }
  }

  Future<void> _loadCustomExercises() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(
      _WorkoutLibraryPageState._customExercisesKey,
    );
    if (raw == null || raw.isEmpty) return;
    try {
      final value = jsonDecode(raw);
      if (value is! List<dynamic>) return;
      final decoded = <Map<String, String>>[];
      final ids = <String>{};
      for (final candidate in value) {
        final parsed = _parseCustomExercise(candidate);
        if (parsed != null && ids.add(parsed['id']!)) decoded.add(parsed);
      }
      if (mounted) _updateState(() => customExercises = decoded);
    } catch (_) {
      // Invalid legacy preferences are ignored; the user can create a clean list.
    }
  }

  Future<bool> _persistCustomExercises(
    List<Map<String, String>> candidate,
  ) async {
    final writer = widget.customExercisesWriter;
    if (writer != null) return writer(candidate);
    final preferences = await SharedPreferences.getInstance();
    return preferences.setString(
      _WorkoutLibraryPageState._customExercisesKey,
      jsonEncode(candidate),
    );
  }

  Future<void> _createCustomExercise() async {
    final controller = TextEditingController();
    var category = 'Strength';
    var dialogSaving = false;
    final created = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: !dialogSaving,
          child: AlertDialog(
            title: Text(tr('Create exercise', 'إنشاء تمرين')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('custom-exercise-name'),
                  controller: controller,
                  enabled: !dialogSaving,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: tr('Exercise name', 'اسم التمرين'),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    labelText: tr('Category', 'الفئة'),
                  ),
                  items: const ['Cardio', 'Strength', 'Recovery']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_categoryLabel(value)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (!dialogSaving && value != null) {
                      setDialogState(() => category = value);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: dialogSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(tr('Cancel', 'إلغاء')),
              ),
              FilledButton(
                key: const Key('save-custom-exercise'),
                onPressed: dialogSaving
                    ? null
                    : () async {
                        final name = controller.text.trim();
                        if (!_validCustomExerciseName(name)) return;
                        final entry = <String, String>{
                          'id':
                              'custom-${DateTime.now().microsecondsSinceEpoch}',
                          'name': name,
                          'category': category,
                        };
                        final candidate = [...customExercises, entry];
                        setDialogState(() => dialogSaving = true);
                        _updateState(() => customMutationBusy = true);
                        try {
                          final saved = await _persistCustomExercises(
                            candidate,
                          );
                          if (!saved) {
                            throw StateError('preference write rejected');
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(entry);
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() => dialogSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tr(
                                    'Could not save exercise. Review and retry.',
                                    'تعذر حفظ التمرين. راجع البيانات وأعد المحاولة.',
                                  ),
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            _updateState(() => customMutationBusy = false);
                          }
                        }
                      },
                child: dialogSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr('Save', 'حفظ')),
              ),
            ],
          ),
        ),
      ),
    );
    // The dialog completes before its exit animation has detached every
    // inherited dependency. Disposing here can trip Flutter's
    // `_dependents.isEmpty` assertion while the TextField is still leaving.
    // The short-lived controller becomes collectible with the closed route.
    if (created == null || !mounted) return;
    _updateState(() {
      customExercises = [...customExercises, created];
      libraryTab = 1;
    });
  }

  Future<void> _deleteCustomExercise(String id) async {
    if (customMutationBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Delete exercise?', 'حذف التمرين؟')),
        content: Text(
          tr(
            'This removes the custom exercise from My Exercises.',
            'سيؤدي ذلك إلى إزالة التمرين المخصص من تماريني.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Delete', 'حذف')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final previous = customExercises;
    final candidate = previous
        .where((entry) => entry['id'] != id)
        .toList(growable: false);
    _updateState(() => customMutationBusy = true);
    try {
      final saved = await _persistCustomExercises(candidate);
      if (!saved) throw StateError('preference write rejected');
      if (mounted) _updateState(() => customExercises = candidate);
    } catch (_) {
      if (mounted) {
        _updateState(() => customExercises = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('Could not delete exercise.', 'تعذر حذف التمرين.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) _updateState(() => customMutationBusy = false);
    }
  }

  Future<void> _openCustomExercise(Map<String, String> entry) => _openWorkout(
    _Workout(
      entry['id']!,
      entry['name']!,
      entry['name']!,
      entry['category'] ?? 'Strength',
      entry['category'] ?? 'Strength',
      Icons.fitness_center_rounded,
    ),
  );
}
