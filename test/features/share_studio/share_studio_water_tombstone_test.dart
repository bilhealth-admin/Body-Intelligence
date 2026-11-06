import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/share_studio/share_studio_page.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Share Studio excludes an actual soft-deleted 2000mL water entry',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      try {
        await database
            .customSelect('SELECT 1')
            .getSingle()
            .timeout(const Duration(seconds: 5));
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 12);
        final repository = WaterRepository(database);
        final id = await repository.add(occurredAt: today, amountMl: 2000);
        await repository.delete(id);
        final stored =
            (await database.select(database.waterEntries).get()).single;
        expect(stored.deletedAt, isNotNull);
        expect(stored.amountMl, 2000);
        expect(stored.syncStatus, 'pendingDelete');
        expect(await repository.totalForDay(today), 0);

        final summary = await container
            .read(shareStudioDataProvider.future)
            .timeout(const Duration(seconds: 5));
        expect(summary.metrics.observedDays, 7);
        expect(summary.metrics.hydrationDays, 0);
        expect(summary.metrics.consistentDays, 0);
        expect(summary.metrics.proteinDays, 0);
        expect(summary.metrics.score, 0);
      } finally {
        container.dispose();
        // The provider's first-only Drift watch cancellation schedules Timer.run.
        await Future<void>.delayed(Duration.zero);
        await database.close().timeout(const Duration(seconds: 5));
      }
    },
  );

  test(
    'Share Studio credits active in-week water and ignores old or deleted water',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      try {
        await database
            .customSelect('SELECT 1')
            .getSingle()
            .timeout(const Duration(seconds: 5));
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 12);
        final repository = WaterRepository(database);
        await repository.add(
          occurredAt: today.subtract(const Duration(days: 6)),
          amountMl: 2000,
        );
        await repository.add(
          occurredAt: today.subtract(const Duration(days: 8)),
          amountMl: 2000,
        );
        final deleted = await repository.add(occurredAt: today, amountMl: 2000);
        await repository.delete(deleted);

        final summary = await container
            .read(shareStudioDataProvider.future)
            .timeout(const Duration(seconds: 5));
        expect(summary.metrics.hydrationDays, 1);
        expect(summary.metrics.score, 5);
        expect(
          await database.select(database.waterEntries).get(),
          hasLength(3),
        );
      } finally {
        container.dispose();
        await Future<void>.delayed(Duration.zero);
        await database.close().timeout(const Duration(seconds: 5));
      }
    },
  );
}
