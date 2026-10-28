import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_restore_providers.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_consent_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_restore_conflict_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:body_intelligence_log/app/services/local_data_lifecycle_service.dart';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_platform_ports.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_v2_engine.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_v2_transport.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_conflict_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/presentation/cloud_restore_conflict_controls.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/cloud_nutrition_fixture.dart';

/// Deterministic model tests complement the separate REAL PostgreSQL/AES cycle.
/// This transport is intentionally not evidence of SQL, RLS or native crypto.
void main() {
  late _ModelServer server;
  late AppDatabase a, b;
  late PreferencesRepository pa, pb;
  late CloudRestoreV2Engine ea, eb;
  var active = true;
  setUp(() async {
    server = _ModelServer();
    a = AppDatabase.forTesting(NativeDatabase.memory(), localOwnerId: 'owner');
    b = AppDatabase.forTesting(NativeDatabase.memory(), localOwnerId: 'owner');
    await LocalDataAccountBoundary(a).bindAuthenticatedOwner('owner');
    await LocalDataAccountBoundary(b).bindAuthenticatedOwner('owner');
    pa = PreferencesRepository(a);
    pb = PreferencesRepository(b);
    active = true;
    ea = _engine(a, server, 'device-a');
    eb = _engine(b, server, 'device-b', current: () => active);
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  for (final size in [10, 100]) {
    test(
      'actual SQLite restore scans grow linearly for $size meal aggregates',
      () async {
        final counter = _RestoreAggregateCounter();
        final destination = AppDatabase.forTesting(
          NativeDatabase.memory().interceptWith(counter),
          localOwnerId: 'owner',
        );
        addTearDown(destination.close);
        await LocalDataAccountBoundary(
          destination,
        ).bindAuthenticatedOwner('owner');
        final food = await FoodRepository(a).addFood(
          name: 'Synthetic linear-scan fixture',
          category: 'test',
          calories: 100,
          protein: 10,
          carbs: 10,
          fats: 2,
          isCustom: true,
          source: 'TEST scan bound',
          servingSize: 100,
          servingUnit: 'g',
        );
        final repository = MealRepository(a);
        for (var i = 0; i < size; i++) {
          final meal = await repository.createMeal(
            date: DateTime.utc(2026, 10, 13).add(Duration(days: i)),
            name: 'Synthetic lunch $i',
            type: 'lunch',
          );
          await repository.addMealItem(
            mealId: meal,
            foodId: food,
            quantity: 50,
          );
        }
        CloudRestoreV2Engine engine(AppDatabase db, String device) =>
            CloudRestoreV2Engine(
              database: db,
              ownerId: 'owner',
              deviceId: device,
              keyId: 'test-key',
              cipher: const _TransparentTestCipher(),
              transport: server,
              ownerIsCurrent: () => true,
              pageSize: 100,
            );
        expect(
          (await engine(a, 'source-performance').run({'nutrition'})).completed,
          isTrue,
        );
        counter.rows = 0;
        counter.selects = 0;
        final clock = Stopwatch()..start();
        final restored = await engine(
          destination,
          'target-performance',
        ).run({'nutrition'});
        clock.stop();
        expect(restored.completed, isTrue);
        final materialized = counter.rows;
        final selects = counter.selects;
        expect(
          await destination.select(destination.meals).get(),
          hasLength(size),
        );
        expect(
          await destination.select(destination.mealItems).get(),
          hasLength(size),
        );
        stdout.writeln(
          'SQLite performance fixture: meals=$size materialized_aggregate_rows=$materialized aggregate_selects=$selects milliseconds=${clock.elapsedMilliseconds}',
        );
        expect(
          materialized,
          lessThanOrEqualTo(size * 12 + 50),
          reason:
              'Verification of one remote aggregate must not repeatedly materialize the whole diary. This row-count bound is independent of machine speed.',
        );
      },
    );
  }

  test(
    'independent SQLite goals restore preserves raw old percentages and zero',
    () async {
      await pa.setMany({
        'goal.calories': '1000',
        'goal.carbsPercent': '45',
        'goal.proteinPercent': '20',
        'goal.fatPercent': '35',
        'goal.carbsGrams': '112.5',
        'goal.fatGrams': '38.888888888888886',
        'goal.fiber': '0',
        'goal.vitaminA': '10',
        'goal.lock.protein': 'true',
        'goal.lockMode.protein': 'grams',
        'goal.macroLastEdited': 'protein',
        'goal.origin.goal.calories': 'manual',
      });
      expect((await ea.run({'goals'})).completed, isTrue);
      expect(await pb.get('goal.calories'), isNull);
      expect((await eb.run({'goals'})).completed, isTrue);
      for (final key in [
        'goal.calories',
        'goal.fatGrams',
        'goal.fiber',
        'goal.vitaminA',
        'goal.lock.protein',
        'goal.lockMode.protein',
        'goal.macroLastEdited',
      ]) {
        expect(await pb.get(key), await pa.get(key));
      }
      expect(await pb.get('goal.vitaminAMcg'), isNull);
      expect((await eb.run({'goals'})).pushed, 0);
    },
  );

  test(
    'paginated tombstone before stale meal survives interruption and restart',
    () async {
      final fixture = await seedCloudNutritionFixture(a, ownerId: 'owner');
      expect((await ea.run({'nutrition'})).completed, isTrue);
      final beforeItems = await a.select(a.mealItems).get();
      final oldAggregates = {
        for (final entry in server.records.entries)
          if (entry.value['record_type'] == 'meal' ||
              entry.value['record_type'] == 'recipe')
            entry.key: Map<String, Object?>.of(entry.value),
      };
      final food = (await a.select(a.foods).get()).singleWhere(
        (row) => row.uuid == fixture.foodUuid,
      );
      await FoodRepository(a).deleteCustomFood(food.id);
      expect((await ea.run({'nutrition'})).completed, isTrue);
      // A still-valid meal revision can carry a historical food definition.
      // Its independent food tombstone arrives on the preceding server page.
      for (final entry in oldAggregates.entries) {
        server.records[entry.key] = entry.value;
      }
      final tombstoneKey = 'nutrition:food:${fixture.foodUuid}';
      expect(server.records[tombstoneKey]!['deleted'], true);
      var sequence = 1;
      server.records[tombstoneKey]!['change_sequence'] = sequence++;
      for (final entry in server.records.entries) {
        if (entry.key != tombstoneKey) {
          entry.value['change_sequence'] = sequence++;
        }
      }
      server.sequence = sequence;
      server.failAtCall = server.calls + 2;
      expect((await eb.run({'nutrition'})).completed, isFalse);
      expect(await b.select(b.foods).get(), isEmpty);
      expect(
        (await eb.codec.capture(scopes: {'nutrition'})).single.deleted,
        true,
      );
      expect(
        (await eb.journal.entries('nutrition')).single.baseline,
        isNotNull,
      );
      server.failAtCall = null;
      final restart = _engine(b, server, 'device-b');
      final restored = await restart.run({'nutrition'});
      expect(restored.completed, isTrue, reason: restored.reason);
      expect(
        restored.pushed,
        0,
        reason: 'A dependency cannot become a new local catalog edit',
      );
      expect(await FoodRepository(b).findById(fixture.foodUuid), isNull);
      final restoredFood = (await b.select(b.foods).get()).singleWhere(
        (row) => row.uuid == fixture.foodUuid,
      );
      expect(restoredFood.deletedAt, isNotNull);
      final afterItems = await b.select(b.mealItems).get();
      expect(afterItems, hasLength(beforeItems.length));
      for (final before in beforeItems) {
        final after = afterItems.singleWhere((row) => row.uuid == before.uuid);
        expect(after.foodEvidenceJson, before.foodEvidenceJson);
        expect(after.quantity, before.quantity);
        expect(after.servingSizeSnapshot, before.servingSizeSnapshot);
        expect(after.servingUnitSnapshot, before.servingUnitSnapshot);
        for (final nutrient in FoodNutrient.values) {
          expect(
            MealFoodEvidence.read(after).fullValue(nutrient),
            MealFoodEvidence.read(before).fullValue(nutrient),
            reason: nutrient.name,
          );
        }
      }
      expect(await b.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect((await restart.run({'nutrition'})).pushed, 0);
      expect(await restart.conflicts({'nutrition'}), isEmpty);
    },
  );

  test('no new consent means no capture, encryption or transport', () async {
    await pa.set('goal.calories', '1000');
    expect((await ea.run({})).completed, isTrue);
    expect(server.calls, 0);
    server.granted = false;
    expect((await ea.run({'goals'})).reason, 'consent_missing');
    expect(server.records, isEmpty);
  });

  test('missing V2 capability does not upload using V1', () async {
    await pa.set('goal.calories', '1000');
    server.version = 1;
    expect((await ea.run({'goals'})).reason, 'server_unsupported');
    expect(server.calls, 0);
    expect(await pa.get('goal.calories'), '1000');
  });

  test(
    'two devices competing keep whole local goal set until explicit choice',
    () async {
      await pa.setMany({'goal.calories': '1000', 'goal.proteinGrams': '50'});
      await ea.run({'goals'});
      await eb.run({'goals'});
      await pa.setMany({'goal.calories': '2000', 'goal.proteinGrams': '100'});
      await pb.setMany({'goal.calories': '1500', 'goal.proteinGrams': '75'});
      expect((await ea.run({'goals'})).completed, isTrue);
      final conflict = await eb.run({'goals'});
      expect(conflict.conflicts, 1);
      expect(conflict.completed, isFalse);
      expect(await pb.get('goal.calories'), '1500');
      expect(await pb.get('goal.proteinGrams'), '75');
      final row = (await eb.conflicts({'goals'})).single;
      await eb.resolveConflict(row.key, keepLocal: true);
      expect((await eb.run({'goals'})).completed, isTrue);
      expect((await ea.run({'goals'})).completed, isTrue);
      expect(await pa.get('goal.calories'), '1500');
      expect(await pa.get('goal.proteinGrams'), '75');
      expect((await eb.journal.entry(row.key))!.recovery, isNotNull);
    },
  );

  test(
    'accepting cloud conflict saves local preimage then atomically replaces goal set',
    () async {
      await pa.set('goal.calories', '1000');
      await ea.run({'goals'});
      await pb.setMany({'goal.calories': '2000', 'goal.lock.protein': 'true'});
      await eb.run({'goals'});
      final row = (await eb.conflicts({'goals'})).single;
      await eb.resolveConflict(row.key, keepLocal: false);
      expect(await pb.get('goal.calories'), '1000');
      expect(await pb.get('goal.lock.protein'), isNull);
      expect((await eb.journal.entry(row.key))!.recovery!['local'], isNotEmpty);
    },
  );

  test(
    'lost accepted response retries same operation and ciphertext after restart',
    () async {
      await pa.set('goal.calories', '1000');
      server.loseResponse = true;
      expect((await ea.run({'goals'})).completed, isFalse);
      final pending = (await ea.journal.entries('goals')).single.pending;
      final restart = _engine(a, server, 'device-a');
      expect((await restart.run({'goals'})).completed, isTrue);
      expect(server.accepted, 1);
      expect(server.seen.last, pending);
    },
  );

  test(
    'edit during download is retained and reported as pending conflict',
    () async {
      await pa.set('goal.calories', '1000');
      await ea.run({'goals'});
      server.beforeReturn = () async {
        await pb.set('goal.calories', '2400');
      };
      final result = await eb.run({'goals'});
      expect(result.completed, isFalse);
      expect(result.conflicts, 1);
      expect(await pb.get('goal.calories'), '2400');
    },
  );

  test(
    'A B A epoch invalidation while downloading never installs earlier session',
    () async {
      await pa.set('goal.calories', '1000');
      await ea.run({'goals'});
      server.beforeReturn = () async {
        active = false;
      };
      expect((await eb.run({'goals'})).reason, 'context_changed');
      expect(await pb.get('goal.calories'), isNull);
      expect(await eb.journal.cursor('goals'), 0);
    },
  );

  test(
    'revocation between response and application does not install data',
    () async {
      await pa.set('goal.calories', '1000');
      await ea.run({'goals'});
      server.beforeReturn = () async {
        server.granted = false;
      };
      expect((await eb.run({'goals'})).reason, 'consent_missing');
      expect(await pb.get('goal.calories'), isNull);
      expect(await eb.journal.cursor('goals'), 0);
    },
  );

  for (final fault in ['owner', 'version', 'key', 'cipher']) {
    test(
      '$fault mismatch blocks restore without cursor or local wipe',
      () async {
        await pa.set('goal.calories', '1000');
        await ea.run({'goals'});
        final row = server.records.values.single;
        switch (fault) {
          case 'owner':
            row['owner_id'] = 'other';
          case 'version':
            row['payload_version'] = 9;
          case 'key':
            (row['payload'] as Map)['key_id'] = 'rotated-key-unavailable';
          case 'cipher':
            (row['payload'] as Map)['clear'] = 'corrupt';
        }
        final result = await eb.run({'goals'});
        expect(result.completed, isFalse);
        expect(await pb.get('goal.calories'), isNull);
        expect(await eb.journal.cursor('goals'), 0);
      },
    );
  }

  test(
    'reset to automatic is an empty goal snapshot, permits later customization',
    () async {
      await pa.set('goal.calories', '1000');
      await ea.run({'goals'});
      await eb.run({'goals'});
      await pa.remove('goal.calories');
      expect((await ea.run({'goals'})).completed, isTrue);
      expect((await eb.run({'goals'})).completed, isTrue);
      expect(await pb.get('goal.calories'), isNull);
      await pb.set('goal.calories', '1800');
      expect((await eb.run({'goals'})).completed, isTrue);
      expect((await ea.run({'goals'})).completed, isTrue);
      expect(await pa.get('goal.calories'), '1800');
    },
  );

  test(
    'local scope withdrawal cannot be overridden by a retained server grant',
    () async {
      final restricted = CloudRestoreV2Engine(
        database: a,
        ownerId: 'owner',
        deviceId: 'device-a',
        keyId: 'test-key',
        cipher: const _TransparentTestCipher(),
        transport: server,
        ownerIsCurrent: () => true,
        allowedScopes: const {'nutrition'},
      );
      await pa.set('goal.calories', '1000');
      expect((await restricted.run({'goals'})).reason, 'consent_missing');
      expect(server.calls, 0);
    },
  );

  test(
    'local reset does not turn a saved cloud dataset into tombstones',
    () async {
      await pa.set('goal.calories', '1000');
      await ea.run({'goals'});
      await LocalDataLifecycleService(a).clearAll();
      await LocalDataAccountBoundary(a).bindAuthenticatedOwner('owner');
      expect((await ea.run({'goals'})).completed, isTrue);
      expect(await pa.get('goal.calories'), '1000');
      expect(server.records.values.single['deleted'], false);
      final recovery = await a
          .customSelect('SELECT preimage FROM bil_local_restore_recovery_v2')
          .get();
      expect(recovery, isNotEmpty);
    },
  );

  test('conflict choice rejects a local edit made after review', () async {
    await pa.set('goal.calories', '1000');
    await ea.run({'goals'});
    await pb.set('goal.calories', '2000');
    await eb.run({'goals'});
    final row = (await eb.conflicts({'goals'})).single;
    final token = await eb.conflictToken(row);
    await pb.set('goal.calories', '2200');
    await expectLater(
      eb.resolveConflict(row.key, keepLocal: false, expectedToken: token),
      throwsStateError,
    );
    expect(await pb.get('goal.calories'), '2200');
    expect((await eb.conflicts({'goals'})).length, 1);
  });

  test(
    'conflict choice refreshes a cloud revision that changed after review',
    () async {
      await pa.set('goal.calories', '1000');
      await ea.run({'goals'});
      await pb.set('goal.calories', '2000');
      await eb.run({'goals'});
      final row = (await eb.conflicts({'goals'})).single;
      await pa.set('goal.calories', '1800');
      await ea.run({'goals'});
      await expectLater(
        eb.resolveConflict(
          row.key,
          keepLocal: false,
          expectedToken: await eb.conflictToken(row),
        ),
        throwsStateError,
      );
      expect(await pb.get('goal.calories'), '2000');
      final updated = (await eb.conflicts({'goals'})).single;
      await eb.resolveConflict(
        updated.key,
        keepLocal: false,
        expectedToken: await eb.conflictToken(updated),
      );
      expect(await pb.get('goal.calories'), '1800');
    },
  );

  test(
    'two engines for one SQLite database serialize the same pending operation',
    () async {
      await pa.set('goal.calories', '1000');
      final second = _engine(a, server, 'device-a');
      final results = await Future.wait([
        ea.run({'goals'}),
        second.run({'goals'}),
      ]);
      expect(results.every((result) => result.completed), isTrue);
      expect(server.accepted, 1);
    },
  );

  test(
    'edit during own acknowledged upload remains queued without a false conflict',
    () async {
      await pa.set('goal.calories', '1000');
      server.beforeReturn = () async {
        await pa.set('goal.calories', '1800');
      };
      final result = await ea.run({'goals'});
      expect(result.completed, isFalse);
      expect(result.pending, 1);
      expect(result.conflicts, 0);
      expect(await pa.get('goal.calories'), '1800');
      expect((await ea.run({'goals'})).completed, isTrue);
      expect((await eb.run({'goals'})).completed, isTrue);
      expect(await pb.get('goal.calories'), '1800');
    },
  );

  test(
    'unsupported decrypted payload version rolls back application and cursor',
    () async {
      await pa.set('goal.calories', '1000');
      await ea.run({'goals'});
      final row = server.records.values.single;
      final payload = row['payload'] as Map;
      final clear = jsonDecode(payload['clear'] as String) as Map;
      ((clear['snapshot'] as Map)['data'] as Map)['schema'] = 'future-version';
      payload['clear'] = jsonEncode(clear);
      expect((await eb.run({'goals'})).completed, isFalse);
      expect(await pb.get('goal.calories'), isNull);
      expect(await eb.journal.cursor('goals'), 0);
    },
  );

  for (final cancel in [true, false]) {
    testWidgets(
      'conflict editor real taps ${cancel ? 'cancel without writes' : 'accept cloud preserving local preimage'}',
      (tester) async {
        final prepared = await tester.runAsync(() async {
          await pa.set('goal.calories', '1000');
          await ea.run({'goals'});
          await pb.set('goal.calories', '2000');
          await eb.run({'goals'});
          return true;
        });
        expect(prepared, true);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cloudRestoreConsentStateProvider.overrideWith(
                (ref) async => const CloudRestoreConsentState(
                  availability: CloudRestoreConsentAvailability.available,
                  ownerId: 'owner',
                  grantedScopes: {CloudRestoreScope.goals},
                ),
              ),
              cloudRestoreConflictServiceProvider.overrideWithValue(
                CloudRestoreConflictService(() async => eb),
              ),
              cloudManualSyncStatusProvider.overrideWith(
                (ref) => CloudManualSyncStatusController(
                  preferences: pb,
                  runSync: () async => const CloudManualSyncResult(
                    disposition: CloudManualSyncDisposition.unavailable,
                  ),
                  cloudAvailable: true,
                  ownerId: 'owner',
                ),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: const Scaffold(body: CloudRestoreConflictControls()),
            ),
          ),
        );
        // Consent is asynchronous; wait for the authoritative fixture before
        // tapping, just as the real control remains disabled while loading.
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('cloud-restore-review-conflicts')),
        );
        for (
          var i = 0;
          i < 50 && find.bySubtype<AlertDialog>().evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(find.bySubtype<AlertDialog>(), findsOneWidget);
        expect(find.textContaining('1000 kcal'), findsOneWidget);
        expect(find.textContaining('2000 kcal'), findsOneWidget);
        await tester.tap(
          cancel
              ? find.text('Cancel')
              : find.byKey(const Key('restore-use-cloud')),
        );
        for (var i = 0; i < 30; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        final stored = await tester.runAsync(() => pb.get('goal.calories'));
        expect(stored, cancel ? '2000' : '1000');
        if (cancel) {
          expect(
            await tester.runAsync(() => eb.conflicts({'goals'})),
            hasLength(1),
          );
        } else {
          expect(
            (await tester.runAsync(
              () => eb.journal.entries('goals'),
            ))!.single.recovery,
            isNotNull,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
}

CloudRestoreV2Engine _engine(
  AppDatabase db,
  _ModelServer server,
  String device, {
  bool Function()? current,
}) => CloudRestoreV2Engine(
  database: db,
  ownerId: 'owner',
  deviceId: device,
  keyId: 'test-key',
  cipher: const _TransparentTestCipher(),
  transport: server,
  ownerIsCurrent: current ?? () => true,
  pageSize: 1,
);

final class _TransparentTestCipher implements CloudPayloadCipher {
  const _TransparentTestCipher();
  @override
  bool get isAvailable => true;
  @override
  Future<Map<String, Object?>> encrypt(Map<String, Object?> value) async => {
    'clear': jsonEncode(value),
  };
  @override
  Future<Map<String, Object?>> decrypt(Map<String, Object?> value) async =>
      Map<String, Object?>.from(jsonDecode(value['clear']! as String) as Map);
}

final class _ModelServer implements CloudRestoreV2Transport {
  int version = 2, calls = 0, sequence = 0, accepted = 0;
  int? failAtCall;
  bool granted = true, loseResponse = false;
  Future<void> Function()? beforeReturn;
  final records = <String, Map<String, Object?>>{};
  final receipts = <String, Map<String, Object?>>{};
  final fingerprints = <String, String>{};
  final seen = <Map<String, Object?>>[];
  @override
  Future<Map<String, Object?>> capabilities() async => {
    'protocol_version': version,
    'scopes': ['nutrition', 'goals'],
  };
  @override
  Future<Map<String, Object?>> consent() async => {
    for (final scope in ['nutrition', 'goals'])
      scope: {'granted': granted, 'policy_version': '1'},
  };
  @override
  Future<Map<String, Object?>> exchange({
    required String deviceId,
    required String scope,
    required int cursor,
    required List<Map<String, Object?>> operations,
    required int limit,
  }) async {
    calls++;
    if (calls == failAtCall) throw StateError('Synthetic network interruption');
    if (!granted) throw StateError('consent revoked');
    final results = <Map<String, Object?>>[];
    for (final operation in operations) {
      seen.add(Map<String, Object?>.from(operation));
      final id = operation['operation_id']! as String;
      final fp = jsonEncode(operation);
      if (receipts.containsKey(id)) {
        if (fingerprints[id] != fp) throw StateError('idempotency collision');
        results.add({...receipts[id]!, 'replayed': true});
        continue;
      }
      final key =
          '$scope:${operation['record_type']}:${operation['record_id']}';
      final old = records[key];
      final revision = old?['server_revision'] ?? 0;
      final conflict =
          revision != operation['expected_revision'] ||
          (old?['deleted'] == true && operation['mutation'] == 'upsert');
      final receipt = <String, Object?>{
        'operation_id': id,
        'outcome': conflict ? 'conflict' : 'accepted',
        'server_revision': conflict ? revision : (revision as int) + 1,
        'replayed': false,
      };
      if (conflict) {
        receipt['current_record'] = old;
      } else {
        accepted++;
        sequence++;
        records[key] = {
          'owner_id': 'owner',
          'scope': scope,
          'record_type': operation['record_type'],
          'record_id': operation['record_id'],
          'server_revision': (revision as int) + 1,
          'change_sequence': sequence,
          'deleted': operation['mutation'] == 'delete',
          'payload_version': operation['payload_version'],
          'payload': operation['payload'],
        };
      }
      fingerprints[id] = fp;
      receipts[id] = receipt;
      results.add(receipt);
    }
    final matching =
        records.values
            .where(
              (r) =>
                  r['scope'] == scope &&
                  (r['change_sequence']! as int) > cursor,
            )
            .toList()
          ..sort(
            (a, b) => (a['change_sequence']! as int).compareTo(
              b['change_sequence']! as int,
            ),
          );
    final page = matching.take(limit).toList();
    final hook = beforeReturn;
    beforeReturn = null;
    await hook?.call();
    if (loseResponse) {
      loseResponse = false;
      throw StateError('network lost after commit');
    }
    return {
      'protocol_version': 2,
      'scope': scope,
      'receipts': results,
      'records': page,
      'cursor': page.isEmpty ? cursor : page.last['change_sequence'],
      'has_more': matching.length > page.length,
    };
  }
}

final class _RestoreAggregateCounter extends QueryInterceptor {
  int rows = 0, selects = 0;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runSelect(statement, args);
    if (RegExp(
      r'FROM\s+"?(?:meals|meal_items)"?',
      caseSensitive: false,
    ).hasMatch(statement)) {
      rows += result.length;
      selects++;
    }
    return result;
  }
}
