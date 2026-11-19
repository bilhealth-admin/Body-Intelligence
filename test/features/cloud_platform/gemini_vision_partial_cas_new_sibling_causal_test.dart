import 'package:flutter/foundation.dart' as diagnostics;
import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
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
  test(
    'partial CAS new sibling cannot publish closed totals inconsistent with accepted live rows',
    () async {
      final f = _Fixture('ordinary-first');
      final c = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      try {
        await f.init();
        await LocalDataAccountBoundary(c).bindAuthenticatedOwner(owner);
        final ec = _engine(c, f.server, 'c');
        final initialC = await ec.run({'nutrition'});
        expect(initialC.completed, isTrue, reason: _describe(initialC));
        final oldCTotal = (await DailyLogRepository(
          c,
        ).readLedger(day)).calories;
        expect(oldCTotal, 180);
        final oldParentRoles = {
          for (final meal in await c.select(c.meals).get())
            meal.uuid: meal.type,
        };

        // A/B advance to L2 while C remains offline on its actual L1 baseline.
        await DailyLogRepository(f.a).reopenDay(day);
        await MealRepository(
          f.a,
        ).updateMealItem(id: (await f.ordinaryItem(f.a)).id, quantity: 2);
        await DailyLogRepository(f.a).closeDay(day);
        final currentB = await f.transfer();
        expect(currentB.completed, isTrue, reason: _describe(currentB));
        expect((await DailyLogRepository(f.b).readLedger(day)).calories, 200);

        // C makes a genuine new parent from the stale local view. No replay,
        // revision/clock manipulation or direct cloud-row mutation is used.
        await DailyLogRepository(c).reopenDay(day);
        await MealRepository(c).addQuickMacroEntry(
          date: day,
          mealType: 'breakfast',
          calories: 30,
          protein: 0,
          carbohydrates: 7.5,
          fat: 0,
          caloriesKnown: true,
          proteinKnown: true,
          carbohydratesKnown: true,
          fatKnown: true,
        );
        await DailyLogRepository(c).closeDay(day);
        expect((await DailyLogRepository(c).readLedger(day)).calories, 210);
        final newParent = (await c.select(c.meals).get()).singleWhere(
          (m) => m.type == 'breakfast',
        );
        final before = f.server.seen.length;
        final cResult = await ec.run({'nutrition'});
        final parentReceipts = <Map<String, Object?>>[
          for (final operation
              in f.server.seen
                  .skip(before)
                  .where((op) => op['record_type'] == 'meal'))
            {
              'parent': operation['record_id'] == newParent.uuid
                  ? 'new-breakfast'
                  : 'existing-${oldParentRoles[operation['record_id']]}',
              'expected_revision': operation['expected_revision'],
              'mutation': operation['mutation'],
              'outcome':
                  f.server.receipts[operation['operation_id']]?['outcome'],
              'server_revision': f
                  .server
                  .receipts[operation['operation_id']]?['server_revision'],
            },
        ];
        expect(cResult.conflicts, greaterThan(0), reason: _describe(cResult));
        final oldReceipts = parentReceipts
            .where((r) => (r['parent']! as String).startsWith('existing-'))
            .toList();
        expect(oldReceipts.length, greaterThanOrEqualTo(2));
        expect(oldReceipts.map((r) => r['outcome']), everyElement('conflict'));
        final acceptedNew = parentReceipts
            .where((r) => r['parent'] == 'new-breakfast')
            .toList();
        expect(acceptedNew, hasLength(1));
        expect(acceptedNew.single['expected_revision'], 0);
        expect(acceptedNew.single['outcome'], 'accepted');

        final observer = await f.eb.run({'nutrition'});
        final log = (await DailyLogRepository(f.b).getForDay(day))!;
        final ledger = await DailyLogRepository(f.b).readLedger(day);
        final liveMeals = (await f.b.select(f.b.meals).get())
            .where((m) => m.deletedAt == null)
            .map((m) => m.id)
            .toSet();
        final liveItems = (await f.b.select(f.b.mealItems).get())
            .where(
              (item) =>
                  item.deletedAt == null && liveMeals.contains(item.mealId),
            )
            .toList();
        final evidence = liveItems
            .map(
              (item) => MealFoodEvidence.read(
                item,
                ownerKey: LocalDatabaseScope.keyForOwner(owner),
              ),
            )
            .toList();
        final calories = evidence
            .map((row) => row.fullValue(FoodNutrient.calories))
            .toList();
        expect(calories, everyElement(isNotNull));
        final liveCalories = calories.fold<double>(
          0,
          (sum, value) => sum + value!,
        );
        // Diagnostic projections are synthetic fixture numbers/parent roles only;
        // no raw ID, user data, encrypted payload or credentials are printed.
        diagnostics.debugPrint(
          jsonEncode({
            'case': 'partial_cas_new_sibling',
            'old_C_closed': oldCTotal,
            'C_parent_receipts': parentReceipts,
            'C_report': _describe(cResult),
            'B_report': _describe(observer),
            'B_day_state': log.lifecycleState,
            'B_closed_or_open_ledger': ledger.calories,
            'B_live_evidence_calories': liveCalories,
          }),
        );
        // A safe durable conflict/deferral is allowed. A completed or partial
        // restore must never display closed totals inconsistent with its rows.
        expect(
          ledger.calories,
          closeTo(liveCalories, 1e-8),
          reason:
              'Accepted new-parent metadata must not freeze an older sibling view over newer accepted rows. ${_describe(observer)}',
        );
      } finally {
        await c.close();
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
