import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/daily_check_in/check_in_mutation_coordinator.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => database.close());

  test('all check-in writes share one pending mutation gate', () async {
    final states = <CheckInMutationKind?>[];
    final coordinator = CheckInMutationCoordinator(onStateChanged: states.add);
    final pending = Completer<void>();
    var calls = 0;
    final save = coordinator.run(CheckInMutationKind.save, () {
      calls += 1;
      return pending.future;
    });
    expect(coordinator.active, CheckInMutationKind.save);
    expect(
      await coordinator.run(CheckInMutationKind.delete, () async {
        calls += 1;
      }),
      CheckInMutationOutcome.alreadyBusy,
    );
    expect(calls, 1);
    pending.completeError(StateError('write failed'));
    expect(await save, CheckInMutationOutcome.failure);
    expect(coordinator.busy, isFalse);
    expect(states, [CheckInMutationKind.save, null]);
  });

  test(
    'save, skip, and delete persist through reconstructed repositories',
    () async {
      final weights = WeightRepository(database);
      final preferences = PreferencesRepository(database);
      final date = DateTime(2026, 8, 14, 8);
      final coordinator = CheckInMutationCoordinator(onStateChanged: (_) {});

      expect(
        await coordinator.run(CheckInMutationKind.save, () async {
          await weights.addWeight(
            82.4,
            date: date,
            measurementContext: 'unspecified',
          );
        }),
        CheckInMutationOutcome.success,
      );
      final saved = await WeightRepository(database).getForDay(date);
      expect(saved?.weight, 82.4);
      expect(saved?.measurementContext, 'unspecified');

      expect(
        await coordinator.run(CheckInMutationKind.skip, () async {
          await preferences.set('weightReminderSkippedDay', dayKeyFor(date));
        }),
        CheckInMutationOutcome.success,
      );
      expect(
        await PreferencesRepository(database).get('weightReminderSkippedDay'),
        dayKeyFor(date),
      );

      expect(
        await coordinator.run(CheckInMutationKind.delete, () async {
          await weights.deleteWeight(saved!.id);
        }),
        CheckInMutationOutcome.success,
      );
      expect(await WeightRepository(database).getForDay(date), isNull);
    },
  );
}
