import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/daily_log/water_mutation_coordinator.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ControlledWaterRepository extends WaterRepository {
  _ControlledWaterRepository(super.database);

  Completer<void>? pendingDelete;
  int deleteCalls = 0;

  @override
  Future<void> delete(int id) async {
    deleteCalls += 1;
    final pending = Completer<void>();
    pendingDelete = pending;
    await pending.future;
  }
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('pending mutation is single-flight and unlocks after failure', () async {
    final repository = _ControlledWaterRepository(database);
    final busyStates = <bool>[];
    final coordinator = WaterMutationCoordinator(onBusyChanged: busyStates.add);

    final first = coordinator.delete(repository: repository, id: 1);
    expect(coordinator.busy, isTrue);
    final duplicate = await coordinator.delete(repository: repository, id: 1);
    expect(duplicate, WaterMutationOutcome.alreadyBusy);
    expect(repository.deleteCalls, 1);

    repository.pendingDelete!.completeError(StateError('write failed'));
    expect(await first, WaterMutationOutcome.failure);
    expect(coordinator.busy, isFalse);
    expect(busyStates, [true, false]);
  });

  test(
    'successful delete persists when the repository is reconstructed',
    () async {
      final repository = WaterRepository(database);
      final date = DateTime(2026, 8, 14, 10);
      final id = await repository.add(occurredAt: date, amountMl: 350);
      final coordinator = WaterMutationCoordinator(onBusyChanged: (_) {});

      expect(
        await coordinator.delete(repository: repository, id: id),
        WaterMutationOutcome.success,
      );
      final reloaded = WaterRepository(database);
      expect(await reloaded.totalForDay(date), 0);
      expect(await reloaded.watchForDay(date).first, isEmpty);
    },
  );
}
