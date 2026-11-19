import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DailyLogRepository repository;
  late _RetireAfterBodyWrite interceptor;
  final day = DateTime(2026, 11, 17);
  final otherDay = DateTime(2026, 11, 16);

  setUp(() async {
    interceptor = _RetireAfterBodyWrite();
    database = AppDatabase.forTesting(
      NativeDatabase.memory().interceptWith(interceptor),
      localOwnerId: 'body-a',
    );
    repository = DailyLogRepository(database);
    await repository.save(
      date: day,
      notes: 'Original body note',
      sleepHours: 7.25,
      steps: 8123,
      exerciseNotes: 'Saved exercise bytes',
    );
    await repository.save(
      date: otherDay,
      notes: 'Other day note',
      sleepHours: 6.5,
      steps: 4321,
      exerciseNotes: 'Other workout bytes',
    );
  });
  tearDown(() => database.close());

  test(
    'guarded body save changes only notes and preserves neighbouring day',
    () async {
      final before = (await repository.getForDay(day))!;
      final otherBefore = (await repository.getForDay(otherDay))!;
      await repository.saveBodyContext(
        date: day,
        notes: 'Updated body note',
        expectedRecord: before,
        isCurrent: () => true,
      );
      final after = (await repository.getForDay(day))!;
      expect(after.notes, 'Updated body note');
      expect(
        after.toJson()
          ..remove('notes')
          ..remove('updatedAt'),
        before.toJson()
          ..remove('notes')
          ..remove('updatedAt'),
      );
      expect(
        (await repository.getForDay(otherDay))!.toJson(),
        otherBefore.toJson(),
      );
    },
  );

  test('body note participates in an existing local transaction', () async {
    final before = (await repository.getForDay(day))!;
    await database.transaction(() async {
      await repository.saveBodyContext(
        date: day,
        notes: 'Nested body annotation',
        expectedRecord: before,
        isCurrent: () => true,
      );
      expect(
        (await repository.getForDay(day))!.notes,
        'Nested body annotation',
      );
    });
    expect((await repository.getForDay(day))!.notes, 'Nested body annotation');
    expect(
      (await repository.getForDay(day))!.exerciseNotes,
      before.exerciseNotes,
    );
  });

  test('captured source CAS refuses a later body-note update', () async {
    final before = (await repository.getForDay(day))!;
    await repository.saveBodyContext(
      date: day,
      notes: 'Newer stored body note',
    );
    final newer = (await repository.getForDay(day))!;
    await expectLater(
      repository.saveBodyContext(
        date: day,
        notes: 'Stale body note',
        expectedRecord: before,
        isCurrent: () => true,
      ),
      throwsStateError,
    );
    expect((await repository.getForDay(day))!.toJson(), newer.toJson());
  });

  test(
    'captured UUID cannot edit a deleted and recreated daily record',
    () async {
      final before = (await repository.getForDay(day))!;
      await (database.delete(
        database.dailyLogs,
      )..where((row) => row.id.equals(before.id))).go();
      await repository.save(
        date: day,
        notes: before.notes,
        sleepHours: 8,
        steps: 9999,
      );
      final replacement = (await repository.getForDay(day))!;
      expect(replacement.uuid, isNot(before.uuid));
      await expectLater(
        repository.saveBodyContext(
          date: day,
          notes: 'Stale body note',
          expectedRecord: before,
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect((await repository.getForDay(day))!.toJson(), replacement.toJson());
    },
  );

  test(
    'cached absent row cannot replace newly created health fields',
    () async {
      final emptyDay = DateTime(2026, 11, 15);
      expect(await repository.getForDay(emptyDay), isNull);
      await repository.save(
        date: emptyDay,
        notes: 'Concurrent body note',
        sleepHours: 8,
        steps: 6000,
        exerciseNotes: 'Concurrent workout bytes',
      );
      final created = (await repository.getForDay(emptyDay))!;
      await expectLater(
        repository.saveBodyContext(
          date: emptyDay,
          notes: 'Stale first note',
          expectAbsent: true,
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(
        (await repository.getForDay(emptyDay))!.toJson(),
        created.toJson(),
      );
    },
  );

  test('retired visit at transaction entry performs no body write', () async {
    final before = (await repository.getForDay(day))!;
    await expectLater(
      repository.saveBodyContext(
        date: day,
        notes: 'Retired body note',
        expectedRecord: before,
        isCurrent: () => false,
      ),
      throwsStateError,
    );
    expect((await repository.getForDay(day))!.toJson(), before.toJson());
  });

  test(
    'owner retirement while real read waits prevents a body write',
    () async {
      final before = (await repository.getForDay(day))!;
      final paused = _PausedBodyRead(database);
      var current = true;
      final saving = paused.saveBodyContext(
        date: day,
        notes: 'Retired body note',
        expectedRecord: before,
        isCurrent: () => current,
      );
      final rejected = expectLater(saving, throwsStateError);
      await paused.entered.future;
      current = false;
      paused.release.complete();
      await rejected;
      expect((await repository.getForDay(day))!.toJson(), before.toJson());
    },
  );

  test('owner retirement after real SQL update rolls back body note', () async {
    final before = (await repository.getForDay(day))!;
    var current = true;
    interceptor.onWrite = () => current = false;
    interceptor.enabled = true;
    await expectLater(
      repository.saveBodyContext(
        date: day,
        notes: 'Retired SQL body note',
        expectedRecord: before,
        isCurrent: () => current,
      ),
      throwsStateError,
    );
    expect(interceptor.triggered, isTrue);
    expect((await repository.getForDay(day))!.toJson(), before.toJson());
  });

  test(
    'retired first insert rolls back instead of creating a daily record',
    () async {
      final emptyDay = DateTime(2026, 11, 15);
      var current = true;
      interceptor.onWrite = () => current = false;
      interceptor.enabled = true;
      await expectLater(
        repository.saveBodyContext(
          date: emptyDay,
          notes: 'Retired first note',
          expectAbsent: true,
          isCurrent: () => current,
        ),
        throwsStateError,
      );
      expect(interceptor.triggered, isTrue);
      expect(await repository.getForDay(emptyDay), isNull);
      expect((await repository.getForDay(otherDay))!.notes, 'Other day note');
    },
  );

  test(
    'body annotations retain existing completed-day permission and frozen fields',
    () async {
      await repository.closeDay(day);
      final before = (await repository.getForDay(day))!;
      await repository.saveBodyContext(
        date: day,
        notes: 'Completed day body annotation',
        expectedRecord: before,
        isCurrent: () => true,
      );
      final after = (await repository.getForDay(day))!;
      expect(after.notes, 'Completed day body annotation');
      expect(
        after.toJson()
          ..remove('notes')
          ..remove('updatedAt'),
        before.toJson()
          ..remove('notes')
          ..remove('updatedAt'),
      );
      expect(after.lifecycleState, 'closed');
    },
  );
}

class _PausedBodyRead extends DailyLogRepository {
  _PausedBodyRead(super.database);
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<DailyLog?> getForDay(DateTime date) async {
    final row = await super.getForDay(date);
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return row;
  }
}

class _RetireAfterBodyWrite extends QueryInterceptor {
  bool enabled = false;
  bool triggered = false;
  void Function()? onWrite;

  void retire(String statement) {
    if (enabled && statement.toLowerCase().contains('daily_logs')) {
      triggered = true;
      onWrite?.call();
    }
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final count = await executor.runUpdate(statement, args);
    retire(statement);
    return count;
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final id = await executor.runInsert(statement, args);
    retire(statement);
    return id;
  }
}
