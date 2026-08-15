part of 'bil_workout_routines_page.dart';

class _CustomWorkoutRoutine {
  const _CustomWorkoutRoutine({
    required this.id,
    required this.name,
    required this.description,
    required this.itemIds,
  });

  final String id;
  final String name;
  final String description;
  final List<String> itemIds;

  factory _CustomWorkoutRoutine.fromJson(Map<String, dynamic> json) {
    const keys = {'id', 'name', 'description', 'itemIds'};
    if (json.keys.toSet().difference(keys).isNotEmpty ||
        keys.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException('Invalid custom routine keys.');
    }
    final id = _validatedRoutineText(json['id'], 'id', 128);
    final name = _validatedRoutineText(json['name'], 'name', 120);
    final description = _validatedRoutineText(
      json['description'],
      'description',
      1000,
      allowEmpty: true,
    );
    final idPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$');
    if (!idPattern.hasMatch(id)) {
      throw const FormatException('Invalid custom routine id.');
    }
    final rawIds = json['itemIds'];
    if (rawIds is! List<dynamic> || rawIds.isEmpty || rawIds.length > 100) {
      throw const FormatException('Invalid custom routine movements.');
    }
    final ids = <String>[];
    final seen = <String>{};
    for (final value in rawIds) {
      final movementId = _validatedRoutineText(value, 'movementId', 128);
      if (!idPattern.hasMatch(movementId) || !seen.add(movementId)) {
        throw const FormatException('Invalid or duplicate movement id.');
      }
      ids.add(movementId);
    }
    return _CustomWorkoutRoutine(
      id: id,
      name: name,
      description: description,
      itemIds: ids,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'itemIds': itemIds,
  };
}

String _validatedRoutineText(
  Object? value,
  String field,
  int maxLength, {
  bool allowEmpty = false,
}) {
  if (value is! String || value != value.trim()) {
    throw FormatException('Invalid custom routine $field.');
  }
  if ((!allowEmpty && value.isEmpty) || value.length > maxLength) {
    throw FormatException('Invalid custom routine $field.');
  }
  if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw FormatException('Invalid custom routine $field.');
  }
  return value;
}

class _MyWorkoutRoutinesView extends StatelessWidget {
  const _MyWorkoutRoutinesView({
    required this.items,
    required this.savedItems,
    required this.routines,
    required this.mediaCache,
    required this.online,
    required this.isLocked,
    required this.onOpen,
    required this.onToggleSaved,
    required this.onCreate,
    required this.onDelete,
    required this.onComplete,
  });

  final List<WellnessContentItem> items;
  final List<WellnessContentItem> savedItems;
  final List<_CustomWorkoutRoutine> routines;
  final WellnessMediaCache mediaCache;
  final bool online;
  final bool Function(WellnessContentItem item) isLocked;
  final ValueChanged<WellnessContentItem> onOpen, onToggleSaved;
  final VoidCallback onCreate;
  final ValueChanged<_CustomWorkoutRoutine>? onDelete;
  final Future<void> Function(
    _CustomWorkoutRoutine routine,
    List<WellnessContentItem> acceptedItems,
  )
  onComplete;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final item in items) item.id: item};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (routines.isNotEmpty)
          for (final routine in routines) ...[
            _CustomRoutineCard(
              routine: routine,
              trustedItems: items,
              items: routine.itemIds
                  .map((id) => byId[id])
                  .whereType<WellnessContentItem>()
                  .toList(growable: false),
              onDelete: onDelete == null ? null : () => onDelete!(routine),
              onComplete: (accepted) => onComplete(routine, accepted),
            ),
            const SizedBox(height: 14),
          ],
        if (savedItems.isNotEmpty) ...[
          Text(
            _copy(context, 'Saved routines', 'الروتينات المحفوظة'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          for (final item in savedItems) ...[
            _WorkoutRoutineCard(
              item: item,
              saved: true,
              locked: isLocked(item),
              mediaCache: mediaCache,
              online: online,
              onToggleSaved: () => onToggleSaved(item),
              onOpen: () => onOpen(item),
            ),
            const SizedBox(height: 18),
          ],
        ],
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text(
                _copy(
                  context,
                  'Track reps, sets, and weights',
                  'تتبّع التكرارات والمجموعات والأوزان',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                _copy(
                  context,
                  'Create a library of multi-exercise routines based on your training plan.',
                  'أنشئ مكتبة روتينات متعددة التمارين تناسب خطتك التدريبية.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('build-custom-routine'),
                  onPressed: onCreate,
                  child: Text(_copy(context, 'Build routine', 'بناء روتين')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomRoutineCard extends StatelessWidget {
  const _CustomRoutineCard({
    required this.routine,
    required this.items,
    required this.trustedItems,
    required this.onDelete,
    required this.onComplete,
  });

  final _CustomWorkoutRoutine routine;
  final List<WellnessContentItem> items;
  final List<WellnessContentItem> trustedItems;
  final VoidCallback? onDelete;
  final Future<void> Function(List<WellnessContentItem>) onComplete;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final item in trustedItems) item.id: item};
    final mapping = validateWorkoutRoutineMapping(
      requestedMovementIds: routine.itemIds,
      trustedMovementIds: byId.keys.toSet(),
    );
    final acceptedItems = mapping.acceptedMovementIds
        .map((id) => byId[id])
        .whereType<WellnessContentItem>()
        .toList(growable: false);
    final languageCode = Localizations.localeOf(context).languageCode;
    final minutes = items.fold<int>(
      0,
      (sum, item) =>
          sum +
          (item.durationMinutes ?? ((item.durationSeconds ?? 0) / 60).ceil()),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    routine.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                PopupMenuButton<void>(
                  enabled: onDelete != null,
                  itemBuilder: (_) => [
                    PopupMenuItem<void>(
                      onTap: onDelete,
                      child: Text(
                        _copy(context, 'Delete routine', 'حذف الروتين'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (routine.description.isNotEmpty) Text(routine.description),
            const SizedBox(height: 10),
            Text(
              items.map((item) => item.title).join(' • '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!mapping.isComplete) ...[
              const SizedBox(height: 10),
              Text(
                '${workoutRoutineCopy(languageCode, 'movementsUnavailable')}: '
                '${mapping.unavailableMovementIds.length}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _RoutineMetric(
                    value: '${items.length}',
                    label: _copy(context, 'Exercises', 'تمارين'),
                  ),
                ),
                Expanded(
                  child: _RoutineMetric(
                    value: minutes == 0 ? '—' : '$minutes',
                    label: _copy(context, 'Est. duration', 'المدة المقدّرة'),
                  ),
                ),
                Expanded(
                  child: _RoutineMetric(
                    value: '—',
                    label: _copy(context, 'Est. calories', 'السعرات المقدّرة'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: ValueKey('complete-custom-routine-${routine.id}'),
                onPressed: mapping.canComplete
                    ? () async {
                        try {
                          await onComplete(acceptedItems);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                workoutRoutineCopy(
                                  languageCode,
                                  'routineCompleted',
                                ),
                              ),
                            ),
                          );
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                workoutRoutineCopy(
                                  languageCode,
                                  'noAcceptedMovements',
                                ),
                              ),
                            ),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.add_task_rounded),
                label: Text(
                  workoutRoutineCopy(languageCode, 'completeRoutine'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineMetric extends StatelessWidget {
  const _RoutineMetric({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _CustomWorkoutRoutineBuilder extends StatefulWidget {
  const _CustomWorkoutRoutineBuilder({
    required this.items,
    required this.onSave,
  });
  final List<WellnessContentItem> items;
  final Future<bool> Function(_CustomWorkoutRoutine routine) onSave;
  @override
  State<_CustomWorkoutRoutineBuilder> createState() =>
      _CustomWorkoutRoutineBuilderState();
}

class _CustomWorkoutRoutineBuilderState
    extends State<_CustomWorkoutRoutineBuilder> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _name.text.trim().isNotEmpty && _selected.isNotEmpty;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          leading: TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(_copy(context, 'Cancel', 'إلغاء')),
          ),
          leadingWidth: 92,
          title: Text(_copy(context, 'Build routine', 'بناء روتين')),
          actions: [
            TextButton(
              onPressed: canSave && !_saving ? _save : null,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_copy(context, 'Save', 'حفظ')),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _name,
              enabled: !_saving,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _copy(context, 'Routine name', 'اسم الروتين'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              enabled: !_saving,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: _copy(
                  context,
                  'Description or notes',
                  'الوصف أو الملاحظات',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _copy(context, 'Add exercises', 'إضافة تمارين'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final item in widget.items)
              CheckboxListTile(
                value: _selected.contains(item.id),
                onChanged: _saving
                    ? null
                    : (selected) => setState(
                        () => selected == true
                            ? _selected.add(item.id)
                            : _selected.remove(item.id),
                      ),
                title: Text(item.title),
                subtitle: Text(
                  item.category ?? _copy(context, 'Workout', 'تمرين'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final routine = _CustomWorkoutRoutine(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      description: _description.text.trim(),
      itemIds: _selected.toList(growable: false),
    );
    final saved = await widget.onSave(routine);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }
}
