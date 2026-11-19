part of 'wellness_tools_pages.dart';

extension _CompletedFastingHistory on _FastingTimerPageState {
  String _historyText(String key) =>
      FastingHistoryRuntimeCopy.text(key, Localizations.localeOf(context));

  List<Widget> _completedHistory(AsyncValue<FastingHistorySnapshot> value) {
    if (value.hasError || value.asData?.value.readable == false) {
      return [
        TextButton.icon(
          key: const Key('fasting-history-retry'),
          onPressed: busy
              ? null
              : () => ref.invalidate(fastingHistorySnapshotProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_historyText(FastingHistoryRuntimeCopy.unavailable)),
        ),
      ];
    }
    final records =
        value.asData?.value.records ?? const <FastingHistoryRecord>[];
    if (records.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      Text(
        tr('Intermittent fasting history', 'سجل الصيام المتقطع'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      for (final record in records.take(10))
        ListTile(
          key: ValueKey('fasting-history-row-${record.occurrence}'),
          leading: Icon(
            record.entry.reachedTarget
                ? Icons.check_circle_outline_rounded
                : Icons.history_rounded,
          ),
          title: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(clock(record.entry.duration)),
          ),
          subtitle: Text(
            '${MaterialLocalizations.of(context).formatMediumDate(record.entry.startedAt.toLocal())} · '
            '${tr('Target', 'الهدف')} ${record.entry.targetHours}h · '
            '${record.entry.reachedTarget ? tr('Reached', 'تم بلوغه') : tr('Ended early', 'انتهى مبكرًا')}',
          ),
          trailing: IconButton(
            key: ValueKey('fasting-history-delete-${record.occurrence}'),
            tooltip: _historyText(FastingHistoryRuntimeCopy.deleteRecord),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            onPressed: busy ? null : () => _deleteCompletedFast(record),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ),
    ];
  }

  Future<void> _deleteCompletedFast(FastingHistoryRecord record) async {
    if (busy) return;
    final repository = ref.read(fastingHistoryRepositoryProvider);
    final visit = ref.read(fastingHistoryOwnerVisitProvider);
    bool current() =>
        mounted &&
        identical(visit, ref.read(fastingHistoryOwnerVisitProvider)) &&
        identical(repository, ref.read(fastingHistoryRepositoryProvider));
    if (!repository.owns(record)) return;
    // The dialog route can outlive the page during an account transition.
    final deleteTitle = _historyText(FastingHistoryRuntimeCopy.deleteRecord);
    final confirmation = _historyText(FastingHistoryRuntimeCopy.confirmation);
    final cancelLabel = tr('Cancel', 'إلغاء');
    final deleteLabel = tr('Delete', 'حذف');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => BilPearlMaterialAlertDialog(
        title: Text(deleteTitle),
        content: Text(confirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            key: const Key('fasting-history-confirm-delete'),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(deleteLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !current() || busy) return;
    _updateState(() => busy = true);
    try {
      final next = await repository.delete(record, isCurrent: current);
      if (!mounted || !current()) return;
      if (next == null) {
        _message(_historyText(FastingHistoryRuntimeCopy.changed));
        return;
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _updateState(() => history = [for (final row in next.records) row.entry]);
      ref.invalidate(weeklyReportProvider);
    } on Object {
      if (current()) _message(_historyText(FastingHistoryRuntimeCopy.failed));
    } finally {
      if (current()) _updateState(() => busy = false);
    }
  }
}
