import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:drift/drift.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('local data account boundary', () {
    late AppDatabase database;
    late LocalDataAccountBoundary boundary;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      boundary = LocalDataAccountBoundary(database);
    });

    tearDown(() => database.close());

    test(
      'first authenticated account safely adopts guest health data',
      () async {
        await WeightRepository(database).addWeight(80);

        final result = await boundary.bindAuthenticatedOwner('owner-a');

        expect(
          result.disposition,
          LocalDataAccountBindingDisposition.adoptedGuestData,
        );
        expect(result.hasSubstantiveLocalData, isTrue);
        expect(result.requiresAccountResolution, isFalse);
        expect(await boundary.readBoundOwnerId(), 'owner-a');
      },
    );

    test('same account may reopen its existing local data', () async {
      await WeightRepository(database).addWeight(80);
      await boundary.bindAuthenticatedOwner('owner-a');

      final result = await boundary.bindAuthenticatedOwner('owner-a');

      expect(
        result.disposition,
        LocalDataAccountBindingDisposition.matchedExistingOwner,
      );
      expect(result.requiresAccountResolution, isFalse);
      expect(await boundary.readBoundOwnerId(), 'owner-a');
    });

    test(
      'different account is blocked when owned health data exists',
      () async {
        await WeightRepository(database).addWeight(80);
        await boundary.bindAuthenticatedOwner('owner-a');

        final result = await boundary.bindAuthenticatedOwner('owner-b');

        expect(
          result.disposition,
          LocalDataAccountBindingDisposition.ownerConflict,
        );
        expect(result.hasSubstantiveLocalData, isTrue);
        expect(result.requiresAccountResolution, isTrue);
        expect(await boundary.readBoundOwnerId(), 'owner-a');
        expect((await WeightRepository(database).getAll()).single.weight, 80);
      },
    );

    test(
      'empty local store may be rebound without destructive cleanup',
      () async {
        await boundary.bindAuthenticatedOwner('owner-a');

        final result = await boundary.bindAuthenticatedOwner('owner-b');

        expect(
          result.disposition,
          LocalDataAccountBindingDisposition.reboundEmptyStore,
        );
        expect(result.hasSubstantiveLocalData, isFalse);
        expect(result.requiresAccountResolution, isFalse);
        expect(await boundary.readBoundOwnerId(), 'owner-b');
      },
    );

    for (final key in [
      'goal.fiber',
      'goals.nutritionSchedule.v1',
      'nutrition.trustedRecipes.v1',
    ]) {
      test(
        'nutrition preference alone prevents another owner adopting $key',
        () async {
          await boundary.bindAuthenticatedOwner('owner-a');
          await PreferencesRepository(
            database,
          ).set(key, 'synthetic preserved value');
          final result = await boundary.bindAuthenticatedOwner('owner-b');
          expect(result.requiresAccountResolution, isTrue);
          expect(await boundary.readBoundOwnerId(), 'owner-a');
          expect(
            await PreferencesRepository(database).get(key),
            'synthetic preserved value',
          );
        },
      );
    }

    test(
      'custom food alone prevents rebound including a soft deleted food',
      () async {
        await boundary.bindAuthenticatedOwner('owner-a');
        await database
            .into(database.foods)
            .insert(
              FoodsCompanion.insert(
                name: 'TEST owner food',
                calories: 10,
                protein: 1,
                carbs: 1,
                fats: 0,
                isCustom: const Value(true),
                deletedAt: Value(DateTime.utc(2026, 10, 12)),
              ),
            );
        final result = await boundary.bindAuthenticatedOwner('owner-b');
        expect(result.requiresAccountResolution, isTrue);
        expect(await boundary.readBoundOwnerId(), 'owner-a');
      },
    );
  });
}
