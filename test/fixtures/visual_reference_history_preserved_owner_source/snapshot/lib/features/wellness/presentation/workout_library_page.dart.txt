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

  void _updateState(VoidCallback update) => setState(update);
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
}
