part of 'connected_health_provider.dart';

@visibleForTesting
Set<HealthDataType> connectedHealthReadTypesForPlatform(
  TargetPlatform platform,
) {
  if (platform == TargetPlatform.iOS) return BilHealthScope.read;
  if (platform == TargetPlatform.android) {
    return Set<HealthDataType>.unmodifiable(
      BilHealthScope.read.where(
        (type) => BilHealthScope.healthConnectReadTypeNames.contains(type.name),
      ),
    );
  }
  return const <HealthDataType>{};
}

@visibleForTesting
Set<String> connectedHealthWriteTypeNamesForPlatform(TargetPlatform platform) =>
    switch (platform) {
      TargetPlatform.iOS => BilHealthScope.appleHealthWriteTypeNames,
      TargetPlatform.android => BilHealthScope.healthConnectWriteTypeNames,
      _ => const <String>{},
    };

@visibleForTesting
ConnectedHealthStatus connectedHealthStatusAfterSynchronization({
  required TargetPlatform platform,
  required bool hasVerifiedNativeEvidence,
}) => platform == TargetPlatform.iOS && !hasVerifiedNativeEvidence
    ? ConnectedHealthStatus.authorizationRequested
    : ConnectedHealthStatus.synchronized;

/// Combines selected connected-health step samples into daily totals.
///
/// The evidence graph has already selected one source per minute, so summing
/// this input does not double-count the same minute from Apple Health and
/// Health Connect. The original samples remain in `health_signals`; only the
/// compact daily projection is stored for dashboard rendering.
@visibleForTesting
List<GlobalHealthSignal> aggregateConnectedStepSignals(
  Iterable<GlobalHealthSignal> records,
) {
  final byDay = <String, List<GlobalHealthSignal>>{};
  for (final signal in records) {
    if (signal.key != 'steps' ||
        signal.deleted ||
        signal.canonicalUnit != 'count' ||
        !signal.canonicalValue.isFinite ||
        signal.canonicalValue < 0) {
      continue;
    }
    final local = signal.provenance.observedAt.toLocal();
    final day =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    byDay.putIfAbsent(day, () => <GlobalHealthSignal>[]).add(signal);
  }

  final output = <GlobalHealthSignal>[];
  for (final entry in byDay.entries) {
    final rows = entry.value;
    final template = rows.reduce(
      (a, b) =>
          a.provenance.observedAt.isAfter(b.provenance.observedAt) ? a : b,
    );
    final date = DateTime.tryParse(entry.key);
    if (date == null) continue;
    final total = rows.fold<double>(0, (sum, row) => sum + row.canonicalValue);
    if (!total.isFinite) continue;
    output.add(
      GlobalHealthSignal(
        key: 'steps',
        canonicalValue: total,
        canonicalUnit: 'count',
        provenance: GlobalProvenance(
          providerId: 'bil.connected_health.daily',
          sourceId: template.provenance.sourceId,
          recordId: 'daily:steps:${entry.key}',
          observedAt: DateTime(date.year, date.month, date.day, 12),
          confidence: rows
              .map((row) => row.provenance.confidence)
              .reduce((a, b) => a < b ? a : b),
          deviceId: template.provenance.deviceId,
          timeZoneId: template.provenance.timeZoneId,
        ),
        attributes: <String, Object?>{
          // Daily totals still need the source evidence carried by the native
          // sample. Without it, a valid Apple Watch/Wear OS step total is
          // incorrectly hidden from the watch preview after aggregation.
          ...template.attributes,
          'aggregation': 'daily',
          'date': entry.key,
          'sampleCount': rows.length,
        },
      ),
    );
  }
  output.sort(
    (a, b) => a.provenance.observedAt.compareTo(b.provenance.observedAt),
  );
  return List<GlobalHealthSignal>.unmodifiable(output);
}

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
      // These records describe the bed window or wake time, not sleep.
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
