import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dense multi-year history stays unique, ordered, and update-safe',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final weights = WeightRepository(database);
      final days = DailyLogRepository(database);
      final start = DateTime(2021, 1, 1, 8, 15);
      const dayCount = 2192; // Six years, including the 2024 leap day.

      for (var index = 0; index < dayCount; index++) {
        final date = start.add(Duration(days: index));
        await weights.addWeight(90 + (index % 300) / 10, date: date);
        await days.save(
          date: date,
          steps: 3000 + (index % 12000),
          notes: 'dense-$index',
        );
      }

      final lastDay = start.add(const Duration(days: dayCount - 1));
      await weights.addWeight(
        89.2,
        date: DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59),
      );
      await days.save(
        date: DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 58),
        steps: 9999,
        notes: 'same-day-update',
      );

      final allWeights = await weights.getAll();
      final allDays = await days.getAll();
      expect(allWeights, hasLength(dayCount));
      expect(allDays, hasLength(dayCount));
      expect(allWeights.map((row) => row.dayKey).toSet(), hasLength(dayCount));
      expect(allDays.map((row) => row.dayKey).toSet(), hasLength(dayCount));
      expect(allWeights.first.weight, 89.2);
      expect(allWeights.first.dayKey, dayKeyFor(lastDay));

      final updatedDay = await days.getForDay(lastDay);
      expect(updatedDay?.steps, 9999);
      expect(updatedDay?.notes, 'same-day-update');
      expect(await weights.getForDay(DateTime(2024, 2, 29)), isNotNull);
      expect(await days.getForDay(DateTime(2024, 2, 29)), isNotNull);

      for (var index = 1; index < allWeights.length; index++) {
        expect(
          allWeights[index - 1].date.isBefore(allWeights[index].date),
          isFalse,
          reason: 'weight history must remain newest-first at index $index',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
