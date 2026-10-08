import 'dart:convert';

import '../../../data/database/app_database.dart';
import '../../../data/database/date_keys.dart';
import '../../../data/repositories/daily_log_repository.dart';
import '../../../data/repositories/weight_repository.dart';
import '../../wellness/domain/exercise_energy_engine.dart';
import 'coach_activity_catalog.dart';
import 'coach_health_adapter.dart';

typedef CoachActivityDailyLogRestorer =
    Future<void> Function({required DateTime date, required DailyLog? prior});

/// Uses the existing daily-log mutation inside the native Coach transaction.
/// Confirmation, operation identity, durable replay, and Undo authorization
/// belong to that native boundary; this adapter creates no second journal.
final class CoachActivityCommandAdapter implements CoachHealthCommandAdapter {
  const CoachActivityCommandAdapter({
    required this.dailyLogs,
    required this.restoreDailyLog,
    this.weights,
  });

  final DailyLogRepository dailyLogs;
  final CoachActivityDailyLogRestorer restoreDailyLog;
  final WeightRepository? weights;

  @override
  bool supports(String toolId) => toolId == 'log_exercise';

  @override
  Future<Map<String, Object?>> resolve({
    required String toolId,
    required String operationId,
    required Map<String, Object?> arguments,
    required DateTime now,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    if (!supports(toolId) ||
        arguments.keys.toSet().difference(const {
          'workoutId',
          'name',
          'minutes',
          'date',
        }).isNotEmpty) {
      throw ArgumentError('Invalid exercise command');
    }
    final workout = coachActivityForExactId(arguments['workoutId']);
    final minutes = arguments['minutes'];
    final name = arguments['name'];
    if (workout == null ||
        minutes is! int ||
        minutes < 5 ||
        minutes > 120 ||
        name != null && name != workout.name && name != workout.nameAr) {
      throw ArgumentError('Use an exact workout and 5–120 whole minutes');
    }
    final today = healthCivilDay(now.toLocal());
    final date = arguments['date'] == null
        ? today
        : parseHealthDay(arguments['date']);
    if (date.isAfter(today)) {
      throw ArgumentError('A completed exercise cannot have a future date');
    }

    // The existing history reader uses recordedAt as the exercise day. A
    // historical date-only entry therefore uses that civil day's midnight;
    // the receipt explicitly retains day precision instead of claiming a time.
    final isToday = date == today;
    final recordedAt = (isToday ? now : date).toUtc().toIso8601String();
    Map<String, Object?>? energyEstimate;
    final weightRepository = weights;
    if (weightRepository != null) {
      final weight = await checkedHealthAwait(
        () => weightRepository.getForDay(date),
        checkAccess,
      );
      if (weight != null) {
        final estimate = ExerciseEnergyEngine.estimate(
          met: ExerciseEnergyEngine.metFor(
            id: workout.id,
            category: workout.category,
          ),
          weightKg: weight.weight,
          durationMinutes: minutes,
        );
        if (estimate != null) {
          energyEstimate = {
            'source': ExerciseEnergySource.manualEstimate.name,
            'estimatedCaloriesKcal': estimate.kcal,
            'met': estimate.met,
            'weightKg': estimate.weightKg,
            'weightDay': weight.dayKey,
            'weightEntryUuid': weight.uuid,
            'weightRevision': weight.revision,
            'affectsCalorieBudget': false,
          };
        }
      }
    }
    checkAccess();
    return _activityFreeze({
          'healthToolId': toolId,
          'operationId': operationId,
          'date': dayKeyFor(date),
          'workoutId': workout.id,
          'name': workout.name,
          'nameAr': workout.nameAr,
          'minutes': minutes,
          'recordedAt': recordedAt,
          'timePrecision': isToday ? 'recordedAt' : 'day',
          'energyEstimate': energyEstimate,
        })
        as Map<String, Object?>;
  }

  @override
  Future<Map<String, Object?>> snapshot({
    required Map<String, Object?> resolved,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    final date = _activityDate(resolved);
    final log = await checkedHealthAwait(
      () => dailyLogs.getForDay(date),
      checkAccess,
    );
    final entry = _activityEntry(resolved);
    var matches = 0;
    for (final line in const LineSplitter().convert(log?.exerciseNotes ?? '')) {
      try {
        if (_activitySame(jsonDecode(line), entry)) matches += 1;
      } on FormatException {
        // Existing free-form history is preserved, never interpreted as data.
      }
    }
    return _activityFreeze({
          // Full identity and all fields are needed for lossless Undo and to
          // refuse compensation after another editor changes this same row.
          'dailyLog': log?.toJson(),
          'receipt': {
            'date': dayKeyFor(date),
            'dailyLogUuid': log?.uuid,
            'workoutId': entry['id'],
            'name': entry['name'],
            'minutes': entry['minutes'],
            'recordedAt': entry['recordedAt'],
            'timePrecision': resolved['timePrecision'],
            'matchingEntries': matches,
            'recorded': matches > 0,
            'energyEstimate': resolved['energyEstimate'],
            'affectsCalorieBudget': false,
          },
        })
        as Map<String, Object?>;
  }

  @override
  Future<void> apply({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    final current = await checkedHealthAwait(
      () => snapshot(resolved: resolved, checkAccess: checkAccess),
      checkAccess,
    );
    if (!_activitySame(current, before)) {
      throw StateError('Exercise proposal is stale');
    }
    final date = _activityDate(resolved);
    final prior = _activityLog(before);
    if (prior?.lifecycleState == 'closed' || prior?.closedAt != null) {
      throw StateError('Reopen this day before logging exercise');
    }
    final encoded = jsonEncode(_activityEntry(resolved));
    await checkedHealthAwait(
      () =>
          dailyLogs.appendExerciseNotes(date: date, encodedEntries: [encoded]),
      checkAccess,
    );
    final saved = await checkedHealthAwait(
      () => dailyLogs.getForDay(date),
      checkAccess,
    );
    final oldNotes = prior?.exerciseNotes?.trim();
    final expectedNotes = oldNotes == null || oldNotes.isEmpty
        ? encoded
        : '$oldNotes\n$encoded';
    if (saved == null || saved.exerciseNotes != expectedNotes) {
      throw StateError('Exercise readback does not match the accepted entry');
    }
    if (prior != null) {
      Map<String, Object?> preserved(DailyLog log) => {...log.toJson()}
        ..remove('exerciseNotes')
        ..remove('updatedAt');
      if (!_activitySame(preserved(prior), preserved(saved))) {
        throw StateError('Exercise write changed an unrelated daily-log field');
      }
    }
  }

  @override
  Future<void> compensate({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    final current = await checkedHealthAwait(
      () => snapshot(resolved: resolved, checkAccess: checkAccess),
      checkAccess,
    );
    if (!_activitySame(current, after)) {
      throw StateError('The exercise day changed after this operation');
    }
    final date = _activityDate(resolved);
    final prior = _activityLog(before);
    if (prior != null && prior.dayKey != dayKeyFor(date)) {
      throw StateError('The exercise snapshot belongs to another day');
    }
    await checkedHealthAwait(
      () => restoreDailyLog(date: date, prior: prior),
      checkAccess,
    );
    final restored = await checkedHealthAwait(
      () => dailyLogs.getForDay(date),
      checkAccess,
    );
    if (!_activitySame(restored?.toJson(), prior?.toJson())) {
      throw StateError('Exercise compensation readback failed');
    }
  }
}

DateTime _activityDate(Map<String, Object?> resolved) {
  if (resolved['healthToolId'] != 'log_exercise') {
    throw ArgumentError('Invalid resolved exercise tool');
  }
  return parseHealthDay(resolved['date']);
}

Map<String, Object?> _activityEntry(Map<String, Object?> resolved) {
  final workout = coachActivityForExactId(resolved['workoutId']);
  final minutes = resolved['minutes'];
  final recordedAt = resolved['recordedAt'];
  if (workout == null ||
      resolved['name'] != workout.name ||
      minutes is! int ||
      minutes < 5 ||
      minutes > 120 ||
      recordedAt is! String ||
      DateTime.tryParse(recordedAt) == null) {
    throw ArgumentError('Invalid resolved exercise entry');
  }
  return {
    'id': workout.id,
    'name': workout.name,
    'minutes': minutes,
    'recordedAt': recordedAt,
  };
}

DailyLog? _activityLog(Map<String, Object?> snapshot) {
  if (!snapshot.containsKey('dailyLog')) {
    throw StateError('Missing daily-log snapshot');
  }
  final row = snapshot['dailyLog'];
  return row == null
      ? null
      : DailyLog.fromJson(Map<String, dynamic>.from(row as Map));
}

Object? _activityFreeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _activityFreeze(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_activityFreeze));
  }
  return value;
}

bool _activitySame(Object? first, Object? second) {
  Object? canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) return value.map(canonical).toList(growable: false);
    return value;
  }

  return jsonEncode(canonical(first)) == jsonEncode(canonical(second));
}
