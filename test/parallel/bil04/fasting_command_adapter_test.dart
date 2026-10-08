import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_fasting_commands.dart';
import 'package:body_intelligence_log/features/wellness/domain/fasting_session.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PreferencesRepository preferences;
  late CoachFastingCommandAdapter adapter;
  final start = DateTime.utc(2026, 10, 7, 6);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    preferences = PreferencesRepository(database);
    adapter = CoachFastingCommandAdapter(preferences);
  });

  tearDown(() => database.close());

  test('only canonical fasting commands are claimed', () {
    expect(adapter.supports('start_fasting'), isTrue);
    expect(adapter.supports('stop_fasting'), isTrue);
    expect(adapter.supports('adjust_fasting'), isTrue);
    expect(adapter.supports('set_notification_preference'), isFalse);
    expect(adapter.supports('log_sleep'), isFalse);
  });

  test(
    'read-only absent fasting status creates no preferences or command',
    () async {
      final before = await database.select(database.preferences).get();
      final result = await adapter.read(checkAccess: _allow);
      expect(result['active'], isFalse);
      expect(result['historyCount'], 0);
      expect(result['latestHistory'], isNull);
      expect(result['lastMinutes'], isNull);
      expect(await database.select(database.preferences).get(), before);
    },
  );

  test(
    'proposal is read-only and requires an explicit bounded target',
    () async {
      await preferences.set(CoachFastingCommandAdapter.notifyTargetKey, 'true');
      final before = await _readData(preferences);
      final proposal = await _prepare(database, adapter, 'start_fasting', {
        'targetHours': 16,
      }, start);
      expect(proposal.resolved['startedAtUtc'], start.toIso8601String());
      expect(await _readData(preferences), before);
      expect(
        await preferences.get(CoachFastingCommandAdapter.notifyTargetKey),
        'true',
      );
      for (final value in <Object?>[null, 0, 24, 48, 1.5, '16']) {
        await expectLater(
          _prepare(database, adapter, 'start_fasting', {
            'targetHours': value,
          }, start),
          throwsArgumentError,
        );
      }
      await expectLater(
        _prepare(database, adapter, 'start_fasting', const {}, start),
        throwsArgumentError,
      );
    },
  );

  test(
    'start persists both session formats and preserves unrelated state',
    () async {
      final history = _historyBefore(start);
      await preferences.setMany({
        CoachFastingCommandAdapter.historyKey: FastingHistoryCodec.encode(
          history,
        ),
        CoachFastingCommandAdapter.lastMinutesKey: '900',
        CoachFastingCommandAdapter.notifyTargetKey: 'true',
        'synthetic_unrelated_preference': 'preserved',
      });
      final proposal = await _prepare(database, adapter, 'start_fasting', {
        'targetHours': 16,
      }, start);
      final saved = await _commit(database, adapter, proposal);
      final values = await _readData(preferences);
      final restored = FastingSession.tryParse(
        values[CoachFastingCommandAdapter.sessionKey],
        now: start,
      );
      expect(restored?.startedAt, start);
      expect(restored?.targetHours, 16);
      expect(
        values[CoachFastingCommandAdapter.startedAtKey],
        start.toIso8601String(),
      );
      expect(values[CoachFastingCommandAdapter.targetHoursKey], '16');
      expect(values[CoachFastingCommandAdapter.lastMinutesKey], '900');
      expect(
        values[CoachFastingCommandAdapter.historyKey],
        FastingHistoryCodec.encode(history),
      );
      expect((saved['receipt']! as Map)['active'], isTrue);
      expect(
        await preferences.get('synthetic_unrelated_preference'),
        'preserved',
      );
      expect(
        await preferences.get(CoachFastingCommandAdapter.notifyTargetKey),
        'true',
      );
    },
  );

  test('a second start cannot replace an active session', () async {
    await _seedSession(preferences, start);
    final before = await _readData(preferences);
    await expectLater(
      _prepare(database, adapter, 'start_fasting', {
        'targetHours': 18,
      }, start.add(const Duration(hours: 1))),
      throwsStateError,
    );
    expect(await _readData(preferences), before);
  });

  test(
    'adjust corrects explicit instants and target without changing history',
    () async {
      await _seedSession(preferences, start);
      await preferences.setMany({
        CoachFastingCommandAdapter.historyKey: FastingHistoryCodec.encode(
          _historyBefore(start),
        ),
        CoachFastingCommandAdapter.lastMinutesKey: '900',
      });
      final prior = await _readData(preferences);
      final proposal = await _prepare(database, adapter, 'adjust_fasting', {
        'startedAt': '2026-10-07T08:30:00+03:00',
        'targetHours': 18,
      }, start.add(const Duration(hours: 2)));
      await _commit(database, adapter, proposal);
      final saved = await _readData(preferences);
      expect(
        saved[CoachFastingCommandAdapter.startedAtKey],
        '2026-10-07T05:30:00.000Z',
      );
      expect(saved[CoachFastingCommandAdapter.targetHoursKey], '18');
      expect(
        saved[CoachFastingCommandAdapter.historyKey],
        prior[CoachFastingCommandAdapter.historyKey],
      );
      expect(saved[CoachFastingCommandAdapter.lastMinutesKey], '900');
    },
  );

  test(
    'adjust rejects ambiguous DST, rollover, future and empty corrections',
    () async {
      await _seedSession(preferences, start);
      final before = await _readData(preferences);
      for (final value in [
        '2026-10-07T06:00:00',
        '2026-10-07',
        '2026-02-30T06:00:00Z',
        '2026-10-07T06:61:00Z',
        '2026-10-07T06:00:00+24:00',
        '2026-10-08T06:00:00Z',
      ]) {
        await expectLater(
          _prepare(database, adapter, 'adjust_fasting', {
            'startedAt': value,
          }, start),
          throwsArgumentError,
        );
      }
      await expectLater(
        _prepare(database, adapter, 'adjust_fasting', const {}, start),
        throwsArgumentError,
      );
      expect(await _readData(preferences), before);
    },
  );

  test(
    'DST repeated wall hour remains distinct through explicit offsets',
    () async {
      final now = DateTime.utc(2026, 11, 1, 8);
      await _seedSession(preferences, now.subtract(const Duration(hours: 4)));
      final first = await _prepare(database, adapter, 'adjust_fasting', {
        'startedAt': '2026-11-01T01:30:00-04:00',
      }, now);
      final second = await _prepare(database, adapter, 'adjust_fasting', {
        'startedAt': '2026-11-01T01:30:00-05:00',
      }, now);
      expect(first.resolved['startedAtUtc'], '2026-11-01T05:30:00.000Z');
      expect(second.resolved['startedAtUtc'], '2026-11-01T06:30:00.000Z');
    },
  );

  test('target-only adjustment preserves the active start', () async {
    await _seedSession(preferences, start);
    final proposal = await _prepare(database, adapter, 'adjust_fasting', {
      'targetHours': 18,
    }, start.add(const Duration(hours: 2)));
    await _commit(database, adapter, proposal);
    expect(
      await preferences.get(CoachFastingCommandAdapter.startedAtKey),
      start.toIso8601String(),
    );
  });

  test(
    'stop derives history and duration from its immutable end instant',
    () async {
      await _seedSession(preferences, start);
      final end = start.add(const Duration(hours: 15, minutes: 30));
      final proposal = await _prepare(
        database,
        adapter,
        'stop_fasting',
        const {},
        end,
      );
      final saved = await _commit(database, adapter, proposal);
      final values = await _readData(preferences);
      final history = FastingHistoryCodec.decode(
        values[CoachFastingCommandAdapter.historyKey],
      );
      expect(values[CoachFastingCommandAdapter.sessionKey], isNull);
      expect(values[CoachFastingCommandAdapter.startedAtKey], isNull);
      expect(values[CoachFastingCommandAdapter.lastMinutesKey], '930');
      expect(values[CoachFastingCommandAdapter.targetHoursKey], '16');
      expect(history, hasLength(1));
      expect(history.single.startedAt, start);
      expect(history.single.endedAt, end);
      expect(history.single.reachedTarget, isFalse);
      expect((saved['receipt']! as Map)['active'], isFalse);
      // The journal prevents replay; the adapter also derives from the immutable
      // before snapshot rather than appending again to a newly read history.
      await _commit(database, adapter, proposal);
      expect(
        FastingHistoryCodec.decode(
          await preferences.get(CoachFastingCommandAdapter.historyKey),
        ),
        hasLength(1),
      );
    },
  );

  test('stop preserves the existing bounded history policy', () async {
    await _seedSession(preferences, start);
    final history = List.generate(100, (index) {
      final ended = start.subtract(Duration(days: index + 1));
      return FastingHistoryEntry(
        startedAt: ended.subtract(const Duration(hours: 16)),
        endedAt: ended,
        targetHours: 16,
      );
    });
    await preferences.set(
      CoachFastingCommandAdapter.historyKey,
      FastingHistoryCodec.encode(history),
    );
    final end = start.add(const Duration(hours: 16));
    final proposal = await _prepare(
      database,
      adapter,
      'stop_fasting',
      const {},
      end,
    );
    await _commit(database, adapter, proposal);
    final saved = FastingHistoryCodec.decode(
      await preferences.get(CoachFastingCommandAdapter.historyKey),
    );
    expect(saved, hasLength(100));
    expect(saved.first.endedAt, end);
    expect(saved.last.endedAt, history[98].endedAt);
  });

  test(
    'stop requires an active session with a positive elapsed duration',
    () async {
      await expectLater(
        _prepare(database, adapter, 'stop_fasting', const {}, start),
        throwsStateError,
      );
      await _seedSession(preferences, start);
      await expectLater(
        _prepare(database, adapter, 'stop_fasting', const {}, start),
        throwsArgumentError,
      );
    },
  );

  test(
    'restart restores the same active record; receipts do not tick',
    () async {
      await _seedSession(preferences, start);
      final restarted = CoachFastingCommandAdapter(
        PreferencesRepository(database),
      );
      final proposal = await _prepare(database, restarted, 'adjust_fasting', {
        'targetHours': 18,
      }, start.add(const Duration(days: 2)));
      final later = await restarted.snapshot(
        resolved: {
          ...proposal.resolved,
          'occurredAtUtc': start.add(const Duration(days: 3)).toIso8601String(),
        },
        checkAccess: _allow,
      );
      expect(later, proposal.before);
      expect((later['receipt']! as Map)['active'], isTrue);
      expect((later['receipt']! as Map).containsKey('elapsedMinutes'), isFalse);
    },
  );

  test(
    'Undo start restores exact data and preserves a later notification setting',
    () async {
      await preferences.set(CoachFastingCommandAdapter.targetHoursKey, '18');
      final before = await _readData(preferences);
      final proposal = await _prepare(database, adapter, 'start_fasting', {
        'targetHours': 16,
      }, start);
      final after = await _commit(database, adapter, proposal);
      await preferences.set(
        CoachFastingCommandAdapter.notifyTargetKey,
        'false',
      );
      await _undo(database, adapter, proposal, after);
      expect(await _readData(preferences), before);
      expect(
        await preferences.get(CoachFastingCommandAdapter.notifyTargetKey),
        'false',
      );
    },
  );

  test(
    'Undo stop restores legacy-only session and exact raw history',
    () async {
      await preferences.setMany({
        CoachFastingCommandAdapter.startedAtKey: '2026-10-07T09:00:00+03:00',
        CoachFastingCommandAdapter.targetHoursKey: '16',
        CoachFastingCommandAdapter.historyKey: '[ ]',
        CoachFastingCommandAdapter.lastMinutesKey: '800',
      });
      final before = await _readData(preferences);
      final proposal = await _prepare(
        database,
        adapter,
        'stop_fasting',
        const {},
        start.add(const Duration(hours: 16)),
      );
      final after = await _commit(database, adapter, proposal);
      await _undo(database, adapter, proposal, after);
      expect(await _readData(preferences), before);
      expect(
        await preferences.get(CoachFastingCommandAdapter.sessionKey),
        isNull,
      );
    },
  );

  test('Undo adjustment restores the entire prior active snapshot', () async {
    await _seedSession(preferences, start);
    final before = await _readData(preferences);
    final proposal = await _prepare(database, adapter, 'adjust_fasting', {
      'targetHours': 18,
      'startedAt': '2026-10-07T05:00:00Z',
    }, start.add(const Duration(hours: 2)));
    final after = await _commit(database, adapter, proposal);
    await _undo(database, adapter, proposal, after);
    expect(await _readData(preferences), before);
  });

  test('Undo rejects a later manual edit without overwriting it', () async {
    final proposal = await _prepare(database, adapter, 'start_fasting', {
      'targetHours': 16,
    }, start);
    final after = await _commit(database, adapter, proposal);
    await preferences.set(CoachFastingCommandAdapter.targetHoursKey, '20');
    final manual = await _readData(preferences);
    await expectLater(
      _undo(database, adapter, proposal, after),
      throwsStateError,
    );
    expect(await _readData(preferences), manual);
  });

  test(
    'partial persistence is detected and caller transaction rolls back',
    () async {
      final incomplete = CoachFastingCommandAdapter(
        _IncompletePreferences(database),
      );
      final before = await _readData(preferences);
      final proposal = await _prepare(database, incomplete, 'start_fasting', {
        'targetHours': 16,
      }, start);
      await expectLater(
        _commit(database, incomplete, proposal),
        throwsStateError,
      );
      expect(await _readData(preferences), before);
    },
  );

  test(
    'readback failure inside write transaction cannot report a saved session',
    () async {
      final failingPreferences = _ReadbackFailurePreferences(database);
      final failing = CoachFastingCommandAdapter(failingPreferences);
      final before = await _readData(preferences);
      final proposal = await _prepare(database, failing, 'start_fasting', {
        'targetHours': 16,
      }, start);
      await expectLater(_commit(database, failing, proposal), throwsStateError);
      expect(await _readData(preferences), before);
    },
  );

  test(
    'owner epoch change after an await rolls data back even after return',
    () async {
      var epoch = 0;
      void checkAccess() {
        if (epoch != 0) throw StateError('Synthetic owner attempt revoked');
      }

      final mutatingPreferences = _AfterWritePreferences(database, () {
        epoch +=
            2; // Synthetic owner A -> B -> A; same owner is not same attempt.
      });
      final guarded = CoachFastingCommandAdapter(mutatingPreferences);
      final before = await _readData(preferences);
      final proposal = await _prepare(
        database,
        guarded,
        'start_fasting',
        {'targetHours': 16},
        start,
        checkAccess: checkAccess,
      );
      await expectLater(
        _commit(database, guarded, proposal, checkAccess: checkAccess),
        throwsStateError,
      );
      expect(await _readData(preferences), before);
    },
  );

  test(
    'malformed persisted session or history is preserved and rejected',
    () async {
      await preferences.set(CoachFastingCommandAdapter.sessionKey, '{broken');
      await expectLater(
        _prepare(database, adapter, 'start_fasting', {
          'targetHours': 16,
        }, start),
        throwsFormatException,
      );
      expect(
        await preferences.get(CoachFastingCommandAdapter.sessionKey),
        '{broken',
      );
      await _seedSession(preferences, start);
      await preferences.set(
        CoachFastingCommandAdapter.historyKey,
        '[{"targetHours":16}]',
      );
      await expectLater(
        _prepare(
          database,
          adapter,
          'stop_fasting',
          const {},
          start.add(const Duration(hours: 1)),
        ),
        throwsFormatException,
      );
      expect(
        await preferences.get(CoachFastingCommandAdapter.historyKey),
        '[{"targetHours":16}]',
      );
    },
  );

  test(
    'unknown history and missing last duration are not reported as zeros',
    () async {
      await preferences.set(CoachFastingCommandAdapter.historyKey, '{invalid');
      final snapshot = await adapter.snapshot(
        resolved: const {'healthToolId': 'start_fasting'},
        checkAccess: _allow,
      );
      final receipt = snapshot['receipt']! as Map;
      expect(receipt['historyAvailable'], isFalse);
      expect(receipt['historyCount'], isNull);
      expect(receipt['lastMinutes'], isNull);
    },
  );

  test(
    'legacy larger target is preserved when only start time is corrected',
    () async {
      await _seedSession(preferences, start, targetHours: 48);
      final proposal = await _prepare(database, adapter, 'adjust_fasting', {
        'startedAt': '2026-10-07T05:00:00Z',
      }, start.add(const Duration(hours: 1)));
      await _commit(database, adapter, proposal);
      expect(
        await preferences.get(CoachFastingCommandAdapter.targetHoursKey),
        '48',
      );
    },
  );
}

void _allow() {}

final class _Proposal {
  const _Proposal(this.resolved, this.before);
  final Map<String, Object?> resolved;
  final Map<String, Object?> before;
}

Future<_Proposal> _prepare(
  AppDatabase database,
  CoachFastingCommandAdapter adapter,
  String toolId,
  Map<String, Object?> arguments,
  DateTime now, {
  void Function() checkAccess = _allow,
}) => database.transaction(() async {
  final resolved = await adapter.resolve(
    toolId: toolId,
    operationId: 'synthetic-fasting-operation',
    arguments: arguments,
    now: now,
    checkAccess: checkAccess,
  );
  final before = await adapter.snapshot(
    resolved: resolved,
    checkAccess: checkAccess,
  );
  return _Proposal(resolved, before);
});

Future<Map<String, Object?>> _commit(
  AppDatabase database,
  CoachFastingCommandAdapter adapter,
  _Proposal proposal, {
  void Function() checkAccess = _allow,
}) => database.transaction(() async {
  await adapter.apply(
    resolved: proposal.resolved,
    before: proposal.before,
    checkAccess: checkAccess,
  );
  return adapter.snapshot(
    resolved: proposal.resolved,
    checkAccess: checkAccess,
  );
});

Future<void> _undo(
  AppDatabase database,
  CoachFastingCommandAdapter adapter,
  _Proposal proposal,
  Map<String, Object?> after,
) => database.transaction(
  () => adapter.compensate(
    resolved: proposal.resolved,
    before: proposal.before,
    after: after,
    checkAccess: _allow,
  ),
);

Future<Map<String, String?>> _readData(
  PreferencesRepository preferences,
) async {
  return {
    for (final key in CoachFastingCommandAdapter.dataKeys)
      key: await preferences.get(key),
  };
}

Future<void> _seedSession(
  PreferencesRepository preferences,
  DateTime start, {
  int targetHours = 16,
}) => preferences.setMany({
  CoachFastingCommandAdapter.sessionKey: jsonEncode(
    FastingSession(startedAt: start, targetHours: targetHours).toJson(),
  ),
  CoachFastingCommandAdapter.startedAtKey: start.toIso8601String(),
  CoachFastingCommandAdapter.targetHoursKey: '$targetHours',
});

List<FastingHistoryEntry> _historyBefore(DateTime start) => [
  FastingHistoryEntry(
    startedAt: start.subtract(const Duration(days: 2)),
    endedAt: start.subtract(const Duration(days: 1, hours: 9)),
    targetHours: 16,
  ),
];

class _IncompletePreferences extends PreferencesRepository {
  _IncompletePreferences(super.database);

  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) =>
      super.setManyInCurrentTransaction({
        for (final entry in values.entries)
          if (entry.key != CoachFastingCommandAdapter.sessionKey)
            entry.key: entry.value,
      });
}

class _ReadbackFailurePreferences extends PreferencesRepository {
  _ReadbackFailurePreferences(super.database);
  var _written = false;

  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    await super.setManyInCurrentTransaction(values);
    _written = true;
  }

  @override
  Future<String?> get(String key) {
    if (_written) throw StateError('Synthetic readback unavailable');
    return super.get(key);
  }
}

class _AfterWritePreferences extends PreferencesRepository {
  _AfterWritePreferences(super.database, this.afterWrite);
  final void Function() afterWrite;

  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    await super.setManyInCurrentTransaction(values);
    afterWrite();
  }
}
