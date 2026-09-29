import '../global_platform/core/global_platform_core.dart';

/// Presentation projection only. Raw native records, permissions, anchors and
/// the live watch values are deliberately outside this module.
final class ConnectedDailyHistoryInput {
  const ConnectedDailyHistoryInput({
    required this.samples,
    required this.asOf,
    this.nativeTotals = const [],
    this.retained = const [],
    this.selectedEvidence = const [],
  });
  final List<GlobalHealthSignal> samples;
  final DateTime asOf;
  final List<GlobalHealthSignal> nativeTotals;
  final List<GlobalHealthSignal> retained;
  final List<GlobalHealthSignal> selectedEvidence;
}

String connectedHistoryDay(DateTime at) {
  final d = at.toLocal();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

DateTime? connectedHistoryDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final date = DateTime.tryParse(value);
  return date != null && connectedHistoryDay(date) == value ? date : null;
}

bool connectedHistoryDayComplete(String day, DateTime asOf) {
  final date = connectedHistoryDate(day);
  // Calendar arithmetic, not +24 hours: local DST days can be 23/25 hours.
  return date != null &&
      !DateTime(date.year, date.month, date.day + 1).isAfter(asOf.toLocal());
}

/// One value per metric/calendar day. Native daily energy is authoritative:
/// never add cumulative totals together or add raw samples to a daily total.
/// Heart rate is a sample mean, not a resting or continuous time average.
List<GlobalHealthSignal> projectConnectedDailyHistory(
  ConnectedDailyHistoryInput input,
) {
  const metrics = {'heartRate', 'restingHeartRate', 'activeEnergy'};
  final local = input.asOf.toLocal();
  final cutoff = DateTime(local.year, local.month, local.day - 365);
  final today = DateTime(local.year, local.month, local.day);
  final output = <String, GlobalHealthSignal>{};
  final samples = <String, GlobalHealthSignal>{};
  final native = <String, GlobalHealthSignal>{};
  final selectedSources = <String, String>{};
  String source(GlobalHealthSignal s) =>
      '${s.provenance.providerId}:${s.provenance.sourceId}';
  String slot(GlobalHealthSignal s) =>
      '${s.key}:${s.provenance.observedAt.millisecondsSinceEpoch ~/ 60000}';
  String dayOf(GlobalHealthSignal s) {
    final stored = s.attributes['historyLocalDay']?.toString();
    return connectedHistoryDate(stored) == null
        ? connectedHistoryDay(s.provenance.observedAt)
        : stored!;
  }

  String key(GlobalHealthSignal s) => '${s.key}:${dayOf(s)}';
  bool valid(GlobalHealthSignal s) {
    final day = connectedHistoryDate(dayOf(s));
    if (s.deleted ||
        !s.canonicalValue.isFinite ||
        s.provenance.confidence <= 0 ||
        s.provenance.observedAt.isAfter(input.asOf) ||
        day == null ||
        day.isBefore(cutoff) ||
        day.isAfter(today)) {
      return false;
    }
    if (s.key == 'activeEnergy') {
      return s.canonicalUnit == 'kcal' && s.canonicalValue >= 0;
    }
    if (s.key == 'heartRate' || s.key == 'restingHeartRate') {
      return s.canonicalUnit == 'count/min' &&
          s.canonicalValue >= 20 &&
          s.canonicalValue <= 300;
    }
    return s.key == 'sleep';
  }

  for (final s in input.selectedEvidence) {
    if (metrics.contains(s.key)) selectedSources[slot(s)] = source(s);
  }
  // Retained summaries fill days outside the OS aggregate window. Fresh raw
  // samples replace a summary; a summary never enters its own arithmetic.
  for (final s in [...input.retained, ...input.samples]) {
    if (!valid(s)) continue;
    if (s.key == 'sleep') {
      output[s.identity] = s;
      continue;
    }
    if (!metrics.contains(s.key)) continue;
    if (s.attributes['historyProjection'] == 'daily_v1') {
      output[key(s)] = s;
    } else if (s.key == 'activeEnergy' &&
        const {'native_daily', 'daily'}.contains(s.attributes['aggregation'])) {
      final previous = native[key(s)];
      if (previous == null ||
          !s.provenance.observedAt.isBefore(previous.provenance.observedAt)) {
        native[key(s)] = s;
      }
    } else {
      samples[s.identity] = s;
    }
  }
  // Newly queried same-timestamp corrections win, even when the value falls.
  for (final s in input.nativeTotals) {
    if (s.key == 'activeEnergy' &&
        valid(s) &&
        s.attributes['aggregation'] == 'native_daily') {
      final previous = native[key(s)];
      if (previous == null ||
          !s.provenance.observedAt.isBefore(previous.provenance.observedAt)) {
        native[key(s)] = s;
      }
    }
  }
  final groups = <String, List<GlobalHealthSignal>>{};
  for (final s in samples.values) {
    final selected = selectedSources[slot(s)];
    if (selected != null && selected != source(s)) continue;
    (groups[key(s)] ??= []).add(s);
  }
  for (final entry in groups.entries) {
    final rows = entry.value
      ..sort((a, b) {
        final time = a.provenance.observedAt.compareTo(b.provenance.observedAt);
        return time != 0 ? time : a.identity.compareTo(b.identity);
      });
    final template = rows.last;
    final day = dayOf(template);
    final energy = template.key == 'activeEnergy';
    if (energy && native.containsKey(entry.key)) continue;
    if (energy &&
        output[entry.key]?.attributes['historyAggregation'] == 'native_daily') {
      continue;
    }
    final sum = rows.fold<double>(0, (v, s) => v + s.canonicalValue);
    final value = energy ? sum : sum / rows.length;
    if (!value.isFinite) continue;
    final peak = rows.reduce(
      (a, b) => b.canonicalValue > a.canonicalValue ? b : a,
    );
    final above = rows
        .where((s) => s.key == 'heartRate' && s.canonicalValue > 100)
        .toList();
    output[entry.key] = _dailySignal(template, day, value, {
      'historyAggregation': energy
          ? 'imported_interval_sum'
          : 'recorded_sample_mean',
      'sampleCount': rows.length,
      'sourceSessionIds': <String>{
        for (final s in rows) ...[
          s.provenance.recordId,
          if (s.attributes['parentRecordId'] case final String parent) parent,
        ],
      }.toList(growable: false),
      if (!energy) ...{
        'dailyMinimum': rows
            .map((s) => s.canonicalValue)
            .reduce((a, b) => a < b ? a : b),
        'dailyMaximum': peak.canonicalValue,
        'peakObservedAt': peak.provenance.observedAt.toUtc().toIso8601String(),
        'peakOffsetMinutes': peak.provenance.observedAt
            .toLocal()
            .timeZoneOffset
            .inMinutes,
      },
      if (template.key == 'heartRate') ...{
        'thresholdBpm': 100,
        'aboveThresholdCount': above.length,
        if (above.isNotEmpty) ...{
          'firstAboveThresholdAt': above.first.provenance.observedAt
              .toUtc()
              .toIso8601String(),
          'firstAboveThresholdOffsetMinutes': above.first.provenance.observedAt
              .toLocal()
              .timeZoneOffset
              .inMinutes,
        },
      },
    });
  }
  for (final entry in native.entries) {
    final s = entry.value;
    output[entry.key] = _dailySignal(s, dayOf(s), s.canonicalValue, {
      'historyAggregation': 'native_daily',
    });
  }
  final result = output.values.toList()
    ..sort((a, b) {
      final order = dayOf(b).compareTo(dayOf(a));
      return order != 0 ? order : a.key.compareTo(b.key);
    });
  return List.unmodifiable(result);
}

GlobalHealthSignal _dailySignal(
  GlobalHealthSignal template,
  String day,
  double value,
  Map<String, Object?> metadata,
) => GlobalHealthSignal(
  key: template.key,
  canonicalValue: value,
  canonicalUnit: template.canonicalUnit,
  provenance: GlobalProvenance(
    providerId: template.provenance.providerId,
    sourceId: template.provenance.sourceId,
    recordId: 'history:daily:v1:${template.key}:$day',
    observedAt: template.provenance.observedAt,
    confidence: template.provenance.confidence,
    deviceId: template.provenance.deviceId,
    timeZoneId: template.provenance.timeZoneId,
  ),
  attributes: {
    ...template.attributes,
    'historyProjection': 'daily_v1',
    'historyLocalDay': day,
    ...metadata,
  },
);
