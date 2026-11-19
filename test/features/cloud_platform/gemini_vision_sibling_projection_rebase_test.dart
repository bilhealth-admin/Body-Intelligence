import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/final_vision_nutrition.dart';
import 'package:body_intelligence_log/data/database/vision_estimate_evidence.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
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
    if (hold != null && !hold!.release.isCompleted) hold!.release.complete();
    await a.close();
    await b.close();
  }
}

void main() {
  for (final order in ['ordinary-first', 'vision-first']) {
    test(
      'all tombstones open then empty close converge without sibling conflict $order',
      () async {
        final f = _Fixture(order);
        try {
          await f.init();
          await DailyLogRepository(f.a).reopenDay(day);
          for (final meal in await f.a.select(f.a.meals).get()) {
            await MealRepository(f.a).deleteMealCascade(meal.id);
          }
          final open = await f.transfer();
          expect(open.completed, isTrue, reason: _describe(open));
          expect(open.conflicts, 0);
          expect(open.pending, 0);
          expect(
            (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
            'open',
          );
          await DailyLogRepository(f.a).closeDay(day);
          final closed = await f.transfer();
          expect(closed.completed, isTrue, reason: _describe(closed));
          expect(closed.conflicts, 0);
          expect(closed.pending, 0);
          final log = (await DailyLogRepository(f.b).getForDay(day))!;
          expect(log.lifecycleState, 'closed');
          final frozen = FinalVisionNutrition.decode(
            log.finalVisionNutrientEvidenceJson!,
          );
          expect(frozen.nutrients.values, everyElement(isNull));
          expect(frozen.directNetCarbohydrates, isNull);
          expect(
            (await f.b.select(f.b.meals).get()).every(
              (row) => row.deletedAt != null,
            ),
            isTrue,
          );
          final repeat = await f.eb.run({'nutrition'});
          expect(repeat.completed, isTrue, reason: _describe(repeat));
          expect(repeat.pushed, 0);
        } finally {
          await f.close();
        }
      },
    );
    test(
      'last Vision item removal and ordinary close converge in either incoming order $order',
      () async {
        final f = _Fixture(order);
        try {
          await f.init();
          await DailyLogRepository(f.a).reopenDay(day);
          await MealRepository(
            f.a,
          ).deleteMealItem((await f.visionItem(f.a)).id);
          await DailyLogRepository(f.a).closeDay(day);
          final report = await f.transfer();
          expect(report.completed, isTrue, reason: _describe(report));
          expect(report.conflicts, 0);
          expect(report.pending, 0);
          final log = (await DailyLogRepository(f.b).getForDay(day))!;
          final frozen = FinalVisionNutrition.decode(
            log.finalVisionNutrientEvidenceJson!,
          );
          expect(frozen.nutrients[FoodNutrient.calories], 20);
          expect(frozen.nutrients[FoodNutrient.carbohydrates], 5);
          expect(frozen.nutrients[FoodNutrient.vitaminA], isNull);
          expect(frozen.directNetCarbohydrates, isNull);
          expect((await f.visionItem(f.b)).deletedAt, isNotNull);
        } finally {
          await f.close();
        }
      },
    );
  }
  for (final edit in ['content', 'quantity', 'tombstone']) {
    test(
      'local sibling $edit pending before pull remains conflict and preserves its rows',
      () async {
        final f = _Fixture('ordinary-first');
        try {
          await f.init();
          await DailyLogRepository(f.b).reopenDay(day);
          final local = await f.visionItem(f.b);
          if (edit == 'content') {
            await MealRepository(f.b).duplicateMealItem(local.id);
          } else if (edit == 'quantity') {
            await MealRepository(
              f.b,
            ).updateMealItem(id: local.id, quantity: 50);
          } else {
            await MealRepository(f.b).deleteMealCascade(local.mealId);
          }
          final before = jsonEncode(
            (await f.b.select(f.b.mealItems).get())
                .map((row) => row.toJson())
                .toList(),
          );
          await DailyLogRepository(f.a).reopenDay(day);
          await MealRepository(
            f.a,
          ).updateMealItem(id: (await f.ordinaryItem(f.a)).id, quantity: 2);
          await DailyLogRepository(f.a).closeDay(day);
          final report = await f.transfer();
          expect(report.conflicts, greaterThan(0), reason: _describe(report));
          expect(
            (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
            'open',
          );
          expect(
            jsonEncode(
              (await f.b.select(f.b.mealItems).get())
                  .map((row) => row.toJson())
                  .toList(),
            ),
            before,
          );
          expect(
            (await f.eb.journal.entries(
              'nutrition',
            )).any((row) => row.conflict != null),
            isTrue,
          );
        } finally {
          await f.close();
        }
      },
    );
  }
  test(
    'real UI write started after validation before meal apply waits for SQL tx and survives incoming close',
    () async {
      final hold = _UpdateHold();
      final f = _Fixture('ordinary-first', hold: hold);
      try {
        await f.init();
        final itemId = (await f.visionItem(f.b)).id;
        await DailyLogRepository(f.a).reopenDay(day);
        await MealRepository(
          f.a,
        ).updateMealItem(id: (await f.ordinaryItem(f.a)).id, quantity: 2);
        await DailyLogRepository(f.a).closeDay(day);
        expect((await f.ea.run({'nutrition'})).completed, isTrue);
        hold.armed = true;
        final pull = f.eb.run({'nutrition'});
        await hold.entered.future.timeout(const Duration(seconds: 3));
        expect(hold.insideTransaction, isTrue);
        var userWriteFinished = false;
        final userWrite = () async {
          await DailyLogRepository(f.b).reopenDay(day);
          await MealRepository(f.b).updateMealItem(id: itemId, quantity: 50);
          userWriteFinished = true;
        }();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          userWriteFinished,
          isFalse,
          reason:
              'Outer-zone UI SQL must wait while restore owns its transaction.',
        );
        hold.release.complete();
        final report = await pull;
        await userWrite;
        expect(report.reason, isNull, reason: _describe(report));
        expect(report.conflicts, 0, reason: _describe(report));
        expect(userWriteFinished, isTrue);
        expect(
          (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
          'open',
        );
        expect((await f.visionItem(f.b)).quantity, 50);
        expect((await f.ordinaryItem(f.b)).quantity, 2);
        expect((await DailyLogRepository(f.b).readLedger(day)).calories, 120);
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
