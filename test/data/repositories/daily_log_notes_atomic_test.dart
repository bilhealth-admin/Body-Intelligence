import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';

void main() {
  late AppDatabase db;
  late DailyLogRepository logs;
  final day = DateTime(2026, 10, 11);
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logs = DailyLogRepository(db);
  });
  tearDown(() => db.close());
  test(
    'Today notes preserve sleep, steps and structured workout content',
    () async {
      await logs.save(
        date: day,
        notes: 'old',
        steps: 3000,
        sleepHours: 7,
        exerciseNotes: 'workout',
      );
      await logs.saveNotesAtomically(
        date: day,
        expectedNotes: 'old',
        expectedExerciseNotes: 'workout',
        notes: 'new',
        exerciseNotes: 'workout',
      );
      final row = await logs.getForDay(day);
      expect(row!.notes, 'new');
      expect(row.steps, 3000);
      expect(row.sleepHours, 7);
      expect(row.exerciseNotes, 'workout');
    },
  );
  test('compare-and-set refuses a concurrent notes overwrite', () async {
    await logs.save(date: day, notes: 'changed');
    await expectLater(
      logs.saveNotesAtomically(
        date: day,
        expectedNotes: 'old',
        expectedExerciseNotes: null,
        notes: 'replacement',
        exerciseNotes: null,
      ),
      throwsStateError,
    );
    expect((await logs.getForDay(day))!.notes, 'changed');
  });
  test(
    'closed diary refuses notes mutation and preserves its snapshot',
    () async {
      await logs.save(date: day, notes: 'closed');
      await logs.closeDay(day);
      await expectLater(
        logs.saveNotesAtomically(
          date: day,
          expectedNotes: 'closed',
          expectedExerciseNotes: null,
          notes: 'replacement',
          exerciseNotes: null,
        ),
        throwsStateError,
      );
      expect((await logs.getForDay(day))!.notes, 'closed');
      expect((await logs.readLedger(day)).state, DayLifecycleState.closed);
    },
  );
}
