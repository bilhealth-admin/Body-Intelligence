part of 'wellness_tools_pages.dart';

Map<String, String>? _parseCustomExercise(Object? value) {
  if (value is! Map<String, dynamic> ||
      value.length != 3 ||
      !value.keys.toSet().containsAll(const {'id', 'name', 'category'})) {
    return null;
  }
  final idValue = value['id'];
  final nameValue = value['name'];
  final categoryValue = value['category'];
  if (idValue is! String || nameValue is! String || categoryValue is! String) {
    return null;
  }
  final id = idValue.trim();
  final name = nameValue.trim();
  final category = categoryValue.trim();
  final validId = RegExp(r'^custom-[A-Za-z0-9_-]{1,96}$').hasMatch(id);
  if (!validId ||
      !_validCustomExerciseName(name) ||
      !const {'Cardio', 'Strength', 'Recovery'}.contains(category)) {
    return null;
  }
  return {'id': id, 'name': name, 'category': category};
}

bool _validCustomExerciseName(String value) =>
    value.isNotEmpty &&
    value.length <= 100 &&
    !value.contains(RegExp(r'[\x00-\x1F\x7F]'));

class WorkoutLibraryPage extends ConsumerStatefulWidget {
  const WorkoutLibraryPage({
    super.key,
    this.initialCategory,
    this.customExercisesWriter,
    this.sortOrderWriter,
  });

  /// Optional category selected by the exercise chooser. Unknown values are
  /// ignored so a malformed deep link never hides the complete library.
  final String? initialCategory;

  /// Testable persistence seam. Production uses SharedPreferences when null.
  final Future<bool> Function(List<Map<String, String>> value)?
  customExercisesWriter;
  final Future<bool> Function(bool descending)? sortOrderWriter;

  @override
  ConsumerState<WorkoutLibraryPage> createState() => _WorkoutLibraryPageState();
}

class _WorkoutLibraryPageState extends ConsumerState<WorkoutLibraryPage>
    with _WellnessCopy {
  String query = '';
  String? category;
  _Workout? selected;
  double minutes = 20;
  bool saving = false;
  bool multiSelecting = false;
  int libraryTab = 2;
  List<Map<String, String>> customExercises = const [];
  List<_WorkoutHistoryEntry> history = const [];
  bool historyLoading = false;
  String? historyError;
  bool customMutationBusy = false;
  bool sortDescending = false;
  final Set<String> multiSelection = {};

  static const _customExercisesKey = 'wellness.custom_exercises.v1';
  static const _sortDescendingKey = 'wellness.exercise_sort_descending.v1';

  static const workouts = <_Workout>[
    _Workout(
      'walk',
      'Brisk walk',
      'مشي سريع',
      'Cardio',
      'قلب وتنفس',
      Icons.directions_walk_rounded,
    ),
    _Workout(
      'run',
      'Easy run',
      'جري خفيف',
      'Cardio',
      'قلب وتنفس',
      Icons.directions_run_rounded,
    ),
    _Workout(
      'cycle',
      'Cycling',
      'دراجة',
      'Cardio',
      'قلب وتنفس',
      Icons.directions_bike_rounded,
    ),
    _Workout(
      'strength',
      'Full-body strength',
      'مقاومة لكامل الجسم',
      'Strength',
      'مقاومة',
      Icons.fitness_center_rounded,
    ),
    _Workout(
      'upper',
      'Upper-body strength',
      'مقاومة للجزء العلوي',
      'Strength',
      'مقاومة',
      Icons.accessibility_new_rounded,
    ),
    _Workout(
      'lower',
      'Lower-body strength',
      'مقاومة للجزء السفلي',
      'Strength',
      'مقاومة',
      Icons.airline_seat_legroom_extra_rounded,
    ),
    _Workout(
      'mobility',
      'Mobility flow',
      'تمارين مرونة وحركة',
      'Recovery',
      'تعافٍ',
      Icons.self_improvement_rounded,
    ),
    _Workout(
      'stretch',
      'Gentle stretching',
      'إطالة خفيفة',
      'Recovery',
      'تعافٍ',
      Icons.accessibility_rounded,
    ),
    _Workout(
      'swim',
      'Swimming',
      'سباحة',
      'Cardio',
      'قلب وتنفس',
      Icons.pool_rounded,
    ),
    _Workout(
      'hike',
      'Hiking',
      'المشي الجبلي',
      'Cardio',
      'قلب وتنفس',
      Icons.hiking_rounded,
    ),
    _Workout(
      'stairs',
      'Stair climbing',
      'صعود الدرج',
      'Cardio',
      'قلب وتنفس',
      Icons.stairs_rounded,
    ),
    _Workout(
      'row',
      'Rowing',
      'التجديف',
      'Cardio',
      'قلب وتنفس',
      Icons.rowing_rounded,
    ),
    _Workout(
      'dance',
      'Dance fitness',
      'لياقة الرقص',
      'Cardio',
      'قلب وتنفس',
      Icons.music_note_rounded,
    ),
    _Workout(
      'core',
      'Core strength',
      'تقوية الجذع',
      'Strength',
      'مقاومة',
      Icons.accessibility_new_rounded,
    ),
    _Workout(
      'circuit',
      'Strength circuit',
      'دائرة تمارين المقاومة',
      'Strength',
      'مقاومة',
      Icons.sync_rounded,
    ),
    _Workout(
      'yoga',
      'Yoga',
      'يوغا',
      'Recovery',
      'تعافٍ',
      Icons.self_improvement_rounded,
    ),
    _Workout(
      'pilates',
      'Pilates',
      'بيلاتس',
      'Recovery',
      'تعافٍ',
      Icons.airline_seat_flat_rounded,
    ),
    _Workout(
      'breathing',
      'Breathing recovery',
      'تنفس للتعافي',
      'Recovery',
      'تعافٍ',
      Icons.air_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    category = _normalizedCategory(widget.initialCategory);
    unawaited(_loadCustomExercises());
    unawaited(_loadSortOrder());
    unawaited(_loadHistory());
  }

  Future<void> _loadSortOrder() async {
    final preferences = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => sortDescending = preferences.getBool(_sortDescendingKey) ?? false,
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
                                  setState(() => customMutationBusy = true);
                                  try {
                                    final writer = widget.sortOrderWriter;
                                    final saved = writer != null
                                        ? await writer(draft)
                                        : await (await SharedPreferences.getInstance())
                                              .setBool(
                                                _sortDescendingKey,
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
                                    setState(() => sortDescending = draft);
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
                                      setState(
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
    if (mounted) setState(() => historyLoading = true);
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
        setState(() {
          history = recent;
          historyLoading = false;
          historyError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
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
    final raw = preferences.getString(_customExercisesKey);
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
      if (mounted) setState(() => customExercises = decoded);
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
    return preferences.setString(_customExercisesKey, jsonEncode(candidate));
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
                        setState(() => customMutationBusy = true);
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
                            setState(() => customMutationBusy = false);
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
    setState(() {
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
    setState(() => customMutationBusy = true);
    try {
      final saved = await _persistCustomExercises(candidate);
      if (!saved) throw StateError('preference write rejected');
      if (mounted) setState(() => customExercises = candidate);
    } catch (_) {
      if (mounted) {
        setState(() => customExercises = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('Could not delete exercise.', 'تعذر حذف التمرين.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => customMutationBusy = false);
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

  @override
  void didUpdateWidget(covariant WorkoutLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory) {
      category = _normalizedCategory(widget.initialCategory);
    }
  }

  static String? _normalizedCategory(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'cardio' => 'Cardio',
      'strength' => 'Strength',
      'recovery' => 'Recovery',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        workouts.where((item) {
          final value =
              '${item.en} ${item.ar} ${item.categoryEn} ${item.categoryAr}'
                  .toLowerCase();
          return (category == null || item.categoryEn == category) &&
              value.contains(query.toLowerCase());
        }).toList()..sort((a, b) {
          final comparison = wellnessCopy(context, a.en, a.ar)
              .toLowerCase()
              .compareTo(wellnessCopy(context, b.en, b.ar).toLowerCase());
          return sortDescending ? -comparison : comparison;
        });
    final pageTitle = category == null
        ? tr('Exercise', 'التمارين')
        : _categoryLabel(category!);
    return PopScope(
      canPop: !customMutationBusy && !saving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: customMutationBusy || saving
                ? null
                : () => context.canPop()
                      ? context.pop()
                      : context.go('/dashboard'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          centerTitle: true,
          title: Text(pageTitle),
          actions: [
            IconButton(
              tooltip: tr('Display options', 'خيارات العرض'),
              onPressed: customMutationBusy || saving ? null : _chooseSortOrder,
              icon: const Icon(Icons.sort_by_alpha_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 156),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: tr('Search for an exercise', 'ابحث عن تمرين'),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(tr('All', 'الكل')),
                    selected: category == null,
                    onSelected: (_) => setState(() => category = null),
                  ),
                  const SizedBox(width: 8),
                  for (final option in const [
                    'Cardio',
                    'Strength',
                    'Recovery',
                  ]) ...[
                    ChoiceChip(
                      label: Text(_categoryLabel(option)),
                      selected: category == option,
                      onSelected: (_) => setState(() => category = option),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _WorkoutDiscoveryHero(
              onStrength: () => _openWorkout(
                workouts.firstWhere((item) => item.id == 'strength'),
              ),
              onMobility: () => _openWorkout(
                workouts.firstWhere((item) => item.id == 'mobility'),
              ),
            ),
            const SizedBox(height: 14),
            _WorkoutLibraryTabs(
              selected: libraryTab,
              onSelected: _selectLibraryTab,
            ),
            if (libraryTab == 2)
              for (final item in visible)
                Column(
                  children: [
                    Semantics(
                      button: true,
                      selected: multiSelecting
                          ? multiSelection.contains(item.id)
                          : null,
                      label: wellnessCopy(context, item.en, item.ar),
                      value: _categoryLabel(item.categoryEn),
                      excludeSemantics: true,
                      child: ListTile(
                        minTileHeight: 76,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 22,
                        ),
                        title: Text(wellnessCopy(context, item.en, item.ar)),
                        trailing: multiSelecting
                            ? Checkbox(
                                value: multiSelection.contains(item.id),
                                onChanged: (_) => _toggleMulti(item.id),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: () => multiSelecting
                            ? _toggleMulti(item.id)
                            : _openWorkout(item),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                )
            else if (libraryTab == 1 && customExercises.isNotEmpty)
              for (final entry in customExercises)
                Column(
                  children: [
                    Semantics(
                      button: true,
                      selected: multiSelecting
                          ? multiSelection.contains(entry['id'])
                          : null,
                      label: entry['name'],
                      value: _categoryLabel(entry['category'] ?? 'Strength'),
                      excludeSemantics: multiSelecting,
                      explicitChildNodes: !multiSelecting,
                      child: ListTile(
                        key: Key('custom-exercise-${entry['id']}'),
                        leading: const CircleAvatar(
                          child: Icon(Icons.fitness_center_rounded),
                        ),
                        title: Text(entry['name']!),
                        subtitle: Text(
                          _categoryLabel(entry['category'] ?? 'Strength'),
                        ),
                        onTap: () => multiSelecting
                            ? _toggleMulti(entry['id']!)
                            : _openCustomExercise(entry),
                        trailing: multiSelecting
                            ? Checkbox(
                                value: multiSelection.contains(entry['id']),
                                onChanged: (_) => _toggleMulti(entry['id']!),
                              )
                            : Semantics(
                                container: true,
                                button: true,
                                label: tr('Delete', 'حذف'),
                                excludeSemantics: true,
                                child: IconButton(
                                  tooltip: tr('Delete', 'حذف'),
                                  onPressed: customMutationBusy
                                      ? null
                                      : () =>
                                            _deleteCustomExercise(entry['id']!),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                )
            else if (libraryTab == 0 && historyLoading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (libraryTab == 0 && historyError != null)
              _WorkoutHistoryError(
                message: historyError!,
                onRetry: _loadHistory,
              )
            else if (libraryTab == 0 && history.isNotEmpty)
              for (final entry in history)
                Column(
                  children: [
                    ListTile(
                      key: Key(
                        'workout-history-${entry.id}-${entry.date.millisecondsSinceEpoch}',
                      ),
                      leading: const CircleAvatar(
                        child: Icon(Icons.history_rounded),
                      ),
                      title: Text(_historyDisplayName(entry)),
                      subtitle: Text(
                        tr(
                          '${entry.minutes} min · ${MaterialLocalizations.of(context).formatShortDate(entry.date)}',
                          '${entry.minutes} دقيقة · ${MaterialLocalizations.of(context).formatShortDate(entry.date)}',
                        ),
                      ),
                      trailing: const Icon(Icons.replay_rounded),
                      onTap: () => _reuseHistory(entry),
                    ),
                    const Divider(height: 1),
                  ],
                )
            else
              _WorkoutEmptyState(
                title: libraryTab == 0
                    ? tr('No exercise history yet', 'لا يوجد سجل تمارين بعد')
                    : tr('No custom exercises yet', 'لا توجد تمارين مخصصة بعد'),
                body: libraryTab == 0
                    ? tr(
                        'Exercises you log will appear here for quick reuse.',
                        'ستظهر التمارين التي تسجلها هنا لإعادة استخدامها بسرعة.',
                      )
                    : tr(
                        'Create exercises that match your own training plan.',
                        'أنشئ تمارين تناسب خطتك التدريبية.',
                      ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                if (!multiSelecting) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: customMutationBusy
                          ? null
                          : _createCustomExercise,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(tr('New exercise', 'تمرين جديد')),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: customMutationBusy ? null : _toggleMultiMode,
                    icon: Icon(
                      multiSelecting
                          ? Icons.close_rounded
                          : Icons.library_add_check_outlined,
                    ),
                    label: Text(
                      multiSelecting
                          ? tr('Cancel', 'إلغاء')
                          : tr('Multi-add', 'إضافة متعددة'),
                    ),
                  ),
                ),
                if (multiSelecting) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('log-selected-workouts'),
                      onPressed: multiSelection.isEmpty || saving
                          ? null
                          : _saveSelectedWorkouts,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        tr(
                          'Log ${multiSelection.length}',
                          'سجل ${multiSelection.length}',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _categoryLabel(String value) => switch (value) {
    'Cardio' => tr('Cardio', 'تمارين القلب'),
    'Strength' => tr('Strength', 'تمارين القوة'),
    'Recovery' => tr('Recovery', 'التعافي'),
    _ => value,
  };

  void _toggleMultiMode() {
    setState(() {
      multiSelecting = !multiSelecting;
      if (!multiSelecting) multiSelection.clear();
    });
  }

  void _selectLibraryTab(int value) {
    setState(() {
      libraryTab = value;
      if (multiSelecting) {
        multiSelecting = false;
        multiSelection.clear();
      }
    });
  }

  void _toggleMulti(String id) {
    setState(() {
      if (!multiSelection.add(id)) multiSelection.remove(id);
    });
  }

  Future<void> _reuseHistory(_WorkoutHistoryEntry entry) {
    _Workout? workout;
    for (final item in workouts) {
      if (item.id == entry.id) {
        workout = item;
        break;
      }
    }
    return _openWorkout(
      workout ??
          _Workout(
            entry.id,
            entry.name,
            entry.name,
            'Strength',
            'مقاومة',
            Icons.fitness_center_rounded,
          ),
      initialMinutes: entry.minutes.toDouble(),
    );
  }

  String _historyDisplayName(_WorkoutHistoryEntry entry) {
    for (final item in workouts) {
      if (item.id == entry.id) return wellnessCopy(context, item.en, item.ar);
    }
    return entry.name;
  }

  Future<void> _saveSelectedWorkouts() async {
    final chosen = <_Workout>[
      ...workouts.where((item) => multiSelection.contains(item.id)),
      ...customExercises
          .where((entry) => multiSelection.contains(entry['id']))
          .map(
            (entry) => _Workout(
              entry['id']!,
              entry['name']!,
              entry['name']!,
              entry['category'] ?? 'Strength',
              entry['category'] ?? 'Strength',
              Icons.fitness_center_rounded,
            ),
          ),
    ];
    if (chosen.isEmpty || saving) return;
    final selectedMinutes = <String, double>{
      for (final item in chosen) item.id: 20,
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('Review selected workouts', 'راجع التمارين المحددة')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(
                      '${chosen.length} workouts for today',
                      '${chosen.length} تمارين لليوم',
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in chosen) ...[
                    Semantics(
                      label: wellnessCopy(context, item.en, item.ar),
                      value: tr(
                        '${selectedMinutes[item.id]!.round()} minutes',
                        '${selectedMinutes[item.id]!.round()} دقيقة',
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              wellnessCopy(context, item.en, item.ar),
                            ),
                          ),
                          Text(
                            tr(
                              '${selectedMinutes[item.id]!.round()} min',
                              '${selectedMinutes[item.id]!.round()} د',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Slider(
                      value: selectedMinutes[item.id]!,
                      min: 5,
                      max: 120,
                      divisions: 23,
                      label: '${selectedMinutes[item.id]!.round()}',
                      onChanged: (value) => setDialogState(
                        () => selectedMinutes[item.id] = value,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr('Log workouts', 'تسجيل التمارين')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => saving = true);
    try {
      await _appendWorkouts(
        chosen.map(
          (item) => (workout: item, minutes: selectedMinutes[item.id]!.round()),
        ),
      );
      if (!mounted) return;
      setState(() {
        saving = false;
        multiSelecting = false;
        multiSelection.clear();
        libraryTab = 0;
      });
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              '${chosen.length} workouts added to today’s health record.',
              'تمت إضافة ${chosen.length} تمارين إلى سجل اليوم الصحي.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Could not save workouts.', 'تعذر حفظ التمارين.')),
        ),
      );
    }
  }

  Future<void> _openWorkout(
    _Workout workout, {
    double initialMinutes = 20,
  }) async {
    setState(() {
      selected = workout;
      minutes = initialMinutes.clamp(5, 120);
    });
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              4,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(child: Icon(workout.icon)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wellnessCopy(context, workout.en, workout.ar),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            wellnessCopy(
                              context,
                              workout.categoryEn,
                              workout.categoryAr,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  tr(
                    'Duration: ${minutes.round()} min',
                    'المدة: ${minutes.round()} دقيقة',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: minutes,
                  min: 5,
                  max: 120,
                  divisions: 23,
                  label: '${minutes.round()}',
                  onChanged: (value) {
                    setState(() => minutes = value);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 8),
                _SafetyNote(
                  text: tr(
                    'Only the activity and duration you confirm are saved. BIL does not invent calorie burn.',
                    'يُحفظ النشاط والمدة اللذان تؤكدهما فقط. لا يخترع BIL سعرات محروقة.',
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final saved = await _saveWorkout();
                          if (saved && sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(tr('Log workout', 'تسجيل التمرين')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _saveWorkout() async {
    final workout = selected;
    if (workout == null || saving) return false;
    setState(() => saving = true);
    try {
      await _appendWorkouts([(workout: workout, minutes: minutes.round())]);
      if (!mounted) return true;
      setState(() => saving = false);
      await _loadHistory();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Workout added to today’s health record.',
              'تمت إضافة التمرين إلى سجل اليوم الصحي.',
            ),
          ),
        ),
      );
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Could not save workout.', 'تعذر حفظ التمرين.')),
        ),
      );
      return false;
    }
  }

  Future<void> _appendWorkouts(
    Iterable<({int minutes, _Workout workout})> entries,
  ) async {
    final date = DateTime.now();
    final repository = ref.read(dailyLogRepositoryProvider);
    final recordedAt = DateTime.now().toUtc().toIso8601String();
    final encoded = entries
        .map(
          (entry) => jsonEncode({
            'id': entry.workout.id,
            'name': entry.workout.en,
            'minutes': entry.minutes,
            'recordedAt': recordedAt,
          }),
        )
        .toList(growable: false);
    await repository.appendExerciseNotes(date: date, encodedEntries: encoded);
  }
}

final class _WorkoutHistoryEntry {
  const _WorkoutHistoryEntry({
    required this.id,
    required this.name,
    required this.minutes,
    required this.date,
  });

  final String id, name;
  final int minutes;
  final DateTime date;
}

class _WorkoutDiscoveryHero extends StatelessWidget {
  const _WorkoutDiscoveryHero({
    required this.onStrength,
    required this.onMobility,
  });

  final VoidCallback onStrength;
  final VoidCallback onMobility;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            wellnessCopy(
              context,
              'Featured workouts',
              '\u062a\u0645\u0627\u0631\u064a\u0646 \u0645\u0645\u064a\u0632\u0629',
            ),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 196,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _WorkoutFeatureCard(
                  image: 'assets/images/workouts/workout_strength_cover_v1.png',
                  title: wellnessCopy(
                    context,
                    'Full-body strength',
                    '\u0642\u0648\u0629 \u0644\u0643\u0627\u0645\u0644 \u0627\u0644\u062c\u0633\u0645',
                  ),
                  detail: wellnessCopy(
                    context,
                    '20 min \u2022 Full body',
                    '20 \u062f\u0642\u064a\u0642\u0629 \u2022 \u0643\u0627\u0645\u0644 \u0627\u0644\u062c\u0633\u0645',
                  ),
                  onTap: onStrength,
                ),
                const SizedBox(width: 12),
                _WorkoutFeatureCard(
                  image: 'assets/images/workouts/workout_mobility_cover_v1.png',
                  title: wellnessCopy(
                    context,
                    'Mobility flow',
                    '\u062d\u0631\u0643\u0629 \u0648\u0645\u0631\u0648\u0646\u0629',
                  ),
                  detail: wellnessCopy(
                    context,
                    '15 min \u2022 Recovery',
                    '15 \u062f\u0642\u064a\u0642\u0629 \u2022 \u062a\u0639\u0627\u0641\u064d',
                  ),
                  onTap: onMobility,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkoutFeatureCard extends StatelessWidget {
  const _WorkoutFeatureCard({
    required this.image,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final String image;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 244,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(image),
                fit: BoxFit.cover,
              ),
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x08000000), Color(0xE6000000)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: .86),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkoutLibraryTabs extends StatelessWidget {
  const _WorkoutLibraryTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = <(String, String)>[
      ('History', 'السجل'),
      ('My Exercises', 'تماريني'),
      ('All Exercises', 'كل التمارين'),
    ];
    return Row(
      children: [
        for (final entry in labels.indexed)
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == entry.$1,
              label: wellnessCopy(context, entry.$2.$1, entry.$2.$2),
              child: InkWell(
                onTap: () => onSelected(entry.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: selected == entry.$1 ? 3 : 1,
                        color: selected == entry.$1
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: Text(
                    wellnessCopy(context, entry.$2.$1, entry.$2.$2),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: selected == entry.$1
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WorkoutEmptyState extends StatelessWidget {
  const _WorkoutEmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 48, 32, 20),
    child: Column(
      children: [
        Icon(
          Icons.fitness_center_rounded,
          size: 42,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
}

class _WorkoutHistoryError extends StatelessWidget {
  const _WorkoutHistoryError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 44, 32, 20),
    child: Column(
      children: [
        const Icon(Icons.error_outline_rounded, size: 42),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(wellnessCopy(context, 'Retry', 'إعادة المحاولة')),
        ),
      ],
    ),
  );
}
