import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../data/database/app_database.dart';
import '../../../shared/widgets/bil_pearl_feature_welcome.dart';
import '../../../shared/widgets/bil_pearl_material.dart';
import '../domain/daily_exercise_notes_codec.dart';
import '../providers/daily_log_provider.dart';

/// Saved occurrences are separate from the editable, unsaved plain-note draft.
class DailyLoggedWorkoutList extends ConsumerStatefulWidget {
  const DailyLoggedWorkoutList({super.key});

  @override
  ConsumerState<DailyLoggedWorkoutList> createState() =>
      _DailyLoggedWorkoutListState();
}

class _DailyLoggedWorkoutListState
    extends ConsumerState<DailyLoggedWorkoutList> {
  int? _pendingLine;
  bool _writing = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(dailyLogExerciseVisitProvider);
    final record = ref.watch(selectedDailyLogProvider).asData?.value;
    if (record == null) return const SizedBox.shrink();
    final entries = DailyExerciseNotesCodec.decode(
      record.exerciseNotes,
    ).entries;
    return Column(
      children: [
        for (final entry in entries)
          ListTile(
            key: ValueKey(
              'daily-exercise-entry-${record.uuid}-${entry.sourceLineIndex}',
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fitness_center_rounded),
            title: Text(
              entry.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: entry.recordedAt == null
                ? null
                : Text(
                    TimeOfDay.fromDateTime(
                      entry.recordedAt!.toLocal(),
                    ).format(context),
                  ),
            trailing: _writing && _pendingLine == entry.sourceLineIndex
                ? const SizedBox.square(
                    dimension: 20,
                    child: BilFeatureWelcomeStatus(),
                  )
                : IconButton(
                    key: ValueKey(
                      'daily-exercise-remove-${entry.sourceLineIndex}',
                    ),
                    tooltip:
                        '${context.strings.text('Remove')} ${entry.displayName}',
                    onPressed:
                        _pendingLine != null ||
                            record.lifecycleState == 'closed'
                        ? null
                        : () => _remove(record, entry),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
          ),
      ],
    );
  }

  String _entryLabel(DailyStructuredExerciseEntry entry) {
    final recordedAt = entry.recordedAt;
    if (recordedAt == null) return entry.displayName;
    final time = TimeOfDay.fromDateTime(recordedAt.toLocal()).format(context);
    return '${entry.displayName}\n$time';
  }

  Future<void> _remove(
    DailyLog record,
    DailyStructuredExerciseEntry entry,
  ) async {
    if (_pendingLine != null || record.exerciseNotes == null) return;
    final repository = ref.read(dailyLogRepositoryProvider);
    final date = ref.read(selectedLogDateProvider);
    final visit = ref.read(dailyLogExerciseVisitProvider);
    bool current() =>
        mounted &&
        identical(visit, ref.read(dailyLogExerciseVisitProvider)) &&
        identical(repository, ref.read(dailyLogRepositoryProvider)) &&
        DateUtils.isSameDay(date, ref.read(selectedLogDateProvider));
    bool unchanged() {
      if (!current()) return false;
      final latest = ref.read(selectedDailyLogProvider).asData?.value;
      return latest?.uuid == record.uuid &&
          latest?.notes == record.notes &&
          latest?.exerciseNotes == record.exerciseNotes &&
          latest?.lifecycleState != 'closed';
    }

    if (!unchanged()) return;
    setState(() => _pendingLine = entry.sourceLineIndex);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Consumer(
          builder: (context, dialogRef, _) {
            dialogRef.watch(dailyLogExerciseVisitProvider);
            dialogRef.watch(selectedDailyLogProvider);
            final available = unchanged();
            return BilPearlMaterialAlertDialog(
              title: Text(context.strings.text('Remove')),
              content: Text(
                available
                    ? _entryLabel(entry)
                    : context.strings.text(
                        'Your saved data was not changed. Try again.',
                      ),
              ),
              actions: [
                TextButton(
                  key: const Key('daily-exercise-cancel-remove'),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.strings.text('Cancel')),
                ),
                FilledButton(
                  key: const Key('daily-exercise-confirm-remove'),
                  onPressed: available
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: Text(context.strings.text('Remove')),
                ),
              ],
            );
          },
        ),
      );
      if (confirmed != true || !unchanged()) return;
      final replacement = DailyExerciseNotesCodec.removeEntry(
        record.exerciseNotes!,
        entry,
      );
      setState(() => _writing = true);
      await repository.saveNotesAtomically(
        date: date,
        expectedRecordUuid: record.uuid,
        expectedNotes: record.notes,
        expectedExerciseNotes: record.exerciseNotes,
        notes: record.notes,
        exerciseNotes: replacement,
        isCurrent: current,
      );
      if (!mounted || !current()) return;
      ref.invalidate(selectedDailyLogProvider);
    } on Object {
      if (mounted && current()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.text(
                'Your saved data was not changed. Try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingLine = null;
          _writing = false;
        });
      }
    }
  }
}
