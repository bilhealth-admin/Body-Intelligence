import 'dart:convert';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_nutrition_snapshot_codec.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_platform_ports.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_v2_engine.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_v2_transport.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../nutrition/gemini_vision_net_consumers_causal_test.dart'
    show owner, day, seedGemini;

class _Fixture {
  final a = AppDatabase.forTesting(
    NativeDatabase.memory(),
    localOwnerId: owner,
  );
  final b = AppDatabase.forTesting(
    NativeDatabase.memory(),
    localOwnerId: owner,
  );
  final server = _ModelServer();
  late final ea = _engine(a, server, 'a'), eb = _engine(b, server, 'b');

  Future<void> init({
    double net = 16.9,
    bool ordinary = false,
    bool restoreB = true,
  }) async {
    for (final db in [a, b]) {
      await LocalDataAccountBoundary(db).bindAuthenticatedOwner(owner);
    }
    await DailyLogRepository(a).startDay(day);
    await seedGemini(a, net);
    if (ordinary) await snack();
    await DailyLogRepository(a).closeDay(day);
    final uploaded = await ea.run({'nutrition'});
    expect(uploaded.completed, isTrue, reason: uploaded.reason);
    if (restoreB) {
      final downloaded = await eb.run({'nutrition'});
      expect(downloaded.completed, isTrue, reason: downloaded.reason);
    }
  }

  Future<void> snack() => MealRepository(a)
      .addQuickMacroEntry(
        date: day,
        mealType: 'snack',
        calories: 20,
        protein: 0,
        carbohydrates: 5,
        fat: 0,
        caloriesKnown: true,
        proteinKnown: true,
        carbohydratesKnown: true,
        fatKnown: true,
      )
      .then((_) {});

  Future<void> sync() async {
    final uploaded = await ea.run({'nutrition'});
    expect(uploaded.completed, isTrue, reason: uploaded.reason);
    final downloaded = await eb.run({'nutrition'});
    expect(downloaded.completed, isTrue, reason: downloaded.reason);
  }

  Future<void> close() async {
    await a.close();
    await b.close();
  }
}

CloudNutritionSnapshot _typedTombstone(
  CloudNutritionSnapshot captured,
  Meal meal,
  DailyLog log,
) {
  final wire = Map<String, Object?>.from(meal.toJson())
    ..remove('id')
    ..remove('syncStatus');
  for (final key in ['date', 'createdAt', 'updatedAt', 'deletedAt']) {
    final value = wire[key];
    if (value is int) {
      wire[key] = DateTime.fromMillisecondsSinceEpoch(
        value,
        isUtc: true,
      ).toIso8601String();
    }
  }
  return CloudNutritionSnapshot(
    scope: captured.scope,
    type: captured.type,
    id: captured.id,
    deleted: true,
    data: {
      ...captured.data,
      'meal': wire,
      'visionDayLifecycle': {
        'schema': 'bil.vision.estimate.day-lifecycle.v1',
        'state': log.lifecycleState,
        'lastClosedSnapshot': log.finalVisionNutrientEvidenceJson!,
      },
    },
  );
}

Map<String, Object?> _copy(Object? source) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(source)) as Map);

void main() {
  const sameFingerprintFaults = [
    'missing-header-deletedAt',
    'malformed-header-deletedAt',
    'meal-uuid',
    'missing-meal-deletedAt',
    'mismatched-meal-deletedAt',
    'meal-revision',
    'unknown-meal-id',
    'unknown-data-id',
    'header-schema',
    'header-owner',
  ];
  for (final fault in [
    ...sameFingerprintFaults,
    'lifecycle-schema',
    'lifecycle-owner',
    'lifecycle-day',
  ]) {
    test(
      'real engine rejects $fault before equality shortcut without ack/cursor advance',
      () async {
        final f = _Fixture();
        try {
          await f.init();
          await DailyLogRepository(f.b).reopenDay(day);
          await MealRepository(
            f.b,
          ).deleteMealCascade((await f.b.select(f.b.meals).get()).single.id);
          final acknowledged = await f.eb.run({'nutrition'});
          expect(acknowledged.completed, isTrue, reason: acknowledged.reason);
          final local = (await f.eb.codec.capture(
            scopes: {'nutrition'},
          )).singleWhere((r) => r.type == 'meal');
          final meal = (await f.b.select(f.b.meals).get()).single;
          final log = (await DailyLogRepository(f.b).getForDay(day))!;
          final typed = _typedTombstone(local, meal, log);
          expect(typed.deleted, isTrue);
          expect(meal.deletedAt, isNotNull);
          expect(snapshotFingerprint(typed), snapshotFingerprint(local));
          final before = (await f.eb.journal.entry(local.key))!;
          expect(before.pending, isNull);
          expect(before.conflict, isNull);
          final cursor = await f.eb.journal.cursor('nutrition');
          final data = _copy(typed.data), row = _copy(typed.data['meal']);
          data['meal'] = row;
          switch (fault) {
            case 'missing-header-deletedAt':
              data.remove('deletedAt');
            case 'malformed-header-deletedAt':
              data['deletedAt'] = 'not-a-UTC-date';
            case 'meal-uuid':
              row['uuid'] = 'different-synthetic-meal';
            case 'missing-meal-deletedAt':
              row['deletedAt'] = null;
            case 'mismatched-meal-deletedAt':
              row['deletedAt'] = '2026-11-17T00:00:00.000Z';
            case 'meal-revision':
              row['revision'] = 0;
            case 'unknown-meal-id':
              row['id'] = 123;
            case 'unknown-data-id':
              data['id'] = 123;
            case 'header-schema':
              data['schema'] = 'invalid-synthetic-schema';
            case 'header-owner':
              data['ownerId'] = 'different-synthetic-owner';
            default:
              final lifecycle = _copy(data['visionDayLifecycle']);
              data['visionDayLifecycle'] = lifecycle;
              if (fault == 'lifecycle-schema') {
                lifecycle['schema'] = 'invalid-synthetic-lifecycle';
              } else {
                final frozen = _copy(
                  jsonDecode(lifecycle['lastClosedSnapshot']! as String),
                );
                frozen[fault == 'lifecycle-owner'
                    ? 'ownerKey'
                    : 'dayKey'] = fault == 'lifecycle-owner'
                    ? LocalDatabaseScope.keyForOwner(
                        'different-synthetic-owner',
                      )
                    : '2026-11-17';
                lifecycle['lastClosedSnapshot'] = jsonEncode(frozen);
              }
          }
          final tampered = CloudNutritionSnapshot(
            scope: typed.scope,
            type: typed.type,
            id: typed.id,
            deleted: true,
            data: data,
          );
          if (sameFingerprintFaults.contains(fault)) {
            expect(snapshotFingerprint(tampered), snapshotFingerprint(local));
          }
          final record = Map<String, Object?>.from(
            f.server.records[local.key]!,
          );
          final payload = _copy(record['payload']);
          final envelope = _copy(jsonDecode(payload['clear']! as String));
          envelope['snapshot'] = tampered.toJson();
          f.server.delay({
            ...record,
            'server_revision': before.revision + 1,
            'payload': {...payload, 'clear': jsonEncode(envelope)},
          });
          final result = await f.eb.run({'nutrition'});
          expect(result.completed, isFalse);
          expect(result.reason, 'payload_invalid_or_key_missing');
          expect(result.pushed, 0);
          expect(result.applied, 0);
          final after = (await f.eb.journal.entry(local.key))!;
          expect(after.revision, before.revision);
          expect(after.baseline, before.baseline);
          expect(after.pending, isNull);
          expect(after.conflict, isNull);
          expect(await f.eb.journal.cursor('nutrition'), cursor);
          final retained = (await f.b.select(f.b.meals).get()).single;
          expect(retained.uuid, meal.uuid);
          expect(retained.deletedAt, meal.deletedAt);
          expect(
            (await DailyLogRepository(
              f.b,
            ).getForDay(day))!.finalVisionNutrientEvidenceJson,
            log.finalVisionNutrientEvidenceJson,
          );
        } finally {
          await f.close();
        }
      },
    );
  }
  test(
    'real engine still acknowledges valid equal typed tombstone and preserves deletion',
    () async {
      final f = _Fixture();
      try {
        await f.init();
        await DailyLogRepository(f.b).reopenDay(day);
        await MealRepository(
          f.b,
        ).deleteMealCascade((await f.b.select(f.b.meals).get()).single.id);
        expect((await f.eb.run({'nutrition'})).completed, isTrue);
        final local = (await f.eb.codec.capture(
          scopes: {'nutrition'},
        )).singleWhere((r) => r.type == 'meal');
        final meal = (await f.b.select(f.b.meals).get()).single;
        final log = (await DailyLogRepository(f.b).getForDay(day))!;
        final typed = _typedTombstone(local, meal, log);
        expect(snapshotFingerprint(typed), snapshotFingerprint(local));
        final before = (await f.eb.journal.entry(local.key))!;
        final record = Map<String, Object?>.from(f.server.records[local.key]!);
        final payload = _copy(record['payload']);
        final envelope = _copy(jsonDecode(payload['clear']! as String));
        envelope['snapshot'] = typed.toJson();
        f.server.delay({
          ...record,
          'server_revision': before.revision + 1,
          'payload': {...payload, 'clear': jsonEncode(envelope)},
        });
        final result = await f.eb.run({'nutrition'});
        expect(result.completed, isTrue, reason: result.reason);
        expect(result.pushed, 0);
        expect(
          (await f.eb.journal.entry(local.key))!.revision,
          before.revision + 1,
        );
        expect(
          (await f.b.select(f.b.meals).get()).single.deletedAt,
          meal.deletedAt,
        );
        expect(
          (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
          'open',
        );
      } finally {
        await f.close();
      }
    },
  );
}

CloudRestoreV2Engine _engine(
  AppDatabase db,
  _ModelServer server,
  String device,
) => CloudRestoreV2Engine(
  database: db,
  ownerId: owner,
  deviceId: device,
  keyId: 'synthetic-key',
  cipher: const _TransparentTestCipher(),
  transport: server,
  ownerIsCurrent: () => true,
  pageSize: 100,
);

/// Synthetic transport/transparent cipher only; production SQLite/engine and
/// its real journal are used. This is not SQL/RLS/hosted encryption evidence.

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
  int sequence = 0;
  final replay = <Map<String, Object?>>[];
  void delay(Map<String, Object?> record) {
    replay.add({...record, 'change_sequence': ++sequence});
  }

  final records = <String, Map<String, Object?>>{};
  final receipts = <String, Map<String, Object?>>{};
  final fingerprints = <String, String>{};
  final seen = <Map<String, Object?>>[];
  @override
  Future<Map<String, Object?>> capabilities() async => {
    'protocol_version': 2,
    'scopes': ['nutrition', 'goals'],
  };
  @override
  Future<Map<String, Object?>> consent() async => {
    for (final scope in ['nutrition', 'goals'])
      scope: {'granted': true, 'policy_version': '1'},
  };
  @override
  Future<Map<String, Object?>> exchange({
    required String deviceId,
    required String scope,
    required int cursor,
    required List<Map<String, Object?>> operations,
    required int limit,
  }) async {
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
        sequence++;
        records[key] = {
          'owner_id': owner,
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
        [...records.values, ...replay]
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
    replay.removeWhere(page.contains);
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
