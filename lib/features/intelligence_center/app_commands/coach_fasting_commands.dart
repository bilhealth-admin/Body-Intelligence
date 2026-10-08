import 'dart:convert';

import '../../../data/repositories/preferences_repository.dart';
import '../../notifications/services/bil_notification_service.dart';
import '../../wellness/domain/fasting_session.dart';
import 'coach_health_adapter.dart';

part 'coach_fasting_notifications.dart';

/// Adapts the existing fasting preferences to the native Coach transaction.
/// The native journal owns admission, stale-proposal checks, replay and Undo.
/// This adapter never opens a second transaction or schedules device effects.
final class CoachFastingCommandAdapter implements CoachHealthCommandAdapter {
  CoachFastingCommandAdapter(this.preferences);

  final PreferencesRepository preferences;

  static const sessionKey = 'wellness_fasting_session_v2';
  static const startedAtKey = 'wellness_fasting_started_at';
  static const targetHoursKey = 'wellness_fasting_target_hours';
  static const historyKey = 'wellness_fasting_history_v1';
  static const lastMinutesKey = 'wellness_fasting_last_minutes';
  static const notifyTargetKey = 'wellness_fasting_notify_target';
  static const dataKeys = [
    sessionKey,
    startedAtKey,
    targetHoursKey,
    historyKey,
    lastMinutesKey,
  ];

  @override
  bool supports(String toolId) => const {
    'start_fasting',
    'stop_fasting',
    'adjust_fasting',
  }.contains(toolId);

  /// Bounded, stable readback for read_fasting. Reading does not prepare a
  /// mutation, create an empty preference, or synchronize device notifications.
  Future<Map<String, Object?>> read({
    required void Function() checkAccess,
  }) async => _fastingReceipt(await _readValues(checkAccess));

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
    final allowed = switch (toolId) {
      'start_fasting' => const {'targetHours'},
      'adjust_fasting' => const {'targetHours', 'startedAt'},
      _ => const <String>{},
    };
    if (arguments.keys.any((key) => !allowed.contains(key))) {
      throw ArgumentError('Unsupported fasting arguments');
    }
    final requestedHours = arguments.containsKey('targetHours')
        ? _requestedFastingHours(arguments['targetHours'])
        : null;
    if (toolId == 'start_fasting' && requestedHours == null) {
      throw ArgumentError('A fasting target is required');
    }
    if (toolId == 'adjust_fasting' && arguments.isEmpty) {
      throw ArgumentError('A fasting correction is required');
    }
    final correctedStart = arguments.containsKey('startedAt')
        ? _explicitFastingInstant(arguments['startedAt'])
        : null;
    if (correctedStart != null && correctedStart.isAfter(now.toUtc())) {
      throw ArgumentError('A fasting start cannot be in the future');
    }
    final values = await _readValues(checkAccess);
    final current = _readFastingSession(values, notAfter: now);
    if (toolId == 'start_fasting' && current != null) {
      throw StateError('A fasting session is already active');
    }
    if (toolId != 'start_fasting' && current == null) {
      throw StateError('There is no active fasting session');
    }
    if (toolId == 'stop_fasting') {
      if (!now.toUtc().isAfter(current!.startedAt.toUtc())) {
        throw ArgumentError('A fasting end must follow its start');
      }
      // Do not silently replace malformed or partially decoded history.
      _readFastingHistory(values[historyKey]);
    }
    checkAccess();
    return {
      'healthToolId': toolId,
      'occurredAtUtc': now.toUtc().toIso8601String(),
      'startedAtUtc': (correctedStart ?? current?.startedAt ?? now)
          .toUtc()
          .toIso8601String(),
      'targetHours': requestedHours ?? current!.targetHours,
    };
  }

  @override
  Future<Map<String, Object?>> snapshot({
    required Map<String, Object?> resolved,
    required void Function() checkAccess,
  }) async {
    _tool(resolved);
    final values = await _readValues(checkAccess);
    return {'preferences': values, 'receipt': _fastingReceipt(values)};
  }

  @override
  Future<void> apply({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    final toolId = _tool(resolved);
    final prior = _fastingSnapshotValues(before);
    final at = _explicitFastingInstant(resolved['occurredAtUtc']);
    final current = _readFastingSession(prior, notAfter: at);
    final startedAt = _explicitFastingInstant(resolved['startedAtUtc']);
    final hours = resolved['targetHours'];
    if (hours is! int || hours < 1 || hours > 48 || startedAt.isAfter(at)) {
      throw ArgumentError('Invalid resolved fasting session');
    }
    if (toolId == 'start_fasting') {
      _requestedFastingHours(hours);
      if (current != null || startedAt != at) {
        throw StateError('The fasting start no longer matches its proposal');
      }
    } else if (current == null) {
      throw StateError('The active fasting session is missing');
    } else if (toolId == 'adjust_fasting' && hours != current.targetHours) {
      _requestedFastingHours(hours);
    }
    final next = Map<String, String?>.of(prior);
    if (toolId == 'stop_fasting') {
      if (current!.startedAt.toUtc() != startedAt ||
          current.targetHours != hours ||
          !at.isAfter(startedAt)) {
        throw StateError('The fasting end no longer matches its proposal');
      }
      final ended = FastingHistoryEntry(
        startedAt: startedAt,
        endedAt: at,
        targetHours: hours,
      );
      next[historyKey] = FastingHistoryCodec.encode(
        FastingHistoryCodec.prepend(
          ended,
          _readFastingHistory(prior[historyKey]),
        ),
      );
      next[lastMinutesKey] = '${ended.duration.inMinutes}';
      next[sessionKey] = null;
      next[startedAtKey] = null;
    } else {
      final session = FastingSession(startedAt: startedAt, targetHours: hours);
      next[sessionKey] = jsonEncode(session.toJson());
      next[startedAtKey] = startedAt.toIso8601String();
      next[targetHoursKey] = '$hours';
    }
    await _writeAndVerify(prior, next, checkAccess);
  }

  @override
  Future<void> compensate({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    required void Function() checkAccess,
  }) async {
    _tool(resolved);
    final expected = _fastingSnapshotValues(after);
    final current = await _readValues(checkAccess);
    if (!_sameFastingValues(current, expected)) {
      throw StateError('The fasting state changed after this operation');
    }
    await _writeAndVerify(current, _fastingSnapshotValues(before), checkAccess);
  }

  String _tool(Map<String, Object?> resolved) {
    final toolId = resolved['healthToolId'];
    if (toolId is! String || !supports(toolId)) {
      throw ArgumentError('Invalid resolved fasting tool');
    }
    return toolId;
  }

  Future<Map<String, String?>> _readValues(void Function() checkAccess) async {
    final values = <String, String?>{};
    for (final key in dataKeys) {
      values[key] = await checkedHealthAwait(
        () => preferences.get(key),
        checkAccess,
      );
    }
    return values;
  }

  Future<void> _writeAndVerify(
    Map<String, String?> current,
    Map<String, String?> intended,
    void Function() checkAccess,
  ) async {
    final set = <String, String>{};
    final remove = <String>[];
    for (final key in dataKeys) {
      if (current[key] == intended[key]) continue;
      final value = intended[key];
      if (value == null) {
        remove.add(key);
      } else {
        set[key] = value;
      }
    }
    await checkedHealthAwait(
      () => preferences.setManyInCurrentTransaction(set),
      checkAccess,
    );
    await checkedHealthAwait(
      () => preferences.removeManyInCurrentTransaction(remove),
      checkAccess,
    );
    final saved = await _readValues(checkAccess);
    if (!_sameFastingValues(saved, intended)) {
      throw StateError('The fasting preference write could not be verified');
    }
  }
}

int _requestedFastingHours(Object? value) {
  if (value is! int || value < 1 || value > 23) {
    throw ArgumentError.value(value, 'targetHours', 'Use 1 to 23 hours');
  }
  return value;
}

/// A correction must identify an instant. Bare local times cannot distinguish
/// the repeated hour at a DST transition. Calendar rollover is also rejected.
DateTime _explicitFastingInstant(Object? value) {
  if (value is! String) throw ArgumentError('A timestamp is required');
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,6}))?)?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (match == null) {
    throw ArgumentError('Use an ISO timestamp with UTC or an explicit offset');
  }
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final second = int.parse(match[6] ?? '0');
  final civil = DateTime.utc(year, month, day, hour, minute, second);
  final offset = match[8]!;
  if (civil.year != year ||
      civil.month != month ||
      civil.day != day ||
      civil.hour != hour ||
      civil.minute != minute ||
      civil.second != second ||
      offset != 'Z' &&
          (int.parse(offset.substring(1, 3)) > 23 ||
              int.parse(offset.substring(4, 6)) > 59)) {
    throw ArgumentError('Invalid fasting timestamp');
  }
  return DateTime.parse(value).toUtc();
}

Map<String, String?> _fastingSnapshotValues(Map<String, Object?> snapshot) {
  final values = snapshot['preferences'];
  if (values is! Map ||
      values.length != CoachFastingCommandAdapter.dataKeys.length) {
    throw const FormatException('Invalid fasting preference snapshot');
  }
  return {
    for (final key in CoachFastingCommandAdapter.dataKeys)
      key: switch (values[key]) {
        String value => value,
        null when values.containsKey(key) => null,
        _ => throw const FormatException('Invalid fasting preference value'),
      },
  };
}

bool _sameFastingValues(
  Map<String, String?> left,
  Map<String, String?> right,
) =>
    CoachFastingCommandAdapter.dataKeys.every((key) => left[key] == right[key]);

FastingSession? _readFastingSession(
  Map<String, String?> values, {
  DateTime? notAfter,
}) {
  final encoded = values[CoachFastingCommandAdapter.sessionKey];
  final legacy = values[CoachFastingCommandAdapter.startedAtKey];
  if (encoded == null && legacy == null) return null;
  // A snapshot must remain stable as wall time advances. Resolve/apply pass
  // their immutable proposal time; receipts use a constant upper boundary.
  final limit = notAfter ?? DateTime.utc(9999, 12, 31, 23, 59, 59, 999, 999);
  if (encoded != null) {
    final session = FastingSession.tryParse(encoded, now: limit);
    if (session == null) {
      throw const FormatException('The saved fasting session is invalid');
    }
    return session;
  }
  final start = DateTime.tryParse(legacy!);
  final hours = int.tryParse(
    values[CoachFastingCommandAdapter.targetHoursKey] ?? '',
  );
  if (start == null ||
      start.toUtc().isAfter(limit.toUtc()) ||
      hours == null ||
      hours < 1 ||
      hours > 48) {
    throw const FormatException('The saved legacy fasting session is invalid');
  }
  return FastingSession(startedAt: start, targetHours: hours);
}

List<FastingHistoryEntry> _readFastingHistory(String? encoded) {
  if (encoded == null || encoded.isEmpty) return const [];
  final raw = jsonDecode(encoded);
  if (raw is! List) {
    throw const FormatException('The saved fasting history is invalid');
  }
  final history = FastingHistoryCodec.decode(encoded);
  if (history.length != raw.length) {
    throw const FormatException('The saved fasting history is incomplete');
  }
  return history;
}

Map<String, Object?> _fastingReceipt(Map<String, String?> values) {
  FastingSession? session;
  List<FastingHistoryEntry>? history;
  var sessionAvailable = true;
  try {
    session = _readFastingSession(values);
  } on FormatException {
    sessionAvailable = false;
  }
  try {
    history = _readFastingHistory(
      values[CoachFastingCommandAdapter.historyKey],
    );
  } on FormatException {
    // Unknown/corrupt history is not an empty history or a zero-duration fast.
  }
  final lastMinutes = int.tryParse(
    values[CoachFastingCommandAdapter.lastMinutesKey] ?? '',
  );
  final savedTarget = int.tryParse(
    values[CoachFastingCommandAdapter.targetHoursKey] ?? '',
  );
  return {
    'source': 'manual_fasting_timer',
    'sessionAvailable': sessionAvailable,
    'active': sessionAvailable ? session != null : null,
    'startedAtUtc': session?.startedAt.toUtc().toIso8601String(),
    'targetHours':
        session?.targetHours ??
        (savedTarget != null && savedTarget >= 1 && savedTarget <= 48
            ? savedTarget
            : null),
    'historyAvailable': history != null,
    'historyCount': history?.length,
    'latestHistory': history == null || history.isEmpty
        ? null
        : history.first.toJson(),
    'lastMinutes': lastMinutes != null && lastMinutes >= 0 ? lastMinutes : null,
  };
}
