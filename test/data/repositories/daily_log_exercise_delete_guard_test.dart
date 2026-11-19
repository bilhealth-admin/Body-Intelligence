import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/daily_log/domain/daily_exercise_notes_codec.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _first =
    '{"id":"bench","name":"Bench push-up","minutes":10,"recordedAt":"2026-11-17T08:00:00Z"}';
const _second =
    '{"id":"bench","name":"Bench push-up","minutes":20,"recordedAt":"2026-11-17T09:00:00Z"}';
const _raw = 'Manual note\n$_first\n$_second';

void main() {
  late AppDatabase database;
  late DailyLogRepository repository;
  late _RetireAfterDailyUpdate interceptor;
  final day = DateTime(2026, 11, 17);
  final neighbour = DateTime(2026, 11, 16);

  setUp(() async {
    interceptor = _RetireAfterDailyUpdate();
    database = AppDatabase.forTesting(
      NativeDatabase.memory().interceptWith(interceptor),
      localOwnerId: 'a',
    );
    repository = DailyLogRepository(database);
    await repository.save(
      date: day,
      notes: 'Private note',
      sleepHours: 7.5,
      steps: 9000,
      exerciseNotes: _raw,
    );
    await repository.save(
      date: neighbour,
      notes: 'Other day',
      exerciseNotes: _raw,
    );
    await (database.update(
      database.dailyLogs,
    )..where((row) => row.dayKey.equals('2026-11-17'))).write(
      const DailyLogsCompanion(
        calories: Value(2100),
        protein: Value(120),
        carbs: Value(270),
        fats: Value(60),
        finalFiber: Value(22),
        finalNutrientEvidenceMask: Value(31),
      ),
    );
  });
  tearDown(() => database.close());

  Future<void> remove(
    DailyLog expected, {
    DailyLogRepository? through,
    bool Function()? isCurrent,
    String? expectedUuid,
  }) {
    final entry = DailyExerciseNotesCodec.decode(
      expected.exerciseNotes,
    ).entries[1];
    return (through ?? repository).saveNotesAtomically(
      date: day,
      expectedRecordUuid: expectedUuid ?? expected.uuid,
      expectedNotes: expected.notes,
      expectedExerciseNotes: expected.exerciseNotes,
      notes: expected.notes,
      exerciseNotes: DailyExerciseNotesCodec.removeEntry(
        expected.exerciseNotes!,
        entry,
      ),
      isCurrent: isCurrent ?? () => true,
    );
  }

  test(
    'actual narrow transaction deletes only selected exercise and preserves all other fields',
    () async {
      final before = (await repository.getForDay(day))!;
      final otherBefore = (await repository.getForDay(neighbour))!;
      await remove(before);
      final after = (await repository.getForDay(day))!;
      expect(after.exerciseNotes, 'Manual note\n$_first\n');
      final priorFields = before.toJson()
        ..remove('exerciseNotes')
        ..remove('updatedAt');
      final currentFields = after.toJson()
        ..remove('exerciseNotes')
        ..remove('updatedAt');
      expect(currentFields, priorFields);
      expect(
        (await repository.getForDay(neighbour))!.toJson(),
        otherBefore.toJson(),
      );
    },
  );

  test(
    'record UUID guard rejects even identical notes in another record',
    () async {
      final before = (await repository.getForDay(day))!;
      await expectLater(
        remove(before, expectedUuid: 'different-record'),
        throwsStateError,
      );
      expect((await repository.getForDay(day))!.toJson(), before.toJson());
      await (database.delete(
        database.dailyLogs,
      )..where((row) => row.id.equals(before.id))).go();
      await repository.save(
        date: day,
        notes: before.notes,
        exerciseNotes: before.exerciseNotes,
      );
      final replacement = (await repository.getForDay(day))!;
      expect(replacement.uuid, isNot(before.uuid));
      await expectLater(remove(before), throwsStateError);
      expect((await repository.getForDay(day))!.toJson(), replacement.toJson());
    },
  );

  test('concurrent plain or structured note changes are preserved', () async {
    final before = (await repository.getForDay(day))!;
    await (database.update(
      database.dailyLogs,
    )..where((row) => row.id.equals(before.id))).write(
      const DailyLogsCompanion(
        notes: Value('New private note'),
        exerciseNotes: Value('$_raw\nConcurrent note'),
      ),
    );
    final changed = (await repository.getForDay(day))!;
    await expectLater(remove(before), throwsStateError);
    expect((await repository.getForDay(day))!.toJson(), changed.toJson());
  });

  test(
    'closed diary refuses deletion and preserves the complete snapshot',
    () async {
      await repository.closeDay(day);
      final closed = (await repository.getForDay(day))!;
      await expectLater(remove(closed), throwsStateError);
      expect((await repository.getForDay(day))!.toJson(), closed.toJson());
    },
  );

  test(
    'owner retirement while real transaction reads prevents the write',
    () async {
      final before = (await repository.getForDay(day))!;
      final paused = _PausedRead(database);
      var current = true;
      final saving = remove(before, through: paused, isCurrent: () => current);
      final rejected = expectLater(saving, throwsStateError);
      await paused.entered.future;
      current = false;
      paused.release.complete();
      await rejected;
      expect((await repository.getForDay(day))!.toJson(), before.toJson());
    },
  );

  test(
    'owner retirement after actual SQL update rolls the transaction back',
    () async {
      final before = (await repository.getForDay(day))!;
      var current = true;
      interceptor.onWrite = () => current = false;
      interceptor.enabled = true;
      await expectLater(
        remove(before, isCurrent: () => current),
        throwsStateError,
      );
      expect(interceptor.triggered, isTrue);
      expect((await repository.getForDay(day))!.toJson(), before.toJson());
    },
  );
}

class _PausedRead extends DailyLogRepository {
  _PausedRead(super.database);
  final entered = Completer<void>();
  final release = Completer<void>();
  bool paused = false;

  @override
  Future<DailyLog?> getForDay(DateTime date) async {
    final record = await super.getForDay(date);
    if (!paused) {
      paused = true;
      entered.complete();
      await release.future;
    }
    return record;
  }
}

class _RetireAfterDailyUpdate extends QueryInterceptor {
  bool enabled = false;
  bool triggered = false;
  void Function()? onWrite;

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runUpdate(statement, args);
    if (enabled && statement.toLowerCase().contains('daily_logs')) {
      triggered = true;
      onWrite?.call();
    }
    return result;
  }
}
