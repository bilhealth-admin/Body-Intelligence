import 'dart:async';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrition_goal_snapshot.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrient_daily_references.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'synthetic-owner-a',
    );
    await PreferencesRepository(
      db,
    ).setMany({'goal.calories': '1000', 'goal.proteinGrams': '50'});
  });
  tearDown(() => db.close());

  test(
    'concurrent full-snapshot CAS saves commit one coherent version',
    () async {
      final repo = PreferencesRepository(db);
      final expected = {'goal.calories': '1000', 'goal.proteinGrams': '50'};
      final seen = <Map<String, String>>[];
      final sub = repo.watchSnapshot(expected.keys).listen(seen.add);
      final results = await Future.wait([
        repo.mutateIfUnchanged(
          expected: expected,
          set: {'goal.calories': '2000', 'goal.proteinGrams': '100'},
        ),
        repo.mutateIfUnchanged(
          expected: expected,
          set: {'goal.calories': '1500', 'goal.proteinGrams': '75'},
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(results.where((v) => v), hasLength(1));
      for (final snapshot in seen) {
        expect(
          double.parse(snapshot['goal.proteinGrams']!) * 20,
          double.parse(snapshot['goal.calories']!),
        );
      }
      expect(seen, isNotEmpty);
      await sub.cancel();
    },
  );

  test(
    'owner visit A to B to A retires a pending CAS without losing either owner',
    () async {
      final repo = _PausedRead(db);
      var epoch = 0;
      final captured = epoch;
      final saving = repo.mutateIfUnchanged(
        expected: {'goal.calories': '1000'},
        set: {'goal.calories': '2000'},
        isCurrent: () => epoch == captured,
      );
      final failure = expectLater(saving, throwsStateError);
      await repo.entered.future;
      epoch++;
      epoch++;
      repo.release.complete();
      await failure;
      expect(await PreferencesRepository(db).get('goal.calories'), '1000');
      final other = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'synthetic-owner-b',
      );
      try {
        expect(await PreferencesRepository(other).get('goal.calories'), isNull);
      } finally {
        await other.close();
      }
    },
  );

  test(
    'mid-write storage failure rolls back every macro and original value',
    () async {
      final repo = _FailedWrite(db);
      await expectLater(
        repo.mutateIfUnchanged(
          expected: {'goal.calories': '1000'},
          set: {'goal.calories': '2000', 'goal.proteinGrams': '100'},
        ),
        throwsStateError,
      );
      expect(await PreferencesRepository(db).get('goal.calories'), '1000');
      expect(await PreferencesRepository(db).get('goal.proteinGrams'), '50');
    },
  );

  test(
    'owner retirement after SQL write still rolls back the transaction',
    () async {
      var current = true;
      final repo = _RetiredAfterWrite(db, () => current = false);
      await expectLater(
        repo.mutateIfUnchanged(
          expected: {'goal.calories': '1000'},
          set: {'goal.calories': '2000'},
          isCurrent: () => current,
        ),
        throwsStateError,
      );
      expect(await PreferencesRepository(db).get('goal.calories'), '1000');
    },
  );

  test(
    'old percentage keys survive reopen and review without conversion or overwrite',
    () async {
      final repo = PreferencesRepository(db);
      final originals = {
        for (final key in NutritionGoalSnapshot.legacyKeys.values) key: '10',
      };
      await repo.setMany(originals);
      for (var visit = 0; visit < 3; visit++) {
        final raw = await repo
            .watchSnapshot(NutritionGoalSnapshot.storageKeys)
            .first;
        final goals = NutritionGoalSnapshot.resolve(
          raw,
          NutrientDailyReferences.values,
        );
        for (final key in NutritionGoalSnapshot.legacyKeys.keys) {
          expect(goals.goals[key]!.status, NutritionGoalStatus.legacyUnknown);
          expect(goals.goals[key]!.legacyRaw, '10');
          expect(await repo.get(key), isNull);
          expect(await repo.get(NutritionGoalSnapshot.legacyKeys[key]!), '10');
        }
      }
    },
  );
}

class _PausedRead extends PreferencesRepository {
  _PausedRead(super.database);
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<String?> get(String key) async {
    final value = await super.get(key);
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return value;
  }
}

class _FailedWrite extends PreferencesRepository {
  _FailedWrite(super.database);
  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    await super.setManyInCurrentTransaction({
      values.keys.first: values.values.first,
    });
    throw StateError('synthetic disk failure after SQL write');
  }
}

class _RetiredAfterWrite extends PreferencesRepository {
  _RetiredAfterWrite(super.database, this.retire);
  final void Function() retire;
  @override
  Future<void> setManyInCurrentTransaction(Map<String, String> values) async {
    await super.setManyInCurrentTransaction(values);
    retire();
  }
}
