import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
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

    test('first authenticated account safely adopts guest health data', () async {
      await WeightRepository(database).addWeight(80);

      final result = await boundary.bindAuthenticatedOwner('owner-a');

      expect(
        result.disposition,
        LocalDataAccountBindingDisposition.adoptedGuestData,
      );
      expect(result.hasSubstantiveLocalData, isTrue);
      expect(result.requiresAccountResolution, isFalse);
      expect(await boundary.readBoundOwnerId(), 'owner-a');
    });

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

    test('different account is blocked when owned health data exists', () async {
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
    });

    test('empty local store may be rebound without destructive cleanup', () async {
      await boundary.bindAuthenticatedOwner('owner-a');

      final result = await boundary.bindAuthenticatedOwner('owner-b');

      expect(
        result.disposition,
        LocalDataAccountBindingDisposition.reboundEmptyStore,
      );
      expect(result.hasSubstantiveLocalData, isFalse);
      expect(result.requiresAccountResolution, isFalse);
      expect(await boundary.readBoundOwnerId(), 'owner-b');
    });
  });
}
