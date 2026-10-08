part of 'health_query_adapter.dart';

final class _HealthConnectedProjection {
  _HealthConnectedProjection({
    required ConnectedHealthSnapshot? snapshot,
    required _HealthQueryWindow window,
    required DateTime now,
    required bool includeSleep,
    required bool includeActivity,
  }) {
    if (snapshot == null ||
        !snapshot.deviceVerified ||
        const {
          ConnectedHealthStatus.unavailable,
          ConnectedHealthStatus.permissionRequired,
          ConnectedHealthStatus.permissionDenied,
          ConnectedHealthStatus.authorizationRequested,
          ConnectedHealthStatus.updateRequired,
        }.contains(snapshot.status)) {
      return;
    }
    accepted = true;
    bool valid(ConnectedHealthSignalView signal) =>
        signal.value.isFinite &&
        signal.value >= 0 &&
        signal.confidence.isFinite &&
        signal.confidence > 0 &&
        !signal.observedAt.isAfter(now) &&
        window.contains(_connectedSignalDay(signal));

    if (includeSleep) {
      for (final signal in [...snapshot.signalHistory, ...snapshot.signals]) {
        if (signal.key != 'sleep' ||
            signal.unit != 'h' ||
            signal.value > 24 ||
            !valid(signal)) {
          continue;
        }
        final key = _connectedSignalDay(signal);
        final previous = sleep[key];
        if (previous == null ||
            !signal.observedAt.isBefore(previous.observedAt)) {
          sleep[key] = signal;
        }
      }
    }
    if (!includeActivity) return;
    final history = snapshot.stepHistory
        .where((s) => s.key == 'steps' && s.unit == 'count' && valid(s))
        .toList(growable: false);
    final signals = snapshot.signals
        .where((s) => s.key == 'steps' && s.unit == 'count' && valid(s))
        .toList(growable: false);
    final stepSnapshot = snapshot.copyWith(
      stepHistory: history,
      signals: signals,
    );
    // Reuse the dashboard's missing-is-absent aggregation and history/latest
    // deduplication. Its public horizon is 30 days, so two bounded endpoint
    // projections cover the permitted 31-day query without new arithmetic.
    final totals = {
      ...connectedHealthDailyStepTotals(stepSnapshot, window.days.first),
      ...connectedHealthDailyStepTotals(stepSnapshot, window.days.last),
    };
    for (final entry in totals.entries) {
      final key = dayKeyFor(entry.key);
      if (!window.contains(key)) continue;
      steps[key] = entry.value;
      final recorded = history
          .where((signal) => dayKeyFor(signal.observedAt) == key)
          .toList(growable: false);
      final latest = signals.where(
        (signal) => dayKeyFor(signal.observedAt) == key,
      );
      final counted = recorded.isNotEmpty
          ? recorded
          : history.isEmpty
          ? latest
          : latest.take(1);
      final sources = <String>[];
      for (final signal in counted) {
        if (sources.length < 4 && !sources.contains(signal.source)) {
          sources.add(signal.source);
        }
      }
      stepSources[key] = sources;
    }
    // Keep the existing native-daily versus sample-sum policy. Latest values
    // and retained daily summaries are never added together in a new formula.
    final projected = compactConnectedHistoryViews([
      for (final signal in [...snapshot.signalHistory, ...snapshot.signals])
        if (signal.key == 'activeEnergy' &&
            signal.unit == 'kcal' &&
            valid(signal))
          signal,
    ], now);
    for (final signal in projected) {
      final key = _connectedSignalDay(signal);
      if (window.contains(key)) energy[key] = signal;
    }
  }

  bool accepted = false;
  final sleep = <String, ConnectedHealthSignalView>{};
  final steps = <String, double>{};
  final stepSources = <String, List<String>>{};
  final energy = <String, ConnectedHealthSignalView>{};
}

String _connectedSignalDay(ConnectedHealthSignalView signal) {
  final stored = signal.attributes['historyLocalDay'];
  if (stored is String && connectedHistoryDate(stored) != null) return stored;
  if (signal.key == 'sleep') {
    final end = DateTime.tryParse(
      signal.attributes['endedAt']?.toString() ?? '',
    );
    if (end != null) return dayKeyFor(end);
  }
  return dayKeyFor(signal.observedAt);
}

Map<String, Object?> _connectedSignalJson(
  ConnectedHealthSignalView signal,
  ConnectedHealthSnapshot snapshot,
  String day,
) => {
  'value': signal.value,
  'unit': signal.unit,
  'source': 'connected_health',
  'deviceSource': signal.source,
  'deviceVerified': snapshot.deviceVerified,
  'confidence': signal.confidence,
  'localDay': day,
  'observedAtUtc': signal.observedAt.toUtc().toIso8601String(),
  'offsetMinutesAtRead': signal.observedAt.toLocal().timeZoneOffset.inMinutes,
  'lastSyncAtUtc': snapshot.lastSyncAt?.toUtc().toIso8601String(),
  for (final key in [
    'startedAt',
    'endedAt',
    'historyLocalDay',
    'historyProjection',
    'historyAggregation',
  ])
    if (signal.attributes[key] case final String value)
      key: String.fromCharCodes(value.runes.take(128)),
};

final class _HealthExerciseEvidence {
  const _HealthExerciseEvidence({
    required this.hasStoredNotes,
    required this.records,
    required this.truncated,
    required this.unstructured,
  });
  final bool hasStoredNotes;
  final List<Map<String, Object?>> records;
  final bool truncated;
  final bool unstructured;
}

_HealthExerciseEvidence _readExerciseEvidence(
  String? notes, {
  required int budget,
}) {
  if (notes == null || notes.trim().isEmpty) {
    return const _HealthExerciseEvidence(
      hasStoredNotes: false,
      records: [],
      truncated: false,
      unstructured: false,
    );
  }
  final records = <Map<String, Object?>>[];
  var unstructured = false;
  var truncated = false;
  var scanned = 0;
  for (final line in const LineSplitter().convert(notes)) {
    if (line.trim().isEmpty) continue;
    // Historical free text remains in its repository. It is not copied into
    // a health-model payload, and excessive note data is not fully parsed.
    if (++scanned > 256) {
      truncated = true;
      break;
    }
    if (line.length > 8192) {
      unstructured = true;
      continue;
    }
    try {
      final value = jsonDecode(line);
      if (value is! Map<String, dynamic>) {
        unstructured = true;
        continue;
      }
      final id = value['id'];
      final title = value['name'] ?? value['title'];
      final at = value['recordedAt'];
      final timestamp = at is String ? DateTime.tryParse(at) : null;
      final minutes = value['minutes'] ?? value['durationMinutes'];
      final kind = value['kind'];
      final routine =
          kind == 'trusted_workout_routine' || kind == 'custom_workout_routine';
      if (id is! String ||
          id.trim().isEmpty ||
          id.length > 128 ||
          title is! String ||
          title.trim().isEmpty ||
          title.length > 200 ||
          timestamp == null ||
          (minutes != null &&
              (minutes is! int || minutes < 1 || minutes > 1440)) ||
          (!routine && minutes == null)) {
        unstructured = true;
        continue;
      }
      if (records.length >= budget) {
        truncated = true;
        break;
      }
      records.add({
        'id': id,
        'name': title,
        'minutes': minutes,
        'recordedAtUtc': timestamp.toUtc().toIso8601String(),
        'source': 'persisted_exercise_log',
        if (routine) 'kind': kind,
      });
    } on FormatException {
      unstructured = true;
    }
  }
  return _HealthExerciseEvidence(
    hasStoredNotes: true,
    records: records,
    truncated: truncated,
    unstructured: unstructured,
  );
}
