import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/life_context_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_daily_commands.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_adapter.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_life_context_commands.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_native_command_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Store store;
  setUp(() => store = _Store());
  tearDown(() => store.database.close());

  test(
    'empty day closes with unknown totals and Undo restores absence',
    () async {
      final command = await store.prepare('close_day', const {});
      expect(command.before.receiptPayload(command)['day_state'], 'notStarted');
      final committed = await store.commit(command);
      final saved = (await store.daily.getForDay(_day))!;
      expect(saved.lifecycleState, 'closed');
      expect(saved.closedAt, isNotNull);
      final receipt = committed.current.receiptPayload(command);
      expect(receipt['day_state'], 'closed');
      for (final key in [
        'calories',
        'protein',
        'carbohydrates',
        'fat',
        'fiber',
        'net_carbohydrates',
      ]) {
        expect(receipt[key], isNull, reason: 'Absent evidence: $key');
      }
      expect(await store.database.select(store.database.meals).get(), isEmpty);
      expect(
        await store.database.select(store.database.mealItems).get(),
        isEmpty,
      );
      final undone = await store.undo(committed);
      expect(undone.state, CoachNativeResultState.undone);
      expect(await store.daily.getForDay(_day), isNull);
    },
  );

  test(
    'close freezes real meal totals; reopen exposes current source totals',
    () async {
      await store.daily.save(
        date: _day,
        notes: 'Synthetic note',
        sleepHours: 7,
        steps: 4321,
        exerciseNotes: 'Existing activity',
      );
      final itemId = await _seedMeal(store.database);
      final prior = (await store.daily.getForDay(_day))!;
      final close = await store.commit(
        await store.prepare('close_day', const {}),
      );
      final closed = close.current.receiptPayload(close.command);
      expect(closed['calories'], 200);
      expect(closed['protein'], 10);
      expect(closed['fiber'], 8);
      expect(closed['net_carbohydrates'], 22);
      // A direct database fixture simulates newer imported source evidence. The
      // normal food API's closed-day guard is tested in its own integration suite.
      await (store.database.update(store.database.mealItems)
            ..where((row) => row.id.equals(itemId)))
          .write(const MealItemsCompanion(calories: Value(250)));
      expect((await store.daily.readLedger(_day)).calories, 200);
      final reopen = await store.commit(
        await store.prepare('reopen_day', const {}),
      );
      expect(reopen.current.receiptPayload(reopen.command)['calories'], 250);
      final saved = (await store.daily.getForDay(_day))!;
      expect(saved.lifecycleState, 'open');
      expect(saved.closedAt, isNull);
      expect(saved.uuid, prior.uuid);
      expect(saved.notes, prior.notes);
      expect(saved.sleepHours, prior.sleepHours);
      expect(saved.steps, prior.steps);
      expect(saved.exerciseNotes, prior.exerciseNotes);
    },
  );

  test(
    'manual zero sleep is distinct from absent sleep and Undo restores absence',
    () async {
      final command = await store.prepare('log_sleep', {'hours': 0});
      expect(command.before.receiptPayload(command)['sleep_hours'], isNull);
      final committed = await store.commit(command);
      expect((await store.daily.getForDay(_day))!.sleepHours, 0);
      final receipt = committed.current.receiptPayload(command);
      expect(receipt['sleep_hours'], 0);
      expect(receipt['source'], 'manual');
      expect(receipt['recorded_at'], _now.toUtc().toIso8601String());
      expect(
        receipt['time_zone_offset_minutes'],
        _now.timeZoneOffset.inMinutes,
      );
      await store.undo(committed);
      expect(await store.daily.getForDay(_day), isNull);
    },
  );

  test(
    'sleep write preserves notes, steps, activity and record identity',
    () async {
      await store.daily.save(
        date: _day,
        notes: 'Keep body context',
        steps: 6200,
        exerciseNotes: 'Keep recorded workout',
      );
      final prior = (await store.daily.getForDay(_day))!;
      final committed = await store.commit(
        await store.prepare('log_sleep', {'hours': 6.25}),
      );
      final saved = (await store.daily.getForDay(_day))!;
      expect(saved.sleepHours, 6.25);
      expect(saved.id, prior.id);
      expect(saved.uuid, prior.uuid);
      expect(saved.notes, prior.notes);
      expect(saved.steps, prior.steps);
      expect(saved.exerciseNotes, prior.exerciseNotes);
      await store.undo(committed);
      expect((await store.daily.getForDay(_day))!.toJson(), prior.toJson());
    },
  );

  test(
    'day-note replacement and Undo preserve every unrelated daily field',
    () async {
      await store.daily.save(
        date: _day,
        notes: 'Earlier note',
        sleepHours: 7.5,
        steps: 5000,
        exerciseNotes: 'Synthetic workout',
      );
      final prior = (await store.daily.getForDay(_day))!;
      final committed = await store.commit(
        await store.prepare('save_day_note', {'text': '  Corrected note  '}),
      );
      final saved = (await store.daily.getForDay(_day))!;
      expect(saved.notes, 'Corrected note');
      expect(saved.sleepHours, prior.sleepHours);
      expect(saved.steps, prior.steps);
      expect(saved.exerciseNotes, prior.exerciseNotes);
      expect(saved.uuid, prior.uuid);
      expect(await store.daily.getAll(), hasLength(1));
      await store.undo(committed);
      expect((await store.daily.getForDay(_day))!.toJson(), prior.toJson());
    },
  );

  for (final marker in ['lifecycle', 'timestamp']) {
    test('sleep and note reject a day closed by its $marker marker', () async {
      await _seedClosure(store, marker);
      final prior = (await store.daily.getForDay(_day))!.toJson();
      for (final input in [
        ('log_sleep', <String, Object?>{'hours': 7}),
        ('save_day_note', <String, Object?>{'text': 'Must not save'}),
      ]) {
        final command = await store.prepare(input.$1, input.$2);
        await expectLater(store.commit(command), throwsStateError);
      }
      expect((await store.daily.getForDay(_day))!.toJson(), prior);
      expect(await store.journals(), isEmpty);
    });
  }

  test(
    'timestamp-only closure is reported closed and explicit reopen clears it',
    () async {
      await _seedClosure(store, 'timestamp');
      final command = await store.prepare('reopen_day', const {});
      expect(command.before.receiptPayload(command)['day_state'], 'closed');
      final committed = await store.commit(command);
      final saved = (await store.daily.getForDay(_day))!;
      expect(saved.lifecycleState, 'open');
      expect(saved.closedAt, isNull);
      expect(committed.current.receiptPayload(command)['day_state'], 'open');
      await store.undo(committed);
      expect((await store.daily.getForDay(_day))!.closedAt, isNotNull);
    },
  );

  test(
    'explicit close repairs a legacy closed state missing its timestamp',
    () async {
      await _seedClosure(store, 'lifecycle');
      final command = await store.prepare('close_day', const {});
      final committed = await store.commit(command);
      final saved = (await store.daily.getForDay(_day))!;
      expect(saved.lifecycleState, 'closed');
      expect(saved.closedAt, isNotNull);
      await store.undo(committed);
      expect((await store.daily.getForDay(_day))!.closedAt, isNull);
    },
  );

  test(
    'reopening a missing day creates no data or operation journal',
    () async {
      final command = await store.prepare('reopen_day', const {});
      await expectLater(store.commit(command), throwsStateError);
      expect(await store.daily.getForDay(_day), isNull);
      expect(await store.journals(), isEmpty);
    },
  );

  test(
    'invalid and future calendar days are rejected before any write',
    () async {
      for (final date in [
        '2026-02-30',
        '2026-10-08',
        '2026-1-07',
        '2026-10-07T00:00:00Z',
      ]) {
        await expectLater(
          store.prepare('log_sleep', {'date': date, 'hours': 7}),
          throwsArgumentError,
        );
      }
      expect(await store.daily.getAll(), isEmpty);
      expect(await store.journals(), isEmpty);
    },
  );

  test(
    'invalid sleep duration and empty or oversized notes are rejected',
    () async {
      for (final hours in <Object?>[
        -1,
        14.1,
        double.nan,
        double.infinity,
        '7',
        null,
      ]) {
        await expectLater(
          store.prepare('log_sleep', {'hours': hours}),
          throwsArgumentError,
        );
      }
      for (final note in <Object?>['', '  ', 'x' * 1001, true]) {
        await expectLater(
          store.prepare('save_day_note', {'text': note}),
          throwsArgumentError,
        );
      }
      expect(await store.daily.getAll(), isEmpty);
      expect(await store.journals(), isEmpty);
    },
  );

  test(
    'daily operation survives repository restart and replay never redoes Undo',
    () async {
      const operationId = 'daily-restart-operation';
      final command = await store.prepare('log_sleep', {
        'hours': 7,
      }, operationId: operationId);
      final first = await store.commit(command);
      final restarted = store.makeRepository();
      final recovered = await restarted.readOperation(
        operationId: operationId,
        scope: store.scope,
      );
      expect(recovered?.state, CoachNativeResultState.committed);
      final replay = await restarted.commit(
        command: command,
        scope: store.scope,
      );
      expect(replay.replayed, isTrue);
      expect(await store.daily.getAll(), hasLength(1));
      expect(await store.journals(), hasLength(1));
      await store.undo(first, repository: restarted);
      final repeated = await restarted.commit(
        command: command,
        scope: store.scope,
      );
      expect(repeated.state, CoachNativeResultState.undone);
      expect(repeated.replayed, isTrue);
      expect(await store.daily.getForDay(_day), isNull);
    },
  );

  test(
    'a later manual daily change rejects both stale commit and stale Undo',
    () async {
      await store.daily.save(date: _day, notes: 'Before');
      final stale = await store.prepare('log_sleep', {'hours': 7});
      await store.daily.saveBodyContext(date: _day, notes: 'Manual correction');
      await expectLater(
        store.commit(stale),
        _nativeConflict(CoachNativeConflictReason.staleRecord),
      );
      final committed = await store.commit(
        await store.prepare('log_sleep', {'hours': 7}),
      );
      await store.daily.saveBodyContext(
        date: _day,
        notes: 'Another correction',
      );
      await expectLater(
        store.undo(committed),
        _nativeConflict(CoachNativeConflictReason.staleRecord),
      );
      expect((await store.daily.getForDay(_day))!.notes, 'Another correction');
    },
  );

  test(
    'owner revocation rejects a prepared daily command without a journal',
    () async {
      final command = await store.prepare('log_sleep', {'hours': 7});
      store.scope.cancel();
      await expectLater(
        store.commit(command),
        _nativeConflict(CoachNativeConflictReason.ownerChanged),
      );
      expect(await store.daily.getForDay(_day), isNull);
      expect(await store.journals(), isEmpty);
    },
  );

  test(
    'Undo permission rejection preserves daily data and committed operation',
    () async {
      final committed = await store.commit(
        await store.prepare('log_sleep', {'hours': 7}),
      );
      await expectLater(
        store.repository.undo(
          operationId: committed.operationId,
          toolId: committed.toolId,
          argumentsDigest: committed.argumentsDigest,
          scope: store.scope,
          checkWritePermission: () =>
              throw StateError('Synthetic denied permission'),
        ),
        throwsStateError,
      );
      expect((await store.daily.getForDay(_day))!.sleepHours, 7);
      expect(
        (await store.repository.readOperation(
          operationId: committed.operationId,
          scope: store.scope,
        ))!.state,
        CoachNativeResultState.committed,
      );
    },
  );

  test(
    'daily write readback exception rolls back actual data and native journal',
    () async {
      final failing = _FailingDailyRepository(store.database)
        ..failAfterSleep = true;
      final repository = store.makeRepository(daily: failing);
      final command = await store.prepare('log_sleep', {
        'hours': 7,
      }, repository: repository);
      await expectLater(
        store.commit(command, repository: repository),
        throwsStateError,
      );
      expect(await store.daily.getForDay(_day), isNull);
      expect(await store.journals(), isEmpty);
    },
  );

  test(
    'failed compensation readback rolls Undo back with its journal untouched',
    () async {
      await store.daily.save(date: _day, notes: 'Before', sleepHours: 6);
      final committed = await store.commit(
        await store.prepare('log_sleep', {'hours': 7}),
      );
      final saved = (await store.daily.getForDay(_day))!.toJson();
      final failing = _FailingDailyRepository(store.database);
      final repository = store.makeRepository(
        daily: failing,
        restoreRecord: ({required date, required prior}) async {
          await store.daily.restoreCoachRecord(date: date, prior: prior);
          failing.failRead = true;
        },
      );
      await expectLater(
        store.undo(committed, repository: repository),
        throwsStateError,
      );
      expect((await store.daily.getForDay(_day))!.toJson(), saved);
      expect(
        (await store.repository.readOperation(
          operationId: committed.operationId,
          scope: store.scope,
        ))!.state,
        CoachNativeResultState.committed,
      );
    },
  );

  test(
    'life context missing consent defaults to false in the real repository',
    () async {
      final command = await store.prepare('save_life_context', {
        'type': 'travel',
        'text': 'Synthetic trip context',
      });
      final committed = await store.commit(command);
      final row = (await store.life.getByUuid(
        command.resolved['uuid']! as String,
      ))!;
      expect(row.useInInsights, isFalse);
      expect(row.uuid, command.resolved['uuid']);
      expect(row.dayKey, dayKeyFor(_day));
      expect(row.occurredAt, _day);
      expect(await store.life.watchAllForInsights().first, isEmpty);
      expect(
        committed.current.receiptPayload(command)['use_in_insights'],
        isFalse,
      );
    },
  );

  test(
    'explicit life-context consent, type and exact trimmed text are persisted',
    () async {
      final command = await store.prepare('save_life_context', {
        'type': 'stress',
        'text': '  Synthetic context\nSecond line.  ',
        'useInInsights': true,
      });
      final committed = await store.commit(command);
      final row = (await store.life.getByUuid(
        command.resolved['uuid']! as String,
      ))!;
      expect(row.type, 'stress');
      expect(row.details, 'Synthetic context\nSecond line.');
      expect(row.useInInsights, isTrue);
      expect(await store.life.watchAllForInsights().first, hasLength(1));
      expect(committed.current.receiptPayload(command)['source'], 'manual');
    },
  );

  test('life context rejects invalid type, consent, text and date', () async {
    final cases = <Map<String, Object?>>[
      {'type': 'unsupported'},
      {'useInInsights': 'false'},
      {'text': ''},
      {'text': 'x' * 1001},
      {'date': '2026-10-08'},
      {'date': '2026-02-30'},
    ];
    for (final replacement in cases) {
      await expectLater(
        store.prepare('save_life_context', {
          'type': 'other',
          'text': 'Synthetic context',
          'useInInsights': false,
          ...replacement,
        }),
        throwsArgumentError,
      );
    }
    expect(
      await store.database.select(store.database.lifeContextEntries).get(),
      isEmpty,
    );
    expect(await store.journals(), isEmpty);
  });

  test(
    'life-context Undo uses the same UUID tombstone without losing other fields',
    () async {
      final command = await store.prepare('save_life_context', {
        'type': 'event',
        'text': 'Synthetic diary event',
        'useInInsights': false,
      });
      final committed = await store.commit(command);
      final before = (await store.life.getByUuid(
        command.resolved['uuid']! as String,
      ))!;
      final undone = await store.undo(committed);
      final row = (await store.life.getByUuid(before.uuid))!;
      expect(row.id, before.id);
      expect(row.uuid, before.uuid);
      expect(row.deletedAt, isNotNull);
      expect(row.revision, before.revision + 1);
      expect(row.syncStatus, 'pendingDelete');
      expect(row.type, before.type);
      expect(row.details, before.details);
      expect(row.useInInsights, before.useInInsights);
      expect(undone.state, CoachNativeResultState.undone);
      expect(undone.current.receiptPayload(command)['exists'], isFalse);
      expect(await store.life.watchForDay(_day).first, isEmpty);
    },
  );

  test(
    'life-context restart and replay never add a second record or resurrect Undo',
    () async {
      const operationId = 'life-context-restart-operation';
      final args = <String, Object?>{
        'type': 'other',
        'text': 'Synthetic record',
        'useInInsights': false,
      };
      final command = await store.prepare(
        'save_life_context',
        args,
        operationId: operationId,
      );
      final committed = await store.commit(command);
      final restarted = store.makeRepository();
      final restored = await store.prepare(
        'save_life_context',
        args,
        operationId: operationId,
        repository: restarted,
      );
      expect(restored.argumentsDigest, command.argumentsDigest);
      final replay = await store.commit(restored, repository: restarted);
      expect(replay.replayed, isTrue);
      expect(
        await store.database.select(store.database.lifeContextEntries).get(),
        hasLength(1),
      );
      expect(await store.journals(), hasLength(1));
      await store.undo(committed, repository: restarted);
      final again = await store.commit(restored, repository: restarted);
      expect(again.state, CoachNativeResultState.undone);
      expect(await store.life.watchForDay(_day).first, isEmpty);
      expect(
        await store.database.select(store.database.lifeContextEntries).get(),
        hasLength(1),
      );
    },
  );

  test(
    'life-context write on the wrong date fails real readback and rolls back',
    () async {
      final repository = store.makeRepository(
        lifeAdapter: CoachLifeContextCommandAdapter(
          repository: store.life,
          readByUuid: store.life.getByUuid,
          addWithUuid:
              ({
                required uuid,
                required occurredAt,
                required type,
                required details,
                required useInInsights,
              }) => store.life.add(
                uuid: uuid,
                occurredAt: occurredAt.add(const Duration(days: 1)),
                type: type,
                details: details,
                useInInsights: useInInsights,
              ),
        ),
      );
      final command = await store.prepare('save_life_context', {
        'type': 'other',
        'text': 'Synthetic context',
        'useInInsights': false,
      }, repository: repository);
      await expectLater(
        store.commit(command, repository: repository),
        throwsStateError,
      );
      expect(
        await store.database.select(store.database.lifeContextEntries).get(),
        isEmpty,
      );
      expect(await store.journals(), isEmpty);
    },
  );

  test(
    'life-context wrong UUID cannot be accepted as the requested identity',
    () async {
      Future<LifeContextEntry?> wrongReader(String _) async {
        final rows = await store.database
            .select(store.database.lifeContextEntries)
            .get();
        return rows.isEmpty ? null : rows.single;
      }

      final repository = store.makeRepository(
        lifeAdapter: CoachLifeContextCommandAdapter(
          repository: store.life,
          readByUuid: wrongReader,
          addWithUuid:
              ({
                required uuid,
                required occurredAt,
                required type,
                required details,
                required useInInsights,
              }) => store.life.add(
                uuid: 'synthetic-wrong-uuid',
                occurredAt: occurredAt,
                type: type,
                details: details,
                useInInsights: useInInsights,
              ),
        ),
      );
      final command = await store.prepare('save_life_context', {
        'type': 'other',
        'text': 'Synthetic context',
        'useInInsights': false,
      }, repository: repository);
      await expectLater(
        store.commit(command, repository: repository),
        throwsStateError,
      );
      expect(
        await store.database.select(store.database.lifeContextEntries).get(),
        isEmpty,
      );
      expect(await store.journals(), isEmpty);
    },
  );

  test(
    'life-context readback exception rolls data and operation journal back',
    () async {
      var armed = false;
      final repository = store.makeRepository(
        lifeAdapter: CoachLifeContextCommandAdapter(
          repository: store.life,
          readByUuid: (uuid) {
            if (armed) throw StateError('Synthetic readback unavailable');
            return store.life.getByUuid(uuid);
          },
          addWithUuid:
              ({
                required uuid,
                required occurredAt,
                required type,
                required details,
                required useInInsights,
              }) async {
                final id = await store.life.add(
                  uuid: uuid,
                  occurredAt: occurredAt,
                  type: type,
                  details: details,
                  useInInsights: useInInsights,
                );
                armed = true;
                return id;
              },
        ),
      );
      final command = await store.prepare('save_life_context', {
        'type': 'other',
        'text': 'Synthetic context',
        'useInInsights': false,
      }, repository: repository);
      await expectLater(
        store.commit(command, repository: repository),
        throwsStateError,
      );
      expect(
        await store.database.select(store.database.lifeContextEntries).get(),
        isEmpty,
      );
      expect(await store.journals(), isEmpty);
    },
  );

  test(
    'owner revocation after life-context insertion rolls back before commit',
    () async {
      final repository = store.makeRepository(
        lifeAdapter: CoachLifeContextCommandAdapter(
          repository: store.life,
          readByUuid: store.life.getByUuid,
          addWithUuid:
              ({
                required uuid,
                required occurredAt,
                required type,
                required details,
                required useInInsights,
              }) async {
                final id = await store.life.add(
                  uuid: uuid,
                  occurredAt: occurredAt,
                  type: type,
                  details: details,
                  useInInsights: useInInsights,
                );
                store.scope.cancel();
                return id;
              },
        ),
      );
      final command = await store.prepare('save_life_context', {
        'type': 'other',
        'text': 'Synthetic context',
        'useInInsights': false,
      }, repository: repository);
      await expectLater(
        store.commit(command, repository: repository),
        _nativeConflict(CoachNativeConflictReason.ownerChanged),
      );
      expect(
        await store.database.select(store.database.lifeContextEntries).get(),
        isEmpty,
      );
      expect(await store.journals(), isEmpty);
    },
  );

  test('later consent edit blocks stale life-context Undo', () async {
    final command = await store.prepare('save_life_context', {
      'type': 'other',
      'text': 'Synthetic context',
      'useInInsights': false,
    });
    final committed = await store.commit(command);
    final row = (await store.life.getByUuid(
      command.resolved['uuid']! as String,
    ))!;
    await store.life.setInsightConsent(row.id, true);
    await expectLater(
      store.undo(committed),
      _nativeConflict(CoachNativeConflictReason.staleRecord),
    );
    final current = (await store.life.getByUuid(row.uuid))!;
    expect(current.useInInsights, isTrue);
    expect(current.deletedAt, isNull);
  });
}

final _day = DateTime(2026, 10, 7);
final _now = DateTime(2026, 10, 7, 12, 34, 56);

Matcher _nativeConflict(CoachNativeConflictReason reason) => throwsA(
  isA<CoachNativeConflict>().having((error) => error.reason, 'reason', reason),
);

class _Store {
  _Store()
    : database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'synthetic-owner',
      );

  final AppDatabase database;
  late final daily = DailyLogRepository(database);
  late final life = LifeContextRepository(database);
  late final repository = makeRepository();
  final scope = CoachNativeOwnerScope(
    ownerId: 'synthetic-owner',
    isCurrent: () => true,
  );
  var _next = 0;

  CoachNativeCommandRepository makeRepository({
    DailyLogRepository? daily,
    CoachDailyRecordRestorer? restoreRecord,
    CoachHealthCommandAdapter? lifeAdapter,
  }) => CoachNativeCommandRepository(
    database,
    healthCommands: CoachHealthAdapters([
      CoachDailyCommandAdapter(
        daily: daily ?? this.daily,
        restoreRecord: restoreRecord ?? this.daily.restoreCoachRecord,
      ),
      lifeAdapter ??
          CoachLifeContextCommandAdapter(
            repository: life,
            readByUuid: life.getByUuid,
            addWithUuid:
                ({
                  required uuid,
                  required occurredAt,
                  required type,
                  required details,
                  required useInInsights,
                }) => life.add(
                  uuid: uuid,
                  occurredAt: occurredAt,
                  type: type,
                  details: details,
                  useInInsights: useInInsights,
                ),
          ),
    ]),
  );

  Future<CoachNativeCommand> prepare(
    String toolId,
    Map<String, Object?> arguments, {
    String? operationId,
    CoachNativeCommandRepository? repository,
  }) => (repository ?? this.repository).prepare(
    toolId: toolId,
    operationId: operationId ?? 'daily-life-operation-${_next++}',
    arguments: {'date': dayKeyFor(_day), ...arguments},
    scope: scope,
    now: _now,
  );

  Future<CoachNativeCommit> commit(
    CoachNativeCommand command, {
    CoachNativeCommandRepository? repository,
  }) => (repository ?? this.repository).commit(command: command, scope: scope);

  Future<CoachNativeCommit> undo(
    CoachNativeCommit commit, {
    CoachNativeCommandRepository? repository,
  }) => (repository ?? this.repository).undo(
    operationId: commit.operationId,
    toolId: commit.toolId,
    argumentsDigest: commit.argumentsDigest,
    scope: scope,
  );

  Future<List<String>> journals() async =>
      (await database.select(database.preferences).get())
          .where((row) => row.key.startsWith('coachNativeOperationV1.'))
          .map((row) => row.value)
          .toList();
}

Future<void> _seedClosure(_Store store, String marker) => store.database
    .into(store.database.dailyLogs)
    .insert(
      DailyLogsCompanion.insert(
        date: _day,
        dayKey: dayKeyFor(_day),
        notes: const Value('Prior context'),
        lifecycleState: Value(marker == 'lifecycle' ? 'closed' : 'open'),
        closedAt: Value(marker == 'timestamp' ? _now : null),
      ),
    )
    .then((_) {});

Future<int> _seedMeal(AppDatabase database) async {
  final foodId = await database
      .into(database.foods)
      .insert(
        FoodsCompanion.insert(
          name: 'Synthetic known meal',
          calories: 200,
          protein: 10,
          carbs: 30,
          fats: 5,
        ),
      );
  final mealId = await database
      .into(database.meals)
      .insert(
        MealsCompanion.insert(
          date: _day,
          dayKey: dayKeyFor(_day),
          type: const Value('lunch'),
        ),
      );
  return database
      .into(database.mealItems)
      .insert(
        MealItemsCompanion.insert(
          mealId: mealId,
          foodId: foodId,
          calories: const Value(200),
          protein: const Value(10),
          carbs: const Value(30),
          fats: const Value(5),
          fiber: const Value(8),
          nutrientEvidenceMask: Value(
            NutrientEvidenceMask.bit(TrackedNutrient.fiber),
          ),
        ),
      );
}

class _FailingDailyRepository extends DailyLogRepository {
  _FailingDailyRepository(super.database);
  var failAfterSleep = false;
  var failRead = false;

  @override
  Future<void> updateSleepHours({
    required DateTime date,
    required double sleepHours,
  }) async {
    await super.updateSleepHours(date: date, sleepHours: sleepHours);
    if (failAfterSleep) failRead = true;
  }

  @override
  Future<DailyLog?> getForDay(DateTime date) {
    if (failRead) throw StateError('Synthetic daily readback failure');
    return super.getForDay(date);
  }
}
