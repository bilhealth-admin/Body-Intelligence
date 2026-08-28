part of 'wellness_tools_pages.dart';

extension _WorkoutLibrarySelection on _WorkoutLibraryPageState {
  String _categoryLabel(String value) => switch (value) {
    'Cardio' => tr('Cardio', 'تمارين القلب'),
    'Strength' => tr('Strength', 'تمارين القوة'),
    'Recovery' => tr('Recovery', 'التعافي'),
    _ => value,
  };

  void _toggleMultiMode() {
    _updateState(() {
      multiSelecting = !multiSelecting;
      if (!multiSelecting) multiSelection.clear();
    });
  }

  void _selectLibraryTab(int value) {
    _updateState(() {
      libraryTab = value;
      if (multiSelecting) {
        multiSelecting = false;
        multiSelection.clear();
      }
    });
  }

  void _toggleMulti(String id) {
    _updateState(() {
      if (!multiSelection.add(id)) multiSelection.remove(id);
    });
  }

  Future<void> _reuseHistory(_WorkoutHistoryEntry entry) {
    _Workout? workout;
    for (final item in _WorkoutLibraryPageState.workouts) {
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
    for (final item in _WorkoutLibraryPageState.workouts) {
      if (item.id == entry.id) return wellnessCopy(context, item.en, item.ar);
    }
    return entry.name;
  }

  Future<void> _saveSelectedWorkouts() async {
    final chosen = <_Workout>[
      ..._WorkoutLibraryPageState.workouts.where(
        (item) => multiSelection.contains(item.id),
      ),
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
    _updateState(() => saving = true);
    try {
      await _appendWorkouts(
        chosen.map(
          (item) => (workout: item, minutes: selectedMinutes[item.id]!.round()),
        ),
      );
      if (!mounted) return;
      _updateState(() {
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
      _updateState(() => saving = false);
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
    _updateState(() {
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
                    _updateState(() => minutes = value);
                    setSheetState(() {});
                  },
                ),
                Builder(
                  builder: (context) {
                    final estimate = _manualEnergyEstimate(
                      workout,
                      minutes.round(),
                    );
                    if (estimate == null) return const SizedBox.shrink();
                    return ListTile(
                      key: const Key('manual-exercise-calorie-estimate'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.local_fire_department_outlined),
                      title: Text(
                        '${estimate.kcal.round()} ${tr('kcal estimated', 'سعرة تقديرية')}',
                      ),
                      subtitle: Text(
                        tr(
                          'MET estimate · does not change today’s calorie allowance',
                          'تقدير MET · لا يغيّر ميزانية سعرات اليوم',
                        ),
                      ),
                    );
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
    _updateState(() => saving = true);
    try {
      await _appendWorkouts([(workout: workout, minutes: minutes.round())]);
      if (!mounted) return true;
      _updateState(() => saving = false);
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
      _updateState(() => saving = false);
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
        .map((entry) {
          final estimate = _manualEnergyEstimate(entry.workout, entry.minutes);
          return jsonEncode({
            'id': entry.workout.id,
            'name': entry.workout.en,
            'minutes': entry.minutes,
            'recordedAt': recordedAt,
            if (estimate != null) ...{
              'estimatedCaloriesKcal': estimate.kcal.round(),
              'calorieEstimate': 'met',
              'met': estimate.met,
              'affectsCalorieBudget': false,
            },
          });
        })
        .toList(growable: false);
    await repository.appendExerciseNotes(date: date, encodedEntries: encoded);
  }

  ExerciseCalorieEstimate? _manualEnergyEstimate(
    _Workout workout,
    int durationMinutes,
  ) {
    final weightKg = ref.read(userProfileProvider).value?.currentWeight;
    if (weightKg == null) return null;
    return ExerciseEnergyEngine.estimate(
      met: ExerciseEnergyEngine.metFor(
        id: workout.id,
        category: workout.categoryEn,
      ),
      weightKg: weightKg,
      durationMinutes: durationMinutes,
    );
  }
}
