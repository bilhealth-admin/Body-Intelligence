import '../../../data/database/app_database.dart';
import '../../connected_health/connected_health_model.dart';
import '../../global_platform/core/global_platform_core.dart';
import '../../global_platform/health_data/unified_health_data_integration.dart';

final class SleepInsightNight {
  const SleepInsightNight({
    required this.date,
    required this.sleepHours,
    this.nativeSignal,
  });

  final DateTime date;
  final double sleepHours;
  final ConnectedHealthSignalView? nativeSignal;
}

final class SleepInsightsProjection {
  SleepInsightsProjection({
    required Iterable<SleepInsightNight> nights,
    required this.hasVerifiedConnection,
    required this.historyIncomplete,
    required this.cached,
  }) : nights = List.unmodifiable(nights);

  final List<SleepInsightNight> nights;
  final bool hasVerifiedConnection;
  final bool historyIncomplete;
  final bool cached;
  SleepInsightNight? get latest => nights.isEmpty ? null : nights.last;
  double? get average => nights.isEmpty
      ? null
      : nights.fold<double>(0, (sum, row) => sum + row.sleepHours) /
            nights.length;
}

/// Read-only presentation of already aggregated, consented provider evidence.
/// Native stage/overlap arithmetic remains in aggregateConnectedSleepSignals.
/// This helper never reads a store, requests native data, or grants authority.
SleepInsightsProjection projectSleepInsights({
  required ConnectedHealthSnapshot? native,
  required Iterable<DailyLog> manualRows,
  required DateTime now,
  required int windowDays,
}) {
  if (windowDays != 7 && windowDays != 30) {
    throw ArgumentError.value(windowDays, 'windowDays');
  }
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final first = DateTime(local.year, local.month, local.day - windowDays + 1);
  bool inWindow(DateTime day) => !day.isBefore(first) && !day.isAfter(today);
  final connected =
      native?.deviceVerified == true &&
      native?.lastSyncAt != null &&
      native?.platformSource?.trim().isNotEmpty == true &&
      !const {
        ConnectedHealthStatus.unavailable,
        ConnectedHealthStatus.updateRequired,
        ConnectedHealthStatus.permissionRequired,
        ConnectedHealthStatus.permissionDenied,
      }.contains(native?.status);
  final bySourceNight = <String, ConnectedHealthSignalView>{};
  if (connected) {
    void add(ConnectedHealthSignalView row, {required bool fallback}) {
      final day = _nativeNight(row, now);
      if (day == null || !inWindow(day)) return;
      final key = '${row.source}:${day.toIso8601String()}';
      final previous = bySourceNight[key];
      // The history entry already represents this source/night. A shorter
      // representative preview must not replace it or become another night.
      if (fallback && previous != null) return;
      bySourceNight[key] = previous == null ? row : _prefer(previous, row);
    }

    for (final row in native!.signalHistory) {
      add(row, fallback: false);
    }
    for (final row in native.signals) {
      add(row, fallback: true);
    }
  }
  final selected = <DateTime, ConnectedHealthSignalView>{};
  final nativeRows = bySourceNight.values.toList()
    ..sort((a, b) => a.source.compareTo(b.source));
  for (final row in nativeRows) {
    final day = _nativeNight(row, now)!;
    final previous = selected[day];
    selected[day] = previous == null ? row : _prefer(previous, row);
  }
  final nights = <DateTime, SleepInsightNight>{
    for (final entry in selected.entries)
      entry.key: SleepInsightNight(
        date: entry.key,
        sleepHours: entry.value.value,
        nativeSignal: entry.value,
      ),
  };
  final manualByDay = <DateTime, DailyLog>{};
  for (final row in manualRows) {
    final hours = row.sleepHours;
    final at = row.date.toLocal();
    final day = DateTime(at.year, at.month, at.day);
    // sleepHours is nullable without a default. Explicit zero is a saved
    // manual value; a day started for water/food has null and stays missing.
    if (hours == null ||
        !hours.isFinite ||
        hours < 0 ||
        hours > 14 ||
        !inWindow(day)) {
      continue;
    }
    final previous = manualByDay[day];
    if (previous == null || !row.updatedAt.isBefore(previous.updatedAt)) {
      manualByDay[day] = row;
    }
  }
  for (final entry in manualByDay.entries) {
    nights[entry.key] = SleepInsightNight(
      date: entry.key,
      sleepHours: entry.value.sleepHours!,
    );
  }
  final result = nights.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return SleepInsightsProjection(
    nights: result,
    hasVerifiedConnection: connected,
    historyIncomplete:
        connected && native?.failureCode == 'health_history_sync_incomplete',
    cached: connected && native?.status == ConnectedHealthStatus.degraded,
  );
}

DateTime? _nativeNight(ConnectedHealthSignalView row, DateTime now) {
  if (row.key != 'sleep' ||
      row.unit != 'h' ||
      !row.value.isFinite ||
      row.value <= 0 ||
      row.value > 24 ||
      !row.confidence.isFinite ||
      row.confidence <= 0 ||
      row.source.trim().isEmpty ||
      row.observedAt.isAfter(now)) {
    return null;
  }
  final rawEnd = row.attributes['endedAt'];
  if (rawEnd == null) {
    // Older verified session totals lack an end edge. Keep their observed
    // calendar date; do not invent a sleep stage or a different wake date.
    final at = row.observedAt.toLocal();
    return DateTime(at.year, at.month, at.day);
  }
  final end = DateTime.tryParse(rawEnd.toString());
  if (end == null || !end.isAfter(row.observedAt) || end.isAfter(now)) {
    return null;
  }
  // Same noon-to-noon night boundary as the reviewed native aggregation,
  // including an end exactly at noon. Calendar arithmetic preserves DST days.
  final at = end.subtract(const Duration(microseconds: 1)).toLocal();
  return DateTime(at.year, at.month, at.day + (at.hour < 12 ? 0 : 1));
}

ConnectedHealthSignalView _prefer(
  ConnectedHealthSignalView current,
  ConnectedHealthSignalView candidate,
) {
  // Same temporary, non-persisted adapter used by compact history views.
  // The resolver compares original confidence/recency/source, not this label.
  GlobalHealthSignal comparison(ConnectedHealthSignalView row) =>
      GlobalHealthSignal(
        key: row.key,
        canonicalValue: row.value,
        canonicalUnit: row.unit,
        provenance: GlobalProvenance(
          providerId: 'history.view',
          sourceId: row.source,
          recordId: '${row.source}:${row.observedAt.toUtc().toIso8601String()}',
          observedAt: row.observedAt,
          confidence: row.confidence,
        ),
        attributes: row.attributes,
      );
  final a = comparison(current), b = comparison(candidate);
  return identical(HealthSignalConflictResolver.prefer(a, b), b)
      ? candidate
      : current;
}
