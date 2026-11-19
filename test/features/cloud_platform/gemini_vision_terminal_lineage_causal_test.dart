import 'dart:convert';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/final_vision_nutrition.dart';
import 'package:body_intelligence_log/data/database/vision_estimate_evidence.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_nutrition_snapshot_codec.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_platform_ports.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_v2_engine.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_v2_transport.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../nutrition/gemini_vision_net_consumers_causal_test.dart'
    show owner, day, seedGemini;

/// Real isolated SQLite databases/repositories/restore engine and journal.
/// The in-memory CAS transport and transparent cipher are test doubles only.
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

void main() {
  for (final net in [16.9, 0.0]) {
    test(
      'offline last-meal tombstone carries reopen and preserves prior direct net $net only as lineage',
      () async {
        final f = _Fixture();
        try {
          await f.init(net: net);
          final before = (await DailyLogRepository(f.b).getForDay(day))!;
          await DailyLogRepository(f.b).save(
            date: day,
            notes: 'Local private note',
            sleepHours: 7,
            steps: 123,
          );
          await DailyLogRepository(f.a).reopenDay(day);
          final meal = (await f.a.select(f.a.meals).get()).single;
          await MealRepository(f.a).deleteMealCascade(meal.id);
          final outgoing = (await f.ea.codec.capture(
            scopes: {'nutrition'},
          )).singleWhere((r) => r.type == 'meal');
          expect(outgoing.data.keys.toSet(), {
            'schema',
            'ownerId',
            'deletedAt',
            'meal',
            'visionDayLifecycle',
          });
          expect((outgoing.data['meal']! as Map).keys.toSet(), {
            'uuid',
            'createdAt',
            'updatedAt',
            'deletedAt',
            'revision',
            'date',
            'dayKey',
            'name',
            'type',
          });
          expect(
            jsonEncode(outgoing.data),
            isNot(contains('Local private note')),
          );
          expect(outgoing.data.containsKey('items'), isFalse);
          await f.sync();
          final after = (await DailyLogRepository(f.b).getForDay(day))!;
          expect(after.lifecycleState, 'open');
          expect(after.closedAt, isNull);
          expect(
            after.finalVisionNutrientEvidenceJson,
            before.finalVisionNutrientEvidenceJson,
          );
          expect(
            FinalVisionNutrition.decode(
              after.finalVisionNutrientEvidenceJson!,
            ).directNetCarbohydrates,
            net,
          );
          expect(after.notes, 'Local private note');
          expect(after.sleepHours, 7);
          expect(after.steps, 123);
          final ledger = await DailyLogRepository(f.b).readLedger(day);
          expect(ledger.calories, isNull);
          expect(ledger.netCarbohydrates, isNull);
          expect(
            (await f.b.select(f.b.mealItems).get()).where(
              (r) => r.deletedAt == null,
            ),
            isEmpty,
          );
        } finally {
          await f.close();
        }
      },
    );
  }
  test(
    'all-meal tombstones carry open then empty close through the same server revisions',
    () async {
      final f = _Fixture();
      try {
        await f.init(ordinary: true);
        await DailyLogRepository(f.a).reopenDay(day);
        for (final meal in await f.a.select(f.a.meals).get()) {
          await MealRepository(f.a).deleteMealCascade(meal.id);
        }
        await f.sync();
        expect(
          (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
          'open',
        );
        final openSnapshots = await f.ea.codec.capture(scopes: {'nutrition'});
        final removed = openSnapshots.where((r) => r.type == 'meal').toList();
        expect(removed, hasLength(2));
        expect(removed.every((r) => r.deleted), isTrue);
        await DailyLogRepository(f.a).closeDay(day);
        final closedSnapshots = await f.ea.codec.capture(scopes: {'nutrition'});
        for (final prior in removed) {
          expect(
            snapshotFingerprint(
              closedSnapshots.singleWhere((r) => r.key == prior.key),
            ),
            isNot(snapshotFingerprint(prior)),
          );
        }
        await f.sync();
        final log = (await DailyLogRepository(f.b).getForDay(day))!;
        expect(log.lifecycleState, 'closed');
        final frozen = FinalVisionNutrition.decode(
          log.finalVisionNutrientEvidenceJson!,
        );
        expect(frozen.nutrients, hasLength(FoodNutrient.values.length));
        expect(frozen.nutrients.values, everyElement(isNull));
        expect(frozen.directNetCarbohydrates, isNull);
        final ledger = await DailyLogRepository(f.b).readLedger(day);
        expect(ledger.calories, isNull);
        expect(ledger.netCarbohydrates, isNull);
      } finally {
        await f.close();
      }
    },
  );
  test(
    'removing last Vision item then reclosing uses only current ordinary food evidence',
    () async {
      final f = _Fixture();
      try {
        await f.init(ordinary: true);
        await DailyLogRepository(f.a).reopenDay(day);
        final vision = (await f.a.select(f.a.mealItems).get()).firstWhere(
          (r) => r.foodSourceSnapshot == VisionFoodEvidence.source,
        );
        await MealRepository(f.a).deleteMealItem(vision.id);
        await DailyLogRepository(f.a).closeDay(day);
        await f.sync();
        final log = (await DailyLogRepository(f.b).getForDay(day))!;
        expect(log.lifecycleState, 'closed');
        final frozen = FinalVisionNutrition.decode(
          log.finalVisionNutrientEvidenceJson!,
        );
        expect(frozen.nutrients[FoodNutrient.calories], 20);
        expect(frozen.nutrients[FoodNutrient.carbohydrates], 5);
        expect(frozen.nutrients[FoodNutrient.vitaminA], isNull);
        expect(frozen.directNetCarbohydrates, isNull);
        expect((await DailyLogRepository(f.b).readLedger(day)).calories, 20);
      } finally {
        await f.close();
      }
    },
  );
  test(
    'fresh B retains real deleted meal and owned Vision food without resurrection or spurious upload',
    () async {
      final f = _Fixture();
      try {
        await f.init(restoreB: false);
        await DailyLogRepository(f.a).reopenDay(day);
        await MealRepository(
          f.a,
        ).deleteMealCascade((await f.a.select(f.a.meals).get()).single.id);
        expect((await f.ea.run({'nutrition'})).completed, isTrue);
        final first = await f.eb.run({'nutrition'});
        expect(first.completed, isTrue, reason: first.reason);
        expect(first.pending, 0);
        expect(first.conflicts, 0);
        final bMeal = (await f.b.select(f.b.meals).get()).single;
        expect(bMeal.deletedAt, isNotNull);
        expect(bMeal.name, 'lunch');
        expect(await f.b.select(f.b.mealItems).get(), isEmpty);
        expect(
          (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
          'open',
        );
        final recaptured = await f.eb.codec.capture(scopes: {'nutrition'});
        expect(recaptured.where((r) => r.type == 'food'), hasLength(1));
        expect(recaptured.singleWhere((r) => r.type == 'meal').deleted, isTrue);
        final operations = f.server.seen.length;
        final repeat = await f.eb.run({'nutrition'});
        expect(repeat.completed, isTrue, reason: repeat.reason);
        expect(repeat.pushed, 0);
        expect(f.server.seen.length, operations);
        await DailyLogRepository(f.a).closeDay(day);
        await f.sync();
        expect(
          (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
          'closed',
        );
        expect((await f.b.select(f.b.meals).get()).single.deletedAt, isNotNull);
        expect(
          (await DailyLogRepository(f.b).readLedger(day)).calories,
          isNull,
        );
      } finally {
        await f.close();
      }
    },
  );
  test(
    'new remote sibling cannot bypass pending deleted local sibling',
    () async {
      final f = _Fixture();
      try {
        await f.init();
        await DailyLogRepository(f.b).reopenDay(day);
        await MealRepository(
          f.b,
        ).deleteMealCascade((await f.b.select(f.b.meals).get()).single.id);
        await DailyLogRepository(f.a).reopenDay(day);
        await f.snack();
        await DailyLogRepository(f.a).closeDay(day);
        expect((await f.ea.run({'nutrition'})).completed, isTrue);
        final report = await f.eb.run({'nutrition'});
        expect(report.conflicts, greaterThan(0));
        expect(
          (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
          'open',
        );
        expect(
          (await f.b.select(f.b.meals).get()).where((r) => r.type == 'snack'),
          isEmpty,
        );
      } finally {
        await f.close();
      }
    },
  );
  test(
    'legacy deleted meal without lifecycle remains no day instruction',
    () async {
      final f = _Fixture();
      try {
        await f.init();
        await DailyLogRepository(f.a).reopenDay(day);
        await MealRepository(
          f.a,
        ).deleteMealCascade((await f.a.select(f.a.meals).get()).single.id);
        final actual = (await f.ea.codec.capture(
          scopes: {'nutrition'},
        )).singleWhere((r) => r.type == 'meal');
        final legacy = Map<String, Object?>.from(actual.data)
          ..remove('visionDayLifecycle')
          ..remove('meal');
        await f.eb.codec.apply(
          CloudNutritionSnapshot(
            scope: actual.scope,
            type: actual.type,
            id: actual.id,
            deleted: true,
            data: legacy,
          ),
        );
        expect(
          (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
          'closed',
        );
        expect((await DailyLogRepository(f.b).readLedger(day)).calories, 160);
      } finally {
        await f.close();
      }
    },
  );
  for (final fault in ['ownerKey', 'dayKey', 'logUuid']) {
    test(
      'typed tombstone rejects mismatched $fault and rolls deletion back',
      () async {
        final f = _Fixture();
        try {
          await f.init();
          await DailyLogRepository(f.a).reopenDay(day);
          await MealRepository(
            f.a,
          ).deleteMealCascade((await f.a.select(f.a.meals).get()).single.id);
          final actual = (await f.ea.codec.capture(
            scopes: {'nutrition'},
          )).singleWhere((r) => r.type == 'meal');
          expect(actual.data['visionDayLifecycle'], isA<Map>());
          final lifecycle = Map<String, Object?>.from(
            actual.data['visionDayLifecycle']! as Map,
          );
          final frozen = Map<String, dynamic>.from(
            jsonDecode(lifecycle['lastClosedSnapshot']! as String) as Map,
          );
          frozen[fault] = switch (fault) {
            'ownerKey' => LocalDatabaseScope.keyForOwner(
              'other-synthetic-owner',
            ),
            'dayKey' => '2026-11-17',
            _ => 'different-synthetic-log',
          };
          lifecycle['lastClosedSnapshot'] = jsonEncode(frozen);
          await expectLater(
            f.eb.codec.apply(
              CloudNutritionSnapshot(
                scope: actual.scope,
                type: actual.type,
                id: actual.id,
                deleted: true,
                data: {...actual.data, 'visionDayLifecycle': lifecycle},
              ),
            ),
            throwsFormatException,
          );
          expect((await f.b.select(f.b.meals).get()).single.deletedAt, isNull);
          expect(
            (await f.b.select(f.b.mealItems).get()).single.deletedAt,
            isNull,
          );
          expect(
            (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
            'closed',
          );
        } finally {
          await f.close();
        }
      },
    );
  }
  for (final fault in ['uuid', 'deletedAt', 'headerDeletedAt']) {
    test(
      'typed tombstone rejects real-row $fault mismatch before retaining deletion',
      () async {
        final f = _Fixture();
        try {
          await f.init();
          await DailyLogRepository(f.a).reopenDay(day);
          await MealRepository(
            f.a,
          ).deleteMealCascade((await f.a.select(f.a.meals).get()).single.id);
          final actual = (await f.ea.codec.capture(
            scopes: {'nutrition'},
          )).singleWhere((r) => r.type == 'meal');
          expect(actual.data['visionDayLifecycle'], isA<Map>());
          final meal = Map<String, Object?>.from(actual.data['meal']! as Map);
          final tampered = <String, Object?>{...actual.data, 'meal': meal};
          if (fault == 'headerDeletedAt') {
            tampered.remove('deletedAt');
          } else {
            meal[fault] = fault == 'uuid' ? 'different-synthetic-meal' : null;
          }
          await expectLater(
            f.eb.codec.apply(
              CloudNutritionSnapshot(
                scope: actual.scope,
                type: actual.type,
                id: actual.id,
                deleted: true,
                data: tampered,
              ),
            ),
            throwsFormatException,
          );
          expect((await f.b.select(f.b.meals).get()).single.deletedAt, isNull);
          expect(
            (await f.b.select(f.b.mealItems).get()).single.deletedAt,
            isNull,
          );
        } finally {
          await f.close();
        }
      },
    );
  }
  for (final fault in ['foreign-owner', 'invalid-json']) {
    test(
      'orphan $fault Vision food is excluded while ordinary catalog scope stays unchanged',
      () async {
        final f = _Fixture();
        try {
          await f.init();
          final source = (await f.b.select(f.b.foods).get()).single;
          final basis = VisionFoodEvidence.decode(source.foodEvidenceJson!);
          final uuid = 'synthetic-orphan-$fault';
          final foreign = VisionFoodEvidence(
            identity: uuid,
            ownerKey: LocalDatabaseScope.keyForOwner('other-synthetic-owner'),
            estimate: basis.estimate,
          );
          await f.b
              .into(f.b.foods)
              .insert(
                source
                    .toCompanion(false)
                    .copyWith(
                      id: const Value.absent(),
                      uuid: Value(uuid),
                      foodEvidenceJson: Value(
                        fault == 'invalid-json'
                            ? 'invalid-json'
                            : foreign.encode(),
                      ),
                    ),
              );
          const catalogUuid = 'ordinary-orphan-catalog';
          await f.b
              .into(f.b.foods)
              .insert(
                source
                    .toCompanion(false)
                    .copyWith(
                      id: const Value.absent(),
                      uuid: const Value(catalogUuid),
                      source: const Value('catalog'),
                      category: const Value('ordinary'),
                      foodEvidenceJson: const Value(null),
                    ),
              );
          final captured = await f.eb.codec.capture(scopes: {'nutrition'});
          expect(
            captured.where((r) => r.type == 'food').map((r) => r.id),
            isNot(contains(uuid)),
          );
          expect(
            captured.where((r) => r.type == 'food').map((r) => r.id),
            isNot(contains(catalogUuid)),
          );
          expect(
            await f.eb.codec.capture(
              scopes: {'nutrition'},
              recordType: 'food',
              recordId: uuid,
            ),
            isEmpty,
          );
        } finally {
          await f.close();
        }
      },
    );
  }
  test(
    'invalid referenced Vision food still fails closed instead of being hidden by orphan filtering',
    () async {
      final f = _Fixture();
      try {
        await f.init();
        await f.b.customStatement(
          "UPDATE foods SET food_evidence_json='invalid-json'",
        );
        await expectLater(
          f.eb.codec.capture(scopes: {'nutrition'}),
          throwsFormatException,
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
