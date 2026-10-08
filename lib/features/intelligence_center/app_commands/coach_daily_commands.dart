import '../../../data/database/app_database.dart';
import '../../../data/database/date_keys.dart';
import '../../../data/repositories/daily_log_repository.dart';
import 'coach_health_adapter.dart';

typedef CoachDailyRecordRestorer =
    Future<void> Function({required DateTime date, required DailyLog? prior});

/// Adapts the authoritative daily ledger. A missing value stays missing: an
/// empty day can be closed without creating food or setting totals to zero.
final class CoachDailyCommandAdapter implements CoachHealthCommandAdapter {
  CoachDailyCommandAdapter({required this.daily, required this.restoreRecord});

  final DailyLogRepository daily;
  final CoachDailyRecordRestorer restoreRecord;

  static const toolIds = {
    'close_day',
    'reopen_day',
    'log_sleep',
    'save_day_note',
  };

  @override
  bool supports(String toolId) => toolIds.contains(toolId);

  @override
  Future<Map<String, Object?>> resolve({
    required String toolId,
    required String operationId,
    required Map<String, Object?> arguments,
    required DateTime now,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    if (!supports(toolId)) throw ArgumentError.value(toolId, 'toolId');
    final date = parseHealthDay(arguments['date']);
    if (date.isAfter(healthCivilDay(now))) {
      throw ArgumentError('A completed health record cannot be in the future');
    }
    final resolved = <String, Object?>{
      'healthToolId': toolId,
      'date': dayKeyFor(date),
      'recordedAt': now.toUtc().toIso8601String(),
      'timeZoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      'provenance': 'manual',
    };
    if (toolId == 'log_sleep') {
      final hours = arguments['hours'];
      if (hours is! num || !hours.isFinite || hours < 0 || hours > 14) {
        throw ArgumentError.value(hours, 'hours');
      }
      resolved['hours'] = hours.toDouble();
    }
    if (toolId == 'save_day_note') {
      final note = arguments['text'];
      if (note is! String || note.trim().isEmpty || note.length > 1000) {
        throw ArgumentError.value(note, 'text');
      }
      resolved['text'] = note.trim();
    }
    return resolved;
  }

  @override
  Future<Map<String, Object?>> snapshot({
    required Map<String, Object?> resolved,
    required void Function() checkAccess,
  }) async {
    final date = parseHealthDay(resolved['date']);
    final row = await checkedHealthAwait(
      () => daily.getForDay(date),
      checkAccess,
    );
    final toolId = resolved['healthToolId'];
    final lifecycle = toolId == 'close_day' || toolId == 'reopen_day';
    final ledger = lifecycle
        ? await checkedHealthAwait(() => daily.readLedger(date), checkAccess)
        : null;
    final state = row == null
        ? 'notStarted'
        : _hasDailyClosureMarker(row)
        ? 'closed'
        : 'open';
    return {
      'record': row?.toJson(),
      'receipt': {
        'exists': row != null,
        'entity_id': row?.uuid ?? dayKeyFor(date),
        'date': dayKeyFor(date),
        'day_state': state,
        if (lifecycle) ...{
          'calories': ledger!.calories,
          'protein': ledger.protein,
          'carbohydrates': ledger.carbohydrates,
          'fat': ledger.fat,
          'fiber': ledger.fiber,
          'net_carbohydrates': ledger.netCarbohydrates,
          'evidence_completeness': ledger.evidenceCompleteness,
        },
        if (toolId == 'log_sleep') ...{
          'sleep_hours': row?.sleepHours,
          'source': 'manual',
          'recorded_at': resolved['recordedAt'],
          'time_zone_offset_minutes': resolved['timeZoneOffsetMinutes'],
        },
        if (toolId == 'save_day_note') 'note': row?.notes,
      },
    };
  }

  @override
  Future<void> apply({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required void Function() checkAccess,
  }) async {
    final date = parseHealthDay(resolved['date']);
    final existing = await checkedHealthAwait(
      () => daily.getForDay(date),
      checkAccess,
    );
    final toolId = resolved['healthToolId']! as String;
    if (toolId != 'close_day' &&
        toolId != 'reopen_day' &&
        _hasDailyClosureMarker(existing)) {
      throw StateError('Reopen this day before changing its health record');
    }
    switch (toolId) {
      case 'close_day':
        if (existing?.lifecycleState == 'closed' &&
            existing?.closedAt != null) {
          break;
        }
        if (existing == null) {
          // startDay has a full-record contract; it is safe only when absent.
          await checkedHealthAwait(() => daily.startDay(date), checkAccess);
        }
        await checkedHealthAwait(() => daily.closeDay(date), checkAccess);
      case 'reopen_day':
        if (existing == null) throw StateError('This day has no saved record');
        if (!_hasDailyClosureMarker(existing)) break;
        await checkedHealthAwait(() => daily.reopenDay(date), checkAccess);
      case 'log_sleep':
        await checkedHealthAwait(
          () => daily.updateSleepHours(
            date: date,
            sleepHours: (resolved['hours']! as num).toDouble(),
          ),
          checkAccess,
        );
      case 'save_day_note':
        await checkedHealthAwait(
          () => daily.saveBodyContext(
            date: date,
            notes: resolved['text']! as String,
          ),
          checkAccess,
        );
      default:
        throw ArgumentError.value(toolId, 'healthToolId');
    }
    final actual = await checkedHealthAwait(
      () => daily.getForDay(date),
      checkAccess,
    );
    final matches =
        actual != null &&
        switch (toolId) {
          'close_day' =>
            actual.lifecycleState == 'closed' && actual.closedAt != null,
          'reopen_day' =>
            actual.lifecycleState == 'open' && actual.closedAt == null,
          'log_sleep' => actual.sleepHours == resolved['hours'],
          'save_day_note' => actual.notes == resolved['text'],
          _ => false,
        };
    if (!matches) throw StateError('Health write readback did not match');
  }

  @override
  Future<void> compensate({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    required void Function() checkAccess,
  }) async {
    final raw = before['record'];
    final prior = raw == null
        ? null
        : DailyLog.fromJson(Map<String, dynamic>.from(raw as Map));
    await checkedHealthAwait(
      () => restoreRecord(date: parseHealthDay(resolved['date']), prior: prior),
      checkAccess,
    );
    final readback = await checkedHealthAwait(
      () => daily.getForDay(parseHealthDay(resolved['date'])),
      checkAccess,
    );
    if (!healthJsonEquals(readback?.toJson(), prior?.toJson())) {
      throw StateError('Daily compensation readback did not match');
    }
  }
}

bool _hasDailyClosureMarker(DailyLog? row) =>
    row?.lifecycleState == 'closed' || row?.closedAt != null;
