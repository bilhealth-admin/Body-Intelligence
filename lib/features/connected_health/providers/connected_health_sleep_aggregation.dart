part of 'connected_health_provider.dart';

/// Converts HealthKit's overlapping in-bed/awake/stage samples into one
/// measured asleep duration per source/night. Android SleepSessionRecord rows
/// already carry a session total with nested stages and pass through unchanged.
/// No stage percentages or missing edges are fabricated.
@visibleForTesting
List<GlobalHealthSignal> aggregateConnectedSleepSignals(
  List<GlobalHealthSignal> records,
) {
  final output = <GlobalHealthSignal>[];
  final stagedByNight = <String, List<GlobalHealthSignal>>{};
  for (final signal in records) {
    if (signal.key != 'sleep') {
      output.add(signal);
      continue;
    }
    final stage = signal.attributes['sleepStage']?.toString();
    if (stage == null || signal.attributes['stages'] is List) {
      output.add(signal);
      continue;
    }
    if (stage == 'inBed' || stage == 'awake' || stage == 'unknown') {
      continue;
    }
    final endedAt = DateTime.tryParse(
      signal.attributes['endedAt']?.toString() ?? '',
    );
    if (endedAt == null || !endedAt.isAfter(signal.provenance.observedAt)) {
      continue;
    }
    final localEnd = endedAt.toLocal();
    final night =
        '${localEnd.year.toString().padLeft(4, '0')}-'
        '${localEnd.month.toString().padLeft(2, '0')}-'
        '${localEnd.day.toString().padLeft(2, '0')}';
    final key =
        '${signal.provenance.providerId}|${signal.provenance.sourceId}|$night';
    stagedByNight.putIfAbsent(key, () => <GlobalHealthSignal>[]).add(signal);
  }

  for (final entry in stagedByNight.entries) {
    final rows = entry.value
      ..sort(
        (a, b) => a.provenance.observedAt.compareTo(b.provenance.observedAt),
      );
    final intervals = <({DateTime start, DateTime end})>[];
    for (final row in rows) {
      final end = DateTime.parse(row.attributes['endedAt']!.toString()).toUtc();
      final start = row.provenance.observedAt.toUtc();
      if (intervals.isEmpty || start.isAfter(intervals.last.end)) {
        intervals.add((start: start, end: end));
      } else if (end.isAfter(intervals.last.end)) {
        intervals[intervals.length - 1] = (
          start: intervals.last.start,
          end: end,
        );
      }
    }
    final hours = intervals.fold<double>(
      0,
      (sum, interval) =>
          sum + interval.end.difference(interval.start).inSeconds / 3600,
    );
    if (!hours.isFinite || hours <= 0 || hours > 24) continue;
    final template = rows.reduce(
      (a, b) =>
          a.provenance.observedAt.isAfter(b.provenance.observedAt) ? a : b,
    );
    final first = intervals.first.start;
    final last = intervals.last.end;
    output.add(
      GlobalHealthSignal(
        key: 'sleep',
        canonicalValue: hours,
        canonicalUnit: 'h',
        provenance: GlobalProvenance(
          providerId: template.provenance.providerId,
          sourceId: template.provenance.sourceId,
          recordId:
              'sleep-night:${entry.key}:${first.microsecondsSinceEpoch}:${last.microsecondsSinceEpoch}',
          observedAt: first,
          confidence: rows
              .map((row) => row.provenance.confidence)
              .reduce((a, b) => a < b ? a : b),
          deviceId: template.provenance.deviceId,
          timeZoneId: template.provenance.timeZoneId,
        ),
        attributes: <String, Object?>{
          'endedAt': last.toIso8601String(),
          'sourceSessionIds': [for (final row in rows) row.provenance.recordId],
          'measuredStages': [
            for (final row in rows) row.attributes['sleepStage'],
          ],
        },
      ),
    );
  }
  return List<GlobalHealthSignal>.unmodifiable(output);
}
