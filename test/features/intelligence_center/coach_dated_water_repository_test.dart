import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/bil_tool_registry.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_native_command_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CoachNativeCommandRepository repository;
  late CoachNativeOwnerScope scope;
  var ownerEpoch = 0;
  final now = DateTime(2026, 1, 1, 0, 5, 20, 987, 456);
  final earlier = DateTime(2025, 12, 20);

  setUp(() {
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-a',
    );
    repository = CoachNativeCommandRepository(database);
    ownerEpoch = 0;
    scope = CoachNativeOwnerScope(
      ownerId: 'owner-a',
      isCurrent: () => ownerEpoch == 0,
    );
  });
  tearDown(() => database.close());

  Future<CoachNativeCommand> prepare({
    String operationId = 'water-explicit-day',
    Map<String, Object?> arguments = const {
      'amountMl': 250,
      'date': '2025-12-20',
    },
    CoachNativeCommandRepository? through,
    DateTime? at,
  }) => (through ?? repository).prepare(
    toolId: 'log_water',
    operationId: operationId,
    arguments: arguments,
    scope: scope,
    now: at ?? now,
  );

  Future<CoachNativeCommit> undo(CoachNativeCommit result) => repository.undo(
    operationId: result.operationId,
    toolId: result.toolId,
    argumentsDigest: result.argumentsDigest,
    scope: scope,
  );

  test(
    'explicit water date commits to that local day with authoritative receipt',
    () async {
      final water = WaterRepository(database);
      await water.add(occurredAt: now, amountMl: 700);
      final command = await prepare();
      final result = await repository.commit(command: command, scope: scope);
      expect(await water.totalForDay(earlier), 250);
      expect(await water.totalForDay(now), 700);
      expect(result.state, CoachNativeResultState.committed);
      final row = result.current.water!;
      expect(row.occurredAt, earlier);
      expect(row.dayKey, '2025-12-20');
      expect(result.after.receiptPayload(command), {
        'exists': true,
        'uuid': row.uuid,
        'revision': row.revision,
        'amount_ml': 250,
        'occurred_at': earlier.toIso8601String(),
        'day': '2025-12-20',
      });
    },
  );

  for (final example in <(String, String)>[
    ('Log 250 ml water yesterday', '2025-12-31'),
    ('سجل ٢٥٠ مل ماء امس', '2025-12-31'),
    ('Yesterday log 250 ml water on 2025-12-20', '2025-12-20'),
  ]) {
    test(
      'parsed local date reaches actual repository unchanged: ${example.$1}',
      () async {
        final action = const LocalCoachCommandParser()
            .parse(example.$1, referenceLocal: now)
            .single;
        final command = await prepare(arguments: action.payload);
        final result = await repository.commit(command: command, scope: scope);
        expect(result.current.water!.dayKey, example.$2);
        expect(result.current.water!.amountMl, 250);
        expect(await WaterRepository(database).totalForDay(now), 0);
        expect(
          await WaterRepository(
            database,
          ).totalForDay(DateTime.parse(example.$2)),
          250,
        );
      },
    );
  }

  test(
    'date absence keeps the original timestamp precision and current day',
    () async {
      final command = await prepare(arguments: const {'amountMl': 250});
      final result = await repository.commit(command: command, scope: scope);
      final expected = DateTime.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch ~/ 1000 * 1000,
        isUtc: now.isUtc,
      );
      expect(command.arguments, {'amountMl': 250});
      expect(command.resolved.containsKey('date'), isFalse);
      expect(result.current.water!.occurredAt, expected);
      expect(result.current.water!.dayKey, '2026-01-01');
      expect(await WaterRepository(database).totalForDay(now), 250);
    },
  );

  test(
    'concurrent replay and repository recreation preserve the original dated operation',
    () async {
      final command = await prepare();
      final results = await Future.wait([
        repository.commit(command: command, scope: scope),
        repository.commit(command: command, scope: scope),
      ]);
      expect(results.where((result) => result.replayed), hasLength(1));
      final reopened = CoachNativeCommandRepository(database);
      final restored = await prepare(
        through: reopened,
        at: now.add(const Duration(days: 3)),
      );
      expect(restored.argumentsDigest, command.argumentsDigest);
      expect(restored.resolved, command.resolved);
      final replay = await reopened.commit(command: restored, scope: scope);
      expect(replay.replayed, isTrue);
      expect(await WaterRepository(database).totalForDay(earlier), 250);
      expect(await database.select(database.waterEntries).get(), hasLength(1));
      expect(await WaterRepository(database).totalForDay(now), 0);
    },
  );

  test('one operation cannot be replayed onto another date', () async {
    final command = await prepare();
    await repository.commit(command: command, scope: scope);
    await expectLater(
      prepare(arguments: const {'amountMl': 250, 'date': '2025-12-21'}),
      throwsA(
        isA<CoachNativeConflict>().having(
          (error) => error.reason,
          'reason',
          CoachNativeConflictReason.operationMismatch,
        ),
      ),
    );
    expect(await WaterRepository(database).totalForDay(earlier), 250);
    expect(
      await WaterRepository(database).totalForDay(DateTime(2025, 12, 21)),
      0,
    );
  });

  test(
    'dated Undo restores the actual day while keeping unrelated water entries',
    () async {
      final water = WaterRepository(database);
      final unrelated = await water.add(
        occurredAt: earlier.add(const Duration(hours: 10)),
        amountMl: 100,
      );
      await water.add(occurredAt: now, amountMl: 700);
      final command = await prepare();
      final committed = await repository.commit(command: command, scope: scope);
      final result = await undo(committed);
      expect(result.state, CoachNativeResultState.undone);
      expect(await water.totalForDay(earlier), 100);
      expect(await water.totalForDay(now), 700);
      final kept = await (database.select(
        database.waterEntries,
      )..where((row) => row.id.equals(unrelated))).getSingle();
      expect(kept.deletedAt, isNull);
      expect(kept.amountMl, 100);
      final replay = await repository.commit(command: command, scope: scope);
      expect(replay.state, CoachNativeResultState.undone);
      expect(await water.totalForDay(earlier), 100);
    },
  );

  test(
    'dated Undo refuses a later edit instead of overwriting the current row',
    () async {
      final command = await prepare();
      final committed = await repository.commit(command: command, scope: scope);
      final prior = committed.after.water!;
      await (database.update(
        database.waterEntries,
      )..where((row) => row.id.equals(prior.id))).write(
        WaterEntriesCompanion(
          amountMl: const Value(300),
          revision: Value(prior.revision + 1),
        ),
      );
      await expectLater(
        undo(committed),
        throwsA(
          isA<CoachNativeConflict>().having(
            (error) => error.reason,
            'reason',
            CoachNativeConflictReason.staleRecord,
          ),
        ),
      );
      expect(await WaterRepository(database).totalForDay(earlier), 300);
    },
  );

  test(
    'account A to B to A during the dated write rolls back the old operation',
    () async {
      final paused = _PausedWaterRepository(database);
      final through = CoachNativeCommandRepository(database, water: paused);
      final command = await prepare(through: through);
      final pending = expectLater(
        through.commit(command: command, scope: scope),
        throwsA(
          isA<CoachNativeConflict>()
              .having(
                (error) => error.reason,
                'reason',
                CoachNativeConflictReason.ownerChanged,
              )
              .having((error) => error.committed, 'committed', isFalse),
        ),
      );
      await paused.entered.future;
      ownerEpoch = 1; // B
      ownerEpoch = 2; // Return to A is a new lifetime.
      paused.release.complete();
      await pending;
      expect(await database.select(database.waterEntries).get(), isEmpty);
      expect(await database.select(database.preferences).get(), isEmpty);
    },
  );

  for (final invalid in [
    '2026-02-30',
    '2026-2-03',
    '2026-01-01T00:00:00Z',
    'yesterday',
    20260101,
  ]) {
    test(
      'water registry and repository reject a noncanonical date: $invalid',
      () async {
        final arguments = {'amountMl': 250, 'date': invalid};
        expect(
          const BilToolRegistry()
              .lookup('log_water')!
              .validateArguments(arguments),
          isNull,
        );
        await expectLater(prepare(arguments: arguments), throwsArgumentError);
        expect(await database.select(database.waterEntries).get(), isEmpty);
      },
    );
  }
}

class _PausedWaterRepository extends WaterRepository {
  _PausedWaterRepository(super.database);
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<int> add({required DateTime occurredAt, required int amountMl}) async {
    entered.complete();
    await release.future;
    return super.add(occurredAt: occurredAt, amountMl: amountMl);
  }
}
