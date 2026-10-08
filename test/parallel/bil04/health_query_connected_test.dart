import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/health_query_adapter.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DailyLogRepository daily;
  final now = DateTime(2026, 10, 7, 18);
  void allow() {}
  setUp(() {
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'synthetic-owner-a',
    );
    daily = DailyLogRepository(database);
  });
  tearDown(() => database.close());

  CoachHealthQueries queries(ConnectedHealthSnapshot snapshot) =>
      CoachHealthQueries(
        database,
        connectedSnapshot: () => snapshot,
        clock: () => now,
      );

  test(
    'sleep keeps manual duration and connected provenance separately',
    () async {
      await daily.updateSleepHours(date: now, sleepHours: 6.5);
      final signal = _signal(
        'sleep',
        7.25,
        'h',
        DateTime(2026, 10, 6, 22),
        attributes: {
          'startedAt': DateTime(2026, 10, 6, 22).toIso8601String(),
          'endedAt': DateTime(2026, 10, 7, 7).toIso8601String(),
          'privateDeviceMetadata': 'not-for-model',
        },
      );
      final result = await queries(
        _snapshot(now, signals: [signal]),
      ).execute(topic: 'sleep', from: now, through: now, checkAccess: allow);
      final row = _rows(result).single;
      expect((row['manual'] as Map)['hours'], 6.5);
      final connected = row['connected'] as Map;
      expect(connected['value'], 7.25);
      expect(connected['unit'], 'h');
      expect(connected['source'], 'connected_health');
      expect(connected['deviceSource'], 'synthetic-native-source');
      expect(connected['localDay'], '2026-10-07');
      expect(connected['endedAt'], isNotNull);
      expect(jsonEncode(result), isNot(contains('not-for-model')));
      expect((await daily.getForDay(now))?.sleepHours, 6.5);
    },
  );

  test(
    'denied or unverified connected data cannot become measured evidence',
    () async {
      final signal = _signal('steps', 5000, 'count', now);
      for (final snapshot in [
        _snapshot(now, signals: [signal], verified: false),
        _snapshot(
          now,
          signals: [signal],
          status: ConnectedHealthStatus.permissionDenied,
        ),
      ]) {
        final result = await queries(snapshot).execute(
          topic: 'activity',
          from: now,
          through: now,
          checkAccess: allow,
        );
        expect(result['status'], 'no_data');
        expect(_rows(result), isEmpty);
        expect(
          result['limitations'],
          contains('connected_evidence_unavailable_or_not_authorized'),
        );
      }
      expect(await database.select(database.dailyLogs).get(), isEmpty);
    },
  );

  test(
    '31-day steps include known zero without adding latest to history',
    () async {
      final first = DateTime(2026, 9, 7, 12);
      final older = _signal('steps', 0, 'count', first);
      final latest = _signal('steps', 1234, 'count', now);
      final result =
          await queries(
            _snapshot(now, signals: [latest], stepHistory: [older, latest]),
          ).execute(
            topic: 'activity',
            from: first,
            through: now,
            checkAccess: allow,
          );
      final rows = _rows(result);
      expect(result['queriedDays'], 31);
      expect(rows.length, 2);
      expect((rows.first['connectedSteps'] as Map)['count'], 1234);
      expect((rows.last['connectedSteps'] as Map)['count'], 0);
      expect(rows.first['manualSteps'], isNull);
      expect((result['missingDays'] as List).length, 29);
      expect(await database.select(database.dailyLogs).get(), isEmpty);
    },
  );

  test('manual steps and native steps are not silently summed', () async {
    await daily.save(date: now, steps: 100);
    final result = await queries(
      _snapshot(now, signals: [_signal('steps', 200, 'count', now)]),
    ).execute(topic: 'activity', from: now, through: now, checkAccess: allow);
    final row = _rows(result).single;
    expect((row['manualSteps'] as Map)['count'], 100);
    expect((row['connectedSteps'] as Map)['count'], 200);
    expect(row.containsKey('totalSteps'), isFalse);
    expect((await daily.getForDay(now))?.steps, 100);
  });

  test(
    'existing energy projection avoids counting daily and latest twice',
    () async {
      final native = _signal(
        'activeEnergy',
        321,
        'kcal',
        now,
        attributes: const {'aggregation': 'native_daily'},
      );
      final summary = _signal(
        'activeEnergy',
        321,
        'kcal',
        now,
        attributes: const {
          'historyProjection': 'daily_v1',
          'historyLocalDay': '2026-10-07',
          'historyAggregation': 'native_daily',
        },
      );
      final result = await queries(
        _snapshot(now, signals: [native], signalHistory: [summary]),
      ).execute(topic: 'activity', from: now, through: now, checkAccess: allow);
      final energy = _rows(result).single['connectedActiveEnergy'] as Map;
      expect(energy['value'], 321);
      expect(energy['historyAggregation'], 'native_daily');
    },
  );

  test(
    'stale degraded cache is identified and future signals are excluded',
    () async {
      final result =
          await queries(
            _snapshot(
              now,
              status: ConnectedHealthStatus.degraded,
              signals: [
                _signal('steps', 150, 'count', now),
                _signal('steps', 9999, 'count', DateTime(2026, 10, 8, 12)),
              ],
            ),
          ).execute(
            topic: 'activity',
            from: now,
            through: DateTime(2026, 10, 8),
            checkAccess: allow,
          );
      expect(_rows(result).length, 1);
      expect(result['missingDays'], ['2026-10-08']);
      expect(
        result['limitations'],
        contains('connected_source_degraded_cache_preserved'),
      );
    },
  );

  test(
    'only requested context is inspected and free text is excluded',
    () async {
      var snapshotReads = 0;
      final instance = CoachHealthQueries(
        database,
        connectedSnapshot: () {
          snapshotReads++;
          return const ConnectedHealthSnapshot.unavailable();
        },
        clock: () => now,
      );
      await instance.execute(
        topic: 'weight',
        from: now,
        through: now,
        checkAccess: allow,
      );
      expect(snapshotReads, 0);
      await daily.save(
        date: now,
        notes: 'private body context excluded',
        exerciseNotes: 'legacy private exercise notes',
      );
      final result = await instance.execute(
        topic: 'activity',
        from: now,
        through: now,
        checkAccess: allow,
      );
      expect(snapshotReads, 1);
      expect(_rows(result).single['hasUnstructuredExerciseNotes'], isTrue);
      expect(_rows(result).single['exercises'], isEmpty);
      expect(jsonEncode(result), isNot(contains('private')));
    },
  );

  test(
    'exercise payload has a global bound and keeps actual log fields only',
    () async {
      final entries = List.generate(
        40,
        (index) => jsonEncode({
          'id': 'synthetic-$index',
          'name': 'Walk',
          'minutes': 15,
          'recordedAt': now.toIso8601String(),
        }),
      );
      await daily.appendExerciseNotes(date: now, encodedEntries: entries);
      final result = await queries(
        const ConnectedHealthSnapshot.unavailable(),
      ).execute(topic: 'activity', from: now, through: now, checkAccess: allow);
      final row = _rows(result).single;
      expect((row['exercises'] as List).length, 31);
      expect(row['exerciseRecordsTruncated'], isTrue);
      expect(jsonEncode(row['exercises']), isNot(contains('completed')));
      expect((await daily.getForDay(now))!.exerciseNotes, entries.join('\n'));
    },
  );
}

List<Map<String, Object?>> _rows(Map<String, Object?> result) =>
    (result['rows'] as List).cast<Map<String, Object?>>();

ConnectedHealthSignalView _signal(
  String key,
  double value,
  String unit,
  DateTime observedAt, {
  Map<String, Object?> attributes = const {},
}) => ConnectedHealthSignalView(
  key: key,
  value: value,
  unit: unit,
  source: 'synthetic-native-source',
  observedAt: observedAt,
  confidence: 0.9,
  attributes: attributes,
);

// Synthetic provider-boundary fixture only; this is not device verification.
ConnectedHealthSnapshot _snapshot(
  DateTime now, {
  List<ConnectedHealthSignalView> signals = const [],
  List<ConnectedHealthSignalView> stepHistory = const [],
  List<ConnectedHealthSignalView> signalHistory = const [],
  bool verified = true,
  ConnectedHealthStatus status = ConnectedHealthStatus.synchronized,
}) => ConnectedHealthSnapshot(
  status: status,
  platformSource: 'synthetic_native_fixture',
  availableSources: const ['synthetic-native-source'],
  signals: signals,
  importedCount: signals.length + stepHistory.length + signalHistory.length,
  lastSyncAt: now,
  failureCode: null,
  deviceVerified: verified,
  stepHistory: stepHistory,
  signalHistory: signalHistory,
);
