import 'dart:convert';

import '../../connected_health/connected_health_daily_history.dart';
import '../../connected_health/connected_health_daily_history_view.dart';
import '../../connected_health/connected_health_model.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/date_keys.dart';
import '../../../data/repositories/body_measurement_repository.dart';
import '../../../data/repositories/daily_log_repository.dart';
import '../../../data/repositories/weight_repository.dart';
import '../../../engine/progress_analysis.dart';
import '../services/coach_catalog_grounding.dart';

part 'health_query_projection.dart';

typedef CoachHealthContentLookup =
    Future<CoachCatalogGroundingResult?> Function({
      required String question,
      required String locale,
    });

/// Owner-bound, local reads for explicit Coach health questions.
///
/// Every database lookup is scoped to one of at most 31 local calendar days.
/// A provider snapshot may be supplied for connected evidence; this adapter
/// never initializes a native source, prompts for access, or imports history.
/// The caller's checkAccess must validate its captured owner AND owner epoch,
/// including independent Coach context-category consent, around every await.
final class CoachHealthQueries {
  CoachHealthQueries(
    AppDatabase database, {
    DailyLogRepository? dailyLogs,
    WeightRepository? weights,
    BodyMeasurementRepository? measurements,
    this._connectedSnapshot,
    CoachCatalogGrounding? catalog,
    CoachHealthContentLookup? contentLookup,
    DateTime Function()? clock,
  }) : _dailyLogs = dailyLogs ?? DailyLogRepository(database),
       _weights = weights ?? WeightRepository(database),
       _measurements = measurements ?? BodyMeasurementRepository(database),
       _contentLookup =
           contentLookup ?? (catalog ?? CoachCatalogGrounding()).answer,
       _clock = clock ?? DateTime.now;

  static const maximumDays = 31;
  static const maximumRows = 31;
  static const topics = <String>{
    'daily',
    'sleep',
    'activity',
    'weight',
    'measurements',
    'progress',
  };

  final DailyLogRepository _dailyLogs;
  final WeightRepository _weights;
  final BodyMeasurementRepository _measurements;
  final ConnectedHealthSnapshot? Function()? _connectedSnapshot;
  final CoachHealthContentLookup _contentLookup;
  final DateTime Function() _clock;

  Future<Map<String, Object?>> execute({
    required String topic,
    required DateTime from,
    required DateTime through,
    int limit = maximumRows,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    if (!topics.contains(topic)) {
      throw ArgumentError.value(topic, 'topic', 'Unsupported health topic');
    }
    if (limit < 1 || limit > maximumRows) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 31');
    }
    final window = _HealthQueryWindow(from, through);
    final now = _clock();
    final needsConnected = topic == 'sleep' || topic == 'activity';
    final snapshot = needsConnected ? _connectedSnapshot?.call() : null;
    checkAccess();
    final connected = _HealthConnectedProjection(
      snapshot: snapshot,
      window: window,
      now: now,
      includeSleep: topic == 'sleep',
      includeActivity: topic == 'activity',
    );
    final records = <Map<String, Object?>>[];
    final missingDays = <String>[];
    final progressSamples = <ProgressSample>[];
    final limitations = <String>{};
    var exerciseBudget = maximumRows;

    // Newest first gives limit a stable, explicit meaning. The entire queried
    // window remains bounded even when it contains gaps in logging.
    for (final day in window.days.reversed) {
      checkAccess();
      final key = dayKeyFor(day);
      Map<String, Object?>? record;
      switch (topic) {
        case 'daily':
          final ledger = await _checked(
            () => _dailyLogs.readLedger(day),
            checkAccess,
          );
          if (ledger.state != DayLifecycleState.notStarted ||
              ledger.evidenceCompleteness > 0) {
            record = {
              'day': key,
              'state': ledger.state.name,
              'caloriesKcal': _finite(ledger.calories),
              'proteinG': _finite(ledger.protein),
              'carbohydratesG': _finite(ledger.carbohydrates),
              'fatG': _finite(ledger.fat),
              'fiberG': _finite(ledger.fiber),
              'netCarbohydratesG': _finite(ledger.netCarbohydrates),
              'evidenceCompleteness': ledger.evidenceCompleteness,
              'source': 'daily_log_repository_ledger',
            };
          }
        case 'weight':
        case 'progress':
          final weight = await _checked(
            () => _weights.getForDay(day),
            checkAccess,
          );
          if (weight != null) {
            if (!weight.weight.isFinite ||
                weight.weight < 20 ||
                weight.weight > 500) {
              limitations.add('invalid_saved_weight_omitted');
            } else {
              record = {
                'day': key,
                'id': weight.id,
                'revision': weight.revision,
                'weightKg': weight.weight,
                'measurementContext': weight.measurementContext,
                'recordedAtUtc': weight.date.toUtc().toIso8601String(),
                'offsetMinutesAtRead': weight.date
                    .toLocal()
                    .timeZoneOffset
                    .inMinutes,
                'source': 'weight_repository',
              };
              progressSamples.add(
                ProgressSample(date: weight.date, weightKg: weight.weight),
              );
            }
          }
        case 'measurements':
          final measurement = await _checked(
            () => _measurements.getForDay(day),
            checkAccess,
          );
          if (measurement != null) {
            record = {
              'day': key,
              'id': measurement.id,
              'revision': measurement.revision,
              'neckCm': _finite(measurement.neckCm),
              'waistCm': _finite(measurement.waistCm),
              'hipsCm': _finite(measurement.hipsCm),
              'chestCm': _finite(measurement.chestCm),
              'armCm': _finite(measurement.armCm),
              'thighCm': _finite(measurement.thighCm),
              'recordedAtUtc': measurement.date.toUtc().toIso8601String(),
              'source': 'body_measurement_repository',
            };
          }
        case 'sleep':
          final log = await _checked(
            () => _dailyLogs.getForDay(day),
            checkAccess,
          );
          final savedHours = _finite(log?.sleepHours);
          final hours = savedHours != null && savedHours <= 24
              ? savedHours
              : null;
          final measured = connected.sleep[key];
          if (hours != null || measured != null) {
            record = {
              'day': key,
              'manual': hours == null
                  ? null
                  : {
                      'hours': hours,
                      'source': 'manual_daily_log',
                      'updatedAtUtc': log!.updatedAt.toUtc().toIso8601String(),
                      'timePrecision': 'calendar_day_duration',
                    },
              'connected': measured == null
                  ? null
                  : _connectedSignalJson(measured, snapshot!, key),
            };
          }
        case 'activity':
          final log = await _checked(
            () => _dailyLogs.getForDay(day),
            checkAccess,
          );
          final storedSteps = log?.steps;
          final manualSteps = storedSteps != null && storedSteps >= 0
              ? storedSteps
              : null;
          final nativeSteps = connected.steps[key];
          final energy = connected.energy[key];
          final exercise = _readExerciseEvidence(
            log?.exerciseNotes,
            budget: exerciseBudget,
          );
          exerciseBudget -= exercise.records.length;
          if (manualSteps != null ||
              nativeSteps != null ||
              energy != null ||
              exercise.hasStoredNotes) {
            record = {
              'day': key,
              'manualSteps': manualSteps == null
                  ? null
                  : {'count': manualSteps, 'source': 'manual_daily_log'},
              'connectedSteps': nativeSteps == null
                  ? null
                  : {
                      'count': nativeSteps,
                      'source': 'connected_health',
                      'deviceSources': connected.stepSources[key] ?? [],
                      'lastSyncAtUtc': snapshot!.lastSyncAt
                          ?.toUtc()
                          .toIso8601String(),
                    },
              'connectedActiveEnergy': energy == null
                  ? null
                  : _connectedSignalJson(energy, snapshot!, key),
              'exercises': exercise.records,
              'exerciseRecordsTruncated': exercise.truncated,
              'hasUnstructuredExerciseNotes': exercise.unstructured,
            };
            if (exercise.truncated) {
              limitations.add('exercise_records_limited_to_31');
            }
            if (exercise.unstructured) {
              limitations.add('unstructured_exercise_notes_not_sent');
            }
          }
      }
      if (record == null) {
        missingDays.add(key);
      } else {
        records.add(record);
      }
    }

    if (needsConnected) {
      limitations.add('connected_evidence_is_cached_no_native_sync');
      if (!connected.accepted) {
        limitations.add('connected_evidence_unavailable_or_not_authorized');
      } else if (snapshot?.status == ConnectedHealthStatus.degraded ||
          snapshot?.failureCode != null) {
        limitations.add('connected_source_degraded_cache_preserved');
      }
    }
    if (topic == 'sleep') {
      limitations.add('manual_sleep_has_no_saved_start_end_or_timezone');
      limitations.add('connected_sleep_is_latest_record_per_local_day');
    }
    if (topic == 'daily') {
      limitations.add('ledger_nutrients_only_no_extended_nutrient_inference');
    }
    final shown = records.take(limit).toList(growable: false);
    if (records.length > limit) limitations.add('rows_limited_newest_first');
    final progress = topic == 'progress'
        ? ProgressAnalysis.evaluate(samples: progressSamples, now: now)
        : null;
    if (progress != null) {
      limitations.add('weight_trend_does_not_measure_fat_or_muscle');
      limitations.add('trend_uses_only_requested_window');
      if (progress.confidence == ProgressConfidence.insufficient) {
        limitations.add('insufficient_comparable_weight_evidence');
      }
    }
    checkAccess();
    return {
      'topic': topic,
      'status': records.isEmpty ? 'no_data' : 'recorded',
      'from': window.fromKey,
      'through': window.throughKey,
      'dateBasis': 'device_local_civil_day',
      'queriedDays': window.days.length,
      'rowLimit': limit,
      'order': 'newest_first',
      'rows': shown,
      'matchedDays': records.length,
      'missingDays': missingDays,
      'truncated': records.length > limit,
      'unknownValuesAreNull': true,
      'limitations': limitations.toList(growable: false),
      if (progress != null)
        'analysis': {
          'engine': 'ProgressAnalysis',
          'confidence': progress.confidence.name,
          'sampleCount': progress.sampleCount,
          'spanDays': progress.spanDays,
          'weeklyDirectionKg': progress.weeklyDirectionKg,
          'monthlyDirectionKg': progress.monthlyDirectionKg,
          'variabilityKg': progress.variabilityKg,
          'sampleScope': 'all_recorded_weights_in_requested_window',
        },
    };
  }

  /// Searches the existing trusted local recipe/workout catalog only.
  ///
  /// A search result is content evidence and an optional trusted route; it
  /// never activates a plan or records a performed workout/recipe serving.
  Future<Map<String, Object?>> searchContent({
    required String question,
    required String locale,
    int limit = 3,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    final query = question.trim();
    if (query.isEmpty || query.runes.length > 500) {
      throw ArgumentError.value(question, 'question', 'Use 1–500 characters');
    }
    if (locale.trim().isEmpty || locale.length > 32) {
      throw ArgumentError.value(locale, 'locale');
    }
    if (limit < 1 || limit > 3) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 3');
    }
    final answer = await _checked(
      () => _contentLookup(question: query, locale: locale),
      checkAccess,
    );
    final links =
        answer?.links
            .where((link) => link.isTrustedLocalRoute)
            .take(limit)
            .toList(growable: false) ??
        [];
    final text = links.isEmpty
        ? ''
        : links.length == answer!.links.length
        ? answer.text
        : links.map((link) => link.label).join('\n');
    checkAccess();
    return {
      'topic': 'content',
      'status': links.isEmpty ? 'no_matching_content' : 'matched',
      'catalogScope': ['installed_recipes', 'installed_workouts'],
      'text': String.fromCharCodes(text.runes.take(1600)),
      'textTruncated': text.runes.length > 1600,
      'rows': links.map((link) => link.toJson()).toList(growable: false),
      'truncated': (answer?.links.length ?? 0) > links.length,
      'source': 'trusted_local_catalog',
      'healthRecordsRead': 0,
      'mutationsPerformed': 0,
    };
  }

  static Future<T> _checked<T>(
    Future<T> Function() operation,
    void Function() checkAccess,
  ) async {
    checkAccess();
    try {
      return await operation();
    } finally {
      checkAccess();
    }
  }
}

double? _finite(double? value) =>
    value != null && value.isFinite && value >= 0 ? value : null;

final class _HealthQueryWindow {
  _HealthQueryWindow(DateTime from, DateTime through) {
    final start = from.toLocal();
    final end = through.toLocal();
    final firstCivil = DateTime.utc(start.year, start.month, start.day);
    final lastCivil = DateTime.utc(end.year, end.month, end.day);
    final count = lastCivil.difference(firstCivil).inDays + 1;
    if (count < 1 || count > CoachHealthQueries.maximumDays) {
      throw ArgumentError('Health queries require 1–31 inclusive civil days');
    }
    days = List.unmodifiable([
      for (var offset = 0; offset < count; offset++)
        // Noon avoids common midnight DST normalization. Advancing the civil
        // components, rather than adding 24 local hours, preserves each day.
        DateTime(start.year, start.month, start.day + offset, 12),
    ]);
  }

  late final List<DateTime> days;
  String get fromKey => dayKeyFor(days.first);
  String get throughKey => dayKeyFor(days.last);
  bool contains(String day) =>
      day.compareTo(fromKey) >= 0 && day.compareTo(throughKey) <= 0;
}
