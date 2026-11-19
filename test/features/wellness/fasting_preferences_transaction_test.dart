import 'package:body_intelligence_log/data/repositories/life_context_repository.dart';
import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/wellness/data/fasting_history_repository.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PreferencesRepository preferences;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    preferences = PreferencesRepository(database);
  });

  tearDown(() => database.close());

  test('fasting snapshot set and removal commit together', () async {
    await preferences.mutate(
      set: const {
        'wellness_fasting_session_v2': '{"session":1}',
        'wellness_fasting_started_at': '2026-08-13T10:00:00Z',
        'wellness_fasting_target_hours': '12',
      },
    );

    expect(await preferences.get('wellness_fasting_session_v2'), isNotNull);
    await preferences.mutate(
      set: const {
        'wellness_fasting_history_v1': '[{"history":1}]',
        'wellness_fasting_last_minutes': '30',
      },
      remove: const [
        'wellness_fasting_session_v2',
        'wellness_fasting_started_at',
      ],
    );

    expect(await preferences.get('wellness_fasting_session_v2'), isNull);
    expect(await preferences.get('wellness_fasting_started_at'), isNull);
    expect(await preferences.get('wellness_fasting_history_v1'), isNotNull);
    expect(await preferences.get('wellness_fasting_last_minutes'), '30');
  });

  test('invalid mutation rolls back every preference write', () async {
    await expectLater(
      preferences.mutate(set: const {'valid': 'new', '  ': 'invalid'}),
      throwsArgumentError,
    );
    expect(await preferences.get('valid'), isNull);
  });

  test(
    'delete first completed record updates duration and keeps active timer',
    () async {
      final rows = [_entry(240, 'first'), _entry(120, 'second')];
      await preferences.mutate(
        set: {
          FastingHistoryRepository.historyKey: jsonEncode(rows),
          FastingHistoryRepository.lastMinutesKey: '240',
          'wellness_fasting_session_v2': '{"active":"unchanged"}',
          'wellness_fasting_started_at': 'synthetic-active-start',
          'wellness_fasting_notify_target': 'true',
        },
      );
      final repository = FastingHistoryRepository(preferences);
      final snapshot = await repository.read();
      final next = await repository.delete(
        snapshot.records.first,
        isCurrent: () => true,
      );
      expect(next!.records, hasLength(1));
      expect(
        await preferences.get(FastingHistoryRepository.lastMinutesKey),
        '120',
      );
      expect(
        jsonDecode(
          (await preferences.get(FastingHistoryRepository.historyKey))!,
        ),
        [rows[1]],
      );
      expect(
        await preferences.get('wellness_fasting_session_v2'),
        '{"active":"unchanged"}',
      );
      expect(
        await preferences.get('wellness_fasting_started_at'),
        'synthetic-active-start',
      );
      expect(await preferences.get('wellness_fasting_notify_target'), 'true');
    },
  );

  test(
    'middle duplicate timestamps delete exact occurrence and preserve neighbors',
    () async {
      final rows = [
        _entry(120, 'first'),
        {
          'unknown': ['keep', 7],
        },
        _entry(120, 'middle'),
        _entry(120, 'last'),
      ];
      await preferences.mutate(
        set: {
          FastingHistoryRepository.historyKey: jsonEncode(rows),
          FastingHistoryRepository.lastMinutesKey: '120',
        },
      );
      final repository = FastingHistoryRepository(preferences);
      final snapshot = await repository.read();
      expect(snapshot.records[1].occurrence, 2);
      await repository.delete(snapshot.records[1], isCurrent: () => true);
      expect(
        jsonDecode(
          (await preferences.get(FastingHistoryRepository.historyKey))!,
        ),
        [rows[0], rows[1], rows[3]],
      );
      expect(
        await preferences.get(FastingHistoryRepository.lastMinutesKey),
        '120',
      );
    },
  );

  test(
    'delete last completed record removes stale duration summary only',
    () async {
      await preferences.mutate(
        set: {
          FastingHistoryRepository.historyKey: jsonEncode([_entry(44, 'only')]),
          FastingHistoryRepository.lastMinutesKey: '44',
          'unrelated': 'keep',
        },
      );
      final repository = FastingHistoryRepository(preferences);
      final snapshot = await repository.read();
      await repository.delete(snapshot.records.single, isCurrent: () => true);
      expect(await preferences.get(FastingHistoryRepository.historyKey), '[]');
      expect(
        await preferences.get(FastingHistoryRepository.lastMinutesKey),
        isNull,
      );
      expect(await preferences.get('unrelated'), 'keep');
    },
  );

  test('stale history revision never retargets a delete by index', () async {
    final rows = [_entry(120, 'first'), _entry(60, 'second')];
    await preferences.mutate(
      set: {
        FastingHistoryRepository.historyKey: jsonEncode(rows),
        FastingHistoryRepository.lastMinutesKey: '120',
      },
    );
    final repository = FastingHistoryRepository(preferences);
    final snapshot = await repository.read();
    final changed = jsonEncode(rows.reversed.toList());
    await preferences.set(FastingHistoryRepository.historyKey, changed);
    expect(
      await repository.delete(snapshot.records.first, isCurrent: () => true),
      isNull,
    );
    expect(await preferences.get(FastingHistoryRepository.historyKey), changed);
    expect(
      await preferences.get(FastingHistoryRepository.lastMinutesKey),
      '120',
    );
  });

  test(
    'late duration write failure rolls back history and summary atomically',
    () async {
      final encoded = jsonEncode([_entry(240, 'first'), _entry(120, 'second')]);
      await preferences.mutate(
        set: {
          FastingHistoryRepository.historyKey: encoded,
          FastingHistoryRepository.lastMinutesKey: '240',
        },
      );
      await database.customStatement(
        "CREATE TRIGGER reject_fasting_summary BEFORE UPDATE ON preferences WHEN NEW.key = 'wellness_fasting_last_minutes' BEGIN SELECT RAISE(ABORT, 'synthetic_summary_failure'); END",
      );
      final repository = FastingHistoryRepository(preferences);
      final snapshot = await repository.read();
      await expectLater(
        repository.delete(snapshot.records.first, isCurrent: () => true),
        throwsA(anything),
      );
      expect(
        await preferences.get(FastingHistoryRepository.historyKey),
        encoded,
      );
      expect(
        await preferences.get(FastingHistoryRepository.lastMinutesKey),
        '240',
      );
    },
  );

  test(
    'delivered owner A-B-A during transaction retires the exact delete',
    () async {
      final held = _HeldPreferences(database);
      final encoded = jsonEncode([_entry(120, 'keep')]);
      await held.mutate(
        set: {
          FastingHistoryRepository.historyKey: encoded,
          FastingHistoryRepository.lastMinutesKey: '120',
        },
      );
      final repository = FastingHistoryRepository(held);
      final snapshot = await repository.read();
      var epoch = 0;
      final originalEpoch = epoch;
      held.hold = true;
      final deletion = repository.delete(
        snapshot.records.single,
        isCurrent: () => epoch == originalEpoch,
      );
      final rejection = expectLater(deletion, throwsStateError);
      await held.entered.future.timeout(const Duration(seconds: 2));
      epoch++; // delivered B
      epoch++; // delivered A again
      held.release.complete();
      await rejection;
      expect(
        await preferences.get(FastingHistoryRepository.historyKey),
        encoded,
      );
      expect(
        await preferences.get(FastingHistoryRepository.lastMinutesKey),
        '120',
      );
    },
  );
  test(
    'independent fasting start fact is not inferred from a completed row',
    () async {
      final contexts = LifeContextRepository(database);
      await contexts.add(
        uuid: 'independent-start-fact',
        occurredAt: DateTime.utc(2026, 11, 18),
        type: 'fasting',
        details: 'User started a 16-hour fasting timer.',
      );
      final prior = await contexts.getByUuid('independent-start-fact');
      await preferences.set(
        FastingHistoryRepository.historyKey,
        jsonEncode([_entry(44, 'only')]),
      );
      final repository = FastingHistoryRepository(preferences);
      final snapshot = await repository.read();
      await repository.delete(snapshot.records.single, isCurrent: () => true);
      final after = await contexts.getByUuid('independent-start-fact');
      expect(after!.deletedAt, isNull);
      expect(after.revision, prior!.revision);
      expect(after.details, prior.details);
    },
  );
}

Map<String, Object> _entry(int minutes, String marker) => {
  'startedAtUtc': DateTime.utc(2026, 11, 18, 1).toIso8601String(),
  'endedAtUtc': DateTime.utc(
    2026,
    11,
    18,
    1,
  ).add(Duration(minutes: minutes)).toIso8601String(),
  'targetHours': 16,
  'unknownPayload': {'marker': marker},
};

class _HeldPreferences extends PreferencesRepository {
  _HeldPreferences(super.database);
  bool hold = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<String?> get(String key) async {
    final value = await super.get(key);
    if (hold && key == FastingHistoryRepository.historyKey) {
      hold = false;
      entered.complete();
      await release.future;
    }
    return value;
  }
}
