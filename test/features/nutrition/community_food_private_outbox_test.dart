import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/community_catalog/data/community_food_outbox_store.dart';
import 'package:body_intelligence_log/features/nutrition/community_catalog/data/supabase_community_food_catalog.dart';
import 'package:body_intelligence_log/features/nutrition/community_catalog/services/community_food_sync_service.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const foodUuid = '11111111-1111-4111-8111-111111111111';
const legacyPayload = <String, dynamic>{
  'client_food_id': foodUuid,
  'canonical_name': 'Private family food',
  'calories_kcal': 321,
};

Future<void> seedLegacy(AppDatabase database) => database.customStatement(
  '''INSERT INTO community_food_outbox
     (local_food_uuid, operation, payload_json, attempt_count,
      next_attempt_at, last_error, updated_at)
     VALUES (?, 'upsert', ?, 2, NULL, 'offline', 17)''',
  [foodUuid, jsonEncode(legacyPayload)],
);

void main() {
  test(
    'legacy private upserts are excluded from due and retained locally',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await seedLegacy(database);
      final outbox = CommunityFoodOutboxStore(database);

      expect(
        await outbox.due(),
        isEmpty,
        reason: 'No explicit Community submission exists for a legacy row.',
      );
      expect(await outbox.pendingCount(), 1);
      final row = await database
          .customSelect('SELECT * FROM community_food_outbox')
          .getSingle();
      expect(jsonDecode(row.read<String>('payload_json')), legacyPayload);
      expect(row.read<int>('attempt_count'), 2);
      expect(row.read<int>('updated_at'), 17);
      expect(
        row.read<String>('last_error'),
        'explicit_community_submission_required_v1',
      );
    },
  );

  test(
    'restart and repeated search flush never send private legacy food',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bil-private-food-',
      );
      final file = File('${directory.path}/owner-a.sqlite');
      var database = AppDatabase.forTesting(
        NativeDatabase(file),
        localOwnerId: 'test-owner-a',
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });
      final repository = FoodRepository(database);
      await repository.addFood(
        name: 'Private diary food',
        category: 'custom',
        servingSize: 100,
        servingUnit: 'g',
        calories: 120,
        protein: 10,
        carbs: 15,
        fats: 2,
      );
      await seedLegacy(database);
      await database.close();

      database = AppDatabase.forTesting(
        NativeDatabase(file),
        localOwnerId: 'test-owner-a',
      );
      final cloud = RecordingCloud();
      final outbox = CommunityFoodOutboxStore(database);
      final sync = CommunityFoodSyncService(outbox, cloud);
      // This is the same flush used when signed-in Community search is read.
      await sync.flush();
      await sync.flush();
      expect(cloud.upserts, isEmpty);
      expect(cloud.withdrawals, isEmpty);
      expect(await outbox.pendingCount(), 1);
      expect(
        (await FoodRepository(database).getFoods()).single.name,
        'Private diary food',
      );
      await database.close();

      database = AppDatabase.forTesting(
        NativeDatabase(file),
        localOwnerId: 'test-owner-a',
      );
      final restarted = CommunityFoodSyncService(
        CommunityFoodOutboxStore(database),
        cloud,
      );
      // A new service/policy session is not a food-specific choice either.
      await restarted.flush();
      expect(cloud.upserts, isEmpty);
      expect(await CommunityFoodOutboxStore(database).pendingCount(), 1);
    },
  );

  test(
    'explicit deletion replaces a blocked upsert and retries withdrawal once',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await seedLegacy(database);
      final outbox = CommunityFoodOutboxStore(database);
      final cloud = RecordingCloud()..offline = true;
      final sync = CommunityFoodSyncService(outbox, cloud);
      await sync.withdrawFood(foodUuid);
      await sync.flush();
      expect(cloud.upserts, isEmpty);
      expect(await outbox.pendingCount(), 1);
      final row = await database
          .customSelect(
            'SELECT operation, attempt_count FROM community_food_outbox',
          )
          .getSingle();
      expect(row.read<String>('operation'), 'delete');
      expect(row.read<int>('attempt_count'), 1);
      cloud.offline = false;
      await database.customStatement(
        'UPDATE community_food_outbox SET next_attempt_at = 0',
      );
      await sync.flush();
      await sync.flush();
      expect(cloud.withdrawals, [foodUuid]);
      expect(cloud.withdrawalAttempts, 2);
      expect(await outbox.pendingCount(), 0);
    },
  );

  test(
    'quarantine is idempotent across reopen and does not remove any data',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await seedLegacy(database);
      final outbox = CommunityFoodOutboxStore(database);
      await outbox.quarantineLegacyUpserts();
      final first =
          (await database
                  .customSelect('SELECT * FROM community_food_outbox')
                  .getSingle())
              .data;
      await CommunityFoodOutboxStore(database).quarantineLegacyUpserts();
      final second =
          (await database
                  .customSelect('SELECT * FROM community_food_outbox')
                  .getSingle())
              .data;
      expect(second, first);
      expect(await outbox.due(), isEmpty);
      expect(second['payload_json'], jsonEncode(legacyPayload));
      expect(second['next_attempt_at'], 9223372036854775807);
    },
  );

  test('failed quarantine still cannot admit legacy publication', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await seedLegacy(database);
    final outbox = FailingQuarantineStore(database);
    final cloud = RecordingCloud();
    final sync = CommunityFoodSyncService(outbox, cloud);
    expect(await outbox.due(), isEmpty);
    await sync.flush();
    expect(cloud.upserts, isEmpty);
    expect(await outbox.pendingCount(), 1);
  });

  test(
    'flush independently rejects an unexpected upsert returned by a store',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await seedLegacy(database);
      final cloud = RecordingCloud();
      final sync = CommunityFoodSyncService(
        UnexpectedUpsertStore(database),
        cloud,
      );
      await sync.flush();
      expect(cloud.upserts, isEmpty);
      expect(await CommunityFoodOutboxStore(database).pendingCount(), 1);
    },
  );

  test(
    'owner change while due rows load prevents withdrawal under another session',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'test-owner-a',
      );
      addTearDown(database.close);
      final store = DelayedStore(database);
      await store.enqueueDelete(foodUuid);
      var ownerIsCurrent = true;
      final cloud = RecordingCloud();
      final sync = CommunityFoodSyncService(
        store,
        cloud,
        isCurrent: () => ownerIsCurrent,
      );
      final loading = sync.flush();
      await store.started.future;
      ownerIsCurrent = false;
      store.continueRead.complete();
      await loading;
      expect(cloud.withdrawalAttempts, 0);
      expect(await store.pendingCount(), 1);
      await sync.withdrawFood('22222222-2222-4222-8222-222222222222');
      expect(await store.pendingCount(), 1);
      // Returning to the original owner permits its existing authorized removal.
      ownerIsCurrent = true;
      await sync.flush();
      expect(cloud.withdrawals, [foodUuid]);
      expect(await store.pendingCount(), 0);
    },
  );

  test('retired owner database errors do not escape a pending flush', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'test-owner-a',
    );
    addTearDown(database.close);
    final store = DelayedStore(database)..failRead = true;
    var ownerIsCurrent = true;
    final cloud = RecordingCloud();
    final sync = CommunityFoodSyncService(
      store,
      cloud,
      isCurrent: () => ownerIsCurrent,
    );
    final loading = sync.flush();
    await store.started.future;
    final completed = expectLater(loading, completes);
    ownerIsCurrent = false;
    store.continueRead.complete();
    await completed;
    expect(cloud.withdrawalAttempts, 0);
    expect(cloud.upserts, isEmpty);
  });

  test('database errors for the active owner remain observable', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DelayedStore(database)..failRead = true;
    store.continueRead.complete();
    final sync = CommunityFoodSyncService(store, RecordingCloud());
    await expectLater(sync.flush(), throwsStateError);
  });
}

class FailingQuarantineStore extends CommunityFoodOutboxStore {
  FailingQuarantineStore(super.database);
  @override
  Future<void> quarantineLegacyUpserts() async =>
      throw StateError('local migration unavailable');
}

class UnexpectedUpsertStore extends CommunityFoodOutboxStore {
  UnexpectedUpsertStore(super.database);
  @override
  Future<List<CommunityFoodOutboxEntry>> due({int limit = 20}) async => [
    const CommunityFoodOutboxEntry(
      localFoodUuid: foodUuid,
      operation: 'upsert',
      payload: legacyPayload,
      attemptCount: 2,
    ),
  ];
}

class DelayedStore extends CommunityFoodOutboxStore {
  DelayedStore(super.database);
  final started = Completer<void>();
  final continueRead = Completer<void>();
  bool failRead = false;
  @override
  Future<List<CommunityFoodOutboxEntry>> due({int limit = 20}) async {
    if (!started.isCompleted) started.complete();
    await continueRead.future;
    if (failRead) throw StateError('retired database connection closed');
    return super.due(limit: limit);
  }
}

class RecordingCloud implements CommunityFoodCloudGateway {
  final upserts = <Map<String, dynamic>>[];
  final withdrawals = <String>[];
  int withdrawalAttempts = 0;
  bool offline = false;

  @override
  Future<void> upsert(Map<String, dynamic> payload) async =>
      upserts.add(payload);
  @override
  Future<void> withdraw(String localFoodUuid) async {
    withdrawalAttempts++;
    if (offline) throw StateError('offline');
    withdrawals.add(localFoodUuid);
  }

  @override
  Future<List<UnifiedFood>> search(String query, {int limit = 10}) async => [];
}
