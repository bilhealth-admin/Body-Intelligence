import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/final_vision_nutrition.dart';
import 'package:body_intelligence_log/data/database/vision_estimate_evidence.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_platform_ports.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_nutrition_snapshot_codec.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_v2_engine.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_v2_transport.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:body_intelligence_log/features/nutrition/domain/gemini_vision_estimate.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../nutrition/gemini_vision_net_consumers_causal_test.dart'
    show owner, day, seedGemini;

String _describe(CloudRestoreV2Report r) =>
    'reason=${r.reason}; conflicts=${r.conflicts}; pending=${r.pending}; pushed=${r.pushed}; applied=${r.applied}';

final class _UpdateHold extends QueryInterceptor {
  bool armed = false, insideTransaction = false;
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    if (armed &&
        RegExp(
          r'^\s*UPDATE\s+"?meals"?\s',
          caseSensitive: false,
        ).hasMatch(sql)) {
      armed = false;
      insideTransaction = executor is TransactionExecutor;
      entered.complete();
      await release.future;
    }
    return executor.runUpdate(sql, args);
  }
}

class _Fixture {
  _Fixture(this.order, {this.hold})
    : a = AppDatabase.forTesting(NativeDatabase.memory(), localOwnerId: owner),
      b = AppDatabase.forTesting(
        hold == null
            ? NativeDatabase.memory()
            : NativeDatabase.memory().interceptWith(hold),
        localOwnerId: owner,
      );
  final String order;
  final _UpdateHold? hold;
  final AppDatabase a, b;
  final server = _ModelServer();
  late final ea = _engine(a, server, 'a'), eb = _engine(b, server, 'b');
  Future<MealItem> visionItem(AppDatabase db) async =>
      (await db.select(db.mealItems).get()).singleWhere(
        (i) => i.foodSourceSnapshot == VisionFoodEvidence.source,
      );
  Future<MealItem> ordinaryItem(AppDatabase db) async =>
      (await db.select(db.mealItems).get()).singleWhere(
        (i) => i.foodSourceSnapshot != VisionFoodEvidence.source,
      );
  Future<void> init() async {
    for (final db in [a, b]) {
      await LocalDataAccountBoundary(db).bindAuthenticatedOwner(owner);
    }
    await DailyLogRepository(a).startDay(day);
    await seedGemini(a, 16.9);
    await MealRepository(a).addQuickMacroEntry(
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
    );
    // Valid synthetic UUIDs make the production codec/server order explicit;
    // every subsequent transition/edit uses the actual repositories.
    const first = '10000000-0000-4000-8000-000000000001';
    const last = '90000000-0000-4000-8000-000000000002';
    final meals = await a.select(a.meals).get();
    for (final meal in meals) {
      final isFirst = (meal.type == 'lunch') == (order == 'vision-first');
      await (a.update(a.meals)..where((row) => row.id.equals(meal.id))).write(
        MealsCompanion(uuid: Value(isFirst ? first : last)),
      );
    }
    await DailyLogRepository(a).closeDay(day);
    final up = await ea.run({'nutrition'}), down = await eb.run({'nutrition'});
    expect(up.completed, isTrue, reason: _describe(up));
    expect(down.completed, isTrue, reason: _describe(down));
  }

  Future<CloudRestoreV2Report> transfer() async {
    final up = await ea.run({'nutrition'});
    expect(up.completed, isTrue, reason: _describe(up));
    return eb.run({'nutrition'});
  }

  Future<void> close() async {
    if (hold != null && !hold!.release.isCompleted) {
      hold!.release.complete();
    }
    await a.close();
    await b.close();
  }
}

final class _PartialCas {
  final f = _Fixture('ordinary-first');
  final c = AppDatabase.forTesting(
    NativeDatabase.memory(),
    localOwnerId: owner,
  );
  late final ec = _engine(c, f.server, 'c');
  late final MealItem addedItem;
  late final MealFoodEvidence addedEvidence;

  Future<void> init({
    double calories = 30,
    bool known = true,
    double updatedQuantity = 2,
  }) async {
    await f.init();
    await LocalDataAccountBoundary(c).bindAuthenticatedOwner(owner);
    expect((await ec.run({'nutrition'})).completed, isTrue);
    await DailyLogRepository(f.a).reopenDay(day);
    await MealRepository(f.a).updateMealItem(
      id: (await f.ordinaryItem(f.a)).id,
      quantity: updatedQuantity,
    );
    await DailyLogRepository(f.a).closeDay(day);
    expect((await f.transfer()).completed, isTrue);
    await DailyLogRepository(c).reopenDay(day);
    if (known && calories == 0) {
      // Adding a zero member can leave every old parent payload unchanged,
      // including a same-second close. Make this a genuine competing local
      // edit through the normal repository, not a timestamp-dependent conflict.
      final staleOrdinary = await f.ordinaryItem(c);
      expect(staleOrdinary.quantity, 1);
      final competingQuantity = updatedQuantity + 1;
      await MealRepository(
        c,
      ).updateMealItem(id: staleOrdinary.id, quantity: competingQuantity);
      expect((await f.ordinaryItem(c)).quantity, competingQuantity);
      // Zero calories is a real positive portion with known-zero nutrition,
      // not an all-zero Quick Macro request that production rejects.
      const request = 'accepted-zero-seasoning';
      final estimate = GeminiVisionEstimate(
        requestId: request,
        index: 0,
        name: 'Synthetic zero-calorie seasoning',
        modelRevision: 'gemini-test',
        promptRevision: 'photo-test',
        basis: GeminiEstimateBasis(quantity: 1, unit: 'g'),
        picturedAmount: 1,
        picturedUnit: 'g',
        nutrients: GeminiEstimateNutrients({
          FoodNutrient.calories: 0,
          FoodNutrient.protein: 0,
          FoodNutrient.carbohydrates: 0,
          FoodNutrient.fat: 0,
          FoodNutrient.fiber: 0,
          FoodNutrient.sugar: 0,
          FoodNutrient.sodium: 100,
        }, netCarbohydrates: 0),
      );
      await MealRepository(c).addGeminiVisionMealAtomically(
        date: day,
        mealType: 'breakfast',
        ownerId: owner,
        requestId: request,
        items: [
          ReviewedGeminiVisionEstimate(
            estimate: estimate,
            amount: 1,
            unit: 'g',
          ),
        ],
        isCurrentOwner: () => true,
      );
    } else {
      // An unknown nutrient is stored as numeric zero plus a missing known
      // bit. A known protein value makes this a valid nonempty Quick Add.
      await MealRepository(c).addQuickMacroEntry(
        date: day,
        mealType: 'breakfast',
        calories: calories,
        protein: known ? 0 : 1,
        carbohydrates: 0,
        fat: 0,
        caloriesKnown: known,
        proteinKnown: true,
        carbohydratesKnown: true,
        fatKnown: true,
      );
    }
    final addedMeal = (await c.select(c.meals).get()).singleWhere(
      (meal) => meal.type == 'breakfast',
    );
    addedItem = (await c.select(c.mealItems).get()).singleWhere(
      (item) => item.mealId == addedMeal.id && item.deletedAt == null,
    );
    expect(addedItem.quantity, greaterThan(0));
    addedEvidence = MealFoodEvidence.read(
      addedItem,
      ownerKey: LocalDatabaseScope.keyForOwner(owner),
    );
    expect(
      addedEvidence.fullValue(FoodNutrient.calories),
      known ? calories : null,
    );
    if (known && calories == 0) {
      expect(addedEvidence.vision, isNotNull);
      expect(addedEvidence.fullValue(FoodNutrient.sodium), 100);
      expect(FinalVisionNutrition.netForRows([addedEvidence]), 0);
    }
    await DailyLogRepository(c).closeDay(day);
    final oldParents = (await c.select(c.meals).get())
        .where((meal) => meal.type != 'breakfast')
        .map((m) => m.uuid)
        .toSet();
    final dirtyParents = (await ec.codec.capture(scopes: {'nutrition'}))
        .where(
          (snapshot) =>
              snapshot.type == 'meal' && oldParents.contains(snapshot.id),
        )
        .toList();
    expect(dirtyParents, hasLength(2));
    for (final snapshot in dirtyParents) {
      final baseline = (await ec.journal.entry(snapshot.key))!;
      expect(baseline.revision, 1);
      expect(baseline.baseline, isNotNull);
      expect(baseline.pending, isNull);
      expect(baseline.conflict, isNull);
      expect(
        snapshotFingerprint(snapshot),
        isNot(baseline.baseline),
        reason: 'A competing parent must be actually dirty before CAS.',
      );
      expect(
        f.server.records['nutrition:meal:${snapshot.id}']!['server_revision'],
        2,
      );
    }
    final seen = f.server.seen.length;
    final report = await ec.run({'nutrition'});
    expect(report.conflicts, 2, reason: _describe(report));
    final operations = f.server.seen
        .skip(seen)
        .where((op) => op['record_type'] == 'meal')
        .toList();
    expect(operations, hasLength(3));
    for (final op in operations) {
      final old = oldParents.contains(op['record_id']);
      expect(op['expected_revision'], old ? 1 : 0);
      expect(
        f.server.receipts[op['operation_id']]!['outcome'],
        old ? 'conflict' : 'accepted',
      );
    }
    final observer = await f.eb.run({'nutrition'});
    expect(observer.completed, isTrue, reason: _describe(observer));
    final retained = (await f.b.select(f.b.mealItems).get())
        .where((item) => item.uuid == addedItem.uuid)
        .toList();
    expect(
      retained,
      hasLength(1),
      reason: 'Zero/unknown members retain their identity.',
    );
    expect(retained.single.deletedAt, isNull);
    expect(retained.single.quantity, addedItem.quantity);
    final observed = MealFoodEvidence.read(
      retained.single,
      ownerKey: LocalDatabaseScope.keyForOwner(owner),
    );
    for (final nutrient in FoodNutrient.values) {
      expect(
        observed.fullValue(nutrient),
        addedEvidence.fullValue(nutrient),
        reason: 'Accepted member retains nullable ${nutrient.name} evidence.',
      );
    }
    expect(
      FinalVisionNutrition.netForRows([observed]),
      FinalVisionNutrition.netForRows([addedEvidence]),
    );
  }

  Future<void> close() async {
    await c.close();
    await f.close();
  }
}

Future<List<MealFoodEvidence>> _acceptedEvidence(AppDatabase db) async {
  final meals = (await db.select(db.meals).get())
      .where((m) => m.deletedAt == null && m.dayKey == '2026-11-18')
      .map((m) => m.id)
      .toSet();
  return [
    for (final item in await db.select(db.mealItems).get())
      if (item.deletedAt == null && meals.contains(item.mealId))
        MealFoodEvidence.read(
          item,
          ownerKey: LocalDatabaseScope.keyForOwner(owner),
        ),
  ];
}

Future<FinalVisionNutrition> _assertAcceptedProjection(AppDatabase db) async {
  final log = (await DailyLogRepository(db).getForDay(day))!;
  final frozen = FinalVisionNutrition.decode(
    log.finalVisionNutrientEvidenceJson!,
  );
  expect(frozen.matches(log, LocalDatabaseScope.keyForOwner(owner)), isTrue);
  final rows = await _acceptedEvidence(db);
  for (final nutrient in FoodNutrient.values) {
    final values = rows.map((row) => row.fullValue(nutrient)).toList();
    final double? expected = values.isEmpty || values.any((v) => v == null)
        ? null
        : values.fold<double>(0, (sum, value) => sum + value!);
    expect(
      frozen.nutrients[nutrient],
      expected,
      reason:
          'Closed observation must match accepted immutable ${nutrient.name}.',
    );
  }
  expect(frozen.directNetCarbohydrates, FinalVisionNutrition.netForRows(rows));
  return frozen;
}

void main() {
  for (final fixture in [
    (
      label: 'nonzero',
      calories: 30.0,
      known: true,
      quantity: 2.0,
      expected: 230.0,
    ),
    (label: 'zero', calories: 0.0, known: true, quantity: 2.0, expected: 200.0),
    (
      label: 'unknown',
      calories: 0.0,
      known: false,
      quantity: 2.0,
      expected: null,
    ),
    (
      label: 'source-total-equals-prior-local',
      calories: 30.0,
      known: true,
      quantity: 2.5,
      expected: 240.0,
    ),
  ]) {
    test(
      'partial CAS preserves accepted membership and all nullable nutrients ${fixture.label}',
      () async {
        final p = _PartialCas();
        try {
          await p.init(
            calories: fixture.calories,
            known: fixture.known,
            updatedQuantity: fixture.quantity,
          );
          expect(await _acceptedEvidence(p.f.b), hasLength(3));
          final frozen = await _assertAcceptedProjection(p.f.b);
          expect(frozen.nutrients[FoodNutrient.calories], fixture.expected);
          expect(frozen.nutrients[FoodNutrient.vitaminC], isNull);
          final before = p.f.server.seen.length;
          final repeat = await p.f.eb.run({'nutrition'});
          expect(repeat.completed, isTrue, reason: _describe(repeat));
          expect(repeat.pushed, 0);
          expect(
            p.f.server.seen.length,
            before,
            reason:
                'Derived day projection must not manufacture sibling uploads.',
          );
        } finally {
          await p.close();
        }
      },
    );
  }

  test(
    'explicit reviewed cloud choices normalize accepted evidence and settle without revision churn',
    () async {
      final p = _PartialCas();
      try {
        await p.init();
        final conflicts = await p.ec.conflicts({'nutrition'});
        expect(conflicts, hasLength(2));
        for (final conflict in conflicts) {
          final fresh = (await p.ec.conflicts({
            'nutrition',
          })).singleWhere((row) => row.key == conflict.key);
          final token = await p.ec.conflictToken(fresh);
          await p.ec.resolveConflict(
            fresh.key,
            keepLocal: false,
            expectedToken: token,
          );
        }
        expect(await p.ec.conflicts({'nutrition'}), isEmpty);
        expect(
          (await _assertAcceptedProjection(
            p.c,
          )).nutrients[FoodNutrient.calories],
          230,
        );
        final before = p.f.server.seen.length;
        for (final engine in [p.ec, p.f.ea, p.f.eb, p.ec, p.f.ea, p.f.eb]) {
          final report = await engine.run({'nutrition'});
          expect(report.completed, isTrue, reason: _describe(report));
          expect(
            report.pushed,
            0,
            reason: 'No implicit projection-only CAS writes.',
          );
        }
        expect(p.f.server.seen.length, before);
        for (final db in [p.c, p.f.a, p.f.b]) {
          expect(
            (await _assertAcceptedProjection(
              db,
            )).nutrients[FoodNutrient.calories],
            230,
          );
        }
      } finally {
        await p.close();
      }
    },
  );

  for (final order in ['ordinary-first', 'vision-first']) {
    test(
      'each committed page exposes only its accepted observation then converges $order',
      () async {
        final f = _Fixture(order);
        final d = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: owner,
        );
        try {
          await f.init();
          await LocalDataAccountBoundary(d).bindAuthenticatedOwner(owner);
          final engine = CloudRestoreV2Engine(
            database: d,
            ownerId: owner,
            deviceId: 'paged-observer',
            keyId: 'synthetic-key',
            cipher: const _TransparentTestCipher(),
            transport: f.server,
            ownerIsCurrent: () => true,
            pageSize: 1,
            maximumPages: 1,
          );
          var complete = false, partialClosed = false;
          for (var page = 0; page < 12; page++) {
            final report = await engine.run({'nutrition'});
            expect(report.conflicts, 0, reason: _describe(report));
            expect(report.pending, 0, reason: _describe(report));
            final log = await DailyLogRepository(d).getForDay(day);
            if (log?.lifecycleState == 'closed') {
              await _assertAcceptedProjection(d);
              if (!report.completed) {
                expect(report.reason, 'page_limit');
                partialClosed = true;
              }
            }
            if (report.completed) {
              complete = true;
              break;
            }
            expect(report.reason, 'page_limit');
          }
          expect(complete, isTrue);
          expect(
            partialClosed,
            isTrue,
            reason:
                'This proves a partial local observation, not complete source membership.',
          );
          expect(
            (await _assertAcceptedProjection(
              d,
            )).nutrients[FoodNutrient.calories],
            180,
          );
          expect(await _acceptedEvidence(d), hasLength(2));
          final repeat = await engine.run({'nutrition'});
          expect(repeat.completed, isTrue, reason: _describe(repeat));
          expect(repeat.pushed, 0);
        } finally {
          await d.close();
          await f.close();
        }
      },
    );
  }

  for (final net in <double?>[0, null]) {
    test(
      'remote accepted projection preserves direct Gemini net and sparse zero/null $net',
      () async {
        final a = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: owner,
        );
        final b = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: owner,
        );
        final server = _ModelServer();
        try {
          for (final db in [a, b]) {
            await LocalDataAccountBoundary(db).bindAuthenticatedOwner(owner);
          }
          await DailyLogRepository(a).startDay(day);
          await seedGemini(a, net);
          await DailyLogRepository(a).closeDay(day);
          expect(
            (await _engine(a, server, 'a').run({'nutrition'})).completed,
            isTrue,
          );
          final report = await _engine(b, server, 'b').run({'nutrition'});
          expect(report.completed, isTrue, reason: _describe(report));
          final frozen = await _assertAcceptedProjection(b);
          expect(frozen.directNetCarbohydrates, net);
          expect(frozen.nutrients[FoodNutrient.sugar], 0);
          expect(frozen.nutrients[FoodNutrient.sodium], 0);
          expect(frozen.nutrients[FoodNutrient.vitaminC], isNull);
        } finally {
          await a.close();
          await b.close();
        }
      },
    );
  }

  test(
    'local freeze survives read; corrupt stage fails closed; valid ack and catalog refresh preserve freeze',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      final server = _ModelServer();
      try {
        await LocalDataAccountBoundary(db).bindAuthenticatedOwner(owner);
        await DailyLogRepository(db).startDay(day);
        await seedGemini(db, 16.9);
        await DailyLogRepository(db).closeDay(day);
        final original = (await DailyLogRepository(db).getForDay(day))!;
        // Deliberately emulate out-of-band item tamper under the existing closed
        // local freeze contract; this is not an authorized user editing route.
        final item = (await db.select(db.mealItems).get()).single;
        await (db.update(db.mealItems)..where((r) => r.id.equals(item.id)))
            .write(const MealItemsCompanion(quantity: Value(50)));
        expect((await DailyLogRepository(db).readLedger(day)).calories, 160);
        final engine = _engine(db, server, 'local');
        final corruptStage = await engine.run({'nutrition'});
        expect(
          corruptStage.completed,
          isFalse,
          reason: _describe(corruptStage),
        );
        expect(corruptStage.reason, 'payload_invalid_or_key_missing');
        expect(corruptStage.pushed, 0);
        expect(corruptStage.applied, 0);
        expect(corruptStage.pending, 0);
        expect(corruptStage.conflicts, 0);
        expect(server.seen, isEmpty);
        expect(server.records, isEmpty);
        expect(server.receipts, isEmpty);
        final afterRejected = (await DailyLogRepository(db).getForDay(day))!;
        expect(
          afterRejected.finalVisionNutrientEvidenceJson,
          original.finalVisionNutrientEvidenceJson,
        );
        expect(afterRejected.closedAt, original.closedAt);
        expect(
          (await db.select(db.mealItems).get()).single.quantity,
          50,
          reason:
              'Rejected staging must not repair or rewrite the corrupt item.',
        );

        // Repair only this intentional negative fixture to its exact captured
        // valid preimage, then exercise normal successful staging/acknowledgment.
        await (db.update(db.mealItems)..where((r) => r.id.equals(item.id)))
            .write(item.toCompanion(false).copyWith(id: const Value.absent()));
        expect((await db.select(db.mealItems).get()).single, item);
        final stageAndAck = await engine.run({'nutrition'});
        expect(stageAndAck.completed, isTrue, reason: _describe(stageAndAck));
        expect(stageAndAck.pending, 0);
        expect(stageAndAck.conflicts, 0);
        expect(server.seen, isNotEmpty);
        final food = (await engine.codec.capture(
          scopes: {'nutrition'},
        )).singleWhere((snapshot) => snapshot.type == 'food');
        final wireFood = Map<String, Object?>.from(food.data['food']! as Map);
        // A valid catalog metadata refresh does not rewrite immutable meal-item
        // evidence or the previously frozen local day observation.
        await engine.codec.apply(
          CloudNutritionSnapshot(
            scope: food.scope,
            type: food.type,
            id: food.id,
            deleted: false,
            data: {
              ...food.data,
              'food': {
                ...wireFood,
                'revision': (wireFood['revision']! as int) + 1,
                'updatedAt': DateTime.now().toUtc().toIso8601String(),
              },
            },
          ),
        );
        expect((await db.select(db.mealItems).get()).single, item);
        for (var i = 0; i < 2; i++) {
          expect((await DailyLogRepository(db).readLedger(day)).calories, 160);
        }
        final after = (await DailyLogRepository(db).getForDay(day))!;
        expect(
          after.finalVisionNutrientEvidenceJson,
          original.finalVisionNutrientEvidenceJson,
        );
        expect(after.closedAt, original.closedAt);
      } finally {
        await db.close();
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
        if (fingerprints[id] != fp) {
          throw StateError('idempotency collision');
        }
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
