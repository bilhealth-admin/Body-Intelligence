import 'dart:convert';
import 'package:body_intelligence_log/data/database/app_database.dart';
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
  Future<void> init() async {
    for (final db in [a, b]) {
      await LocalDataAccountBoundary(db).bindAuthenticatedOwner(owner);
    }
    await DailyLogRepository(a).startDay(day);
    await seedGemini(a, 16.9);
    await DailyLogRepository(a).closeDay(day);
    expect((await ea.run({'nutrition'})).completed, isTrue);
    expect((await eb.run({'nutrition'})).completed, isTrue);
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
  Future<void> close() async {
    await a.close();
    await b.close();
  }
}

void main() {
  test(
    'actual engine propagates explicit reopen and later meal edit without retaining closed nutrition',
    () async {
      final f = _Fixture();
      try {
        await f.init();
        final before = (await DailyLogRepository(f.b).getForDay(day))!;
        expect(before.lifecycleState, 'closed');
        expect((await DailyLogRepository(f.b).readLedger(day)).calories, 160);
        await DailyLogRepository(f.a).reopenDay(day);
        expect((await f.ea.run({'nutrition'})).completed, isTrue);
        expect((await f.eb.run({'nutrition'})).completed, isTrue);
        final reopened = (await DailyLogRepository(f.b).getForDay(day))!;
        expect(reopened.lifecycleState, 'open');
        expect(reopened.closedAt, isNull);
        expect(
          reopened.finalVisionNutrientEvidenceJson,
          before.finalVisionNutrientEvidenceJson,
        );
        await f.snack();
        expect((await f.ea.run({'nutrition'})).completed, isTrue);
        expect((await f.eb.run({'nutrition'})).completed, isTrue);
        expect((await DailyLogRepository(f.b).readLedger(day)).calories, 180);
        expect(
          (await DailyLogRepository(f.b).readLedger(day)).netCarbohydrates,
          isNull,
        );
      } finally {
        await f.close();
      }
    },
  );
  test(
    'new closed snapshot can follow a known reopened lineage after parent server CAS',
    () async {
      final f = _Fixture();
      try {
        await f.init();
        await DailyLogRepository(f.a).reopenDay(day);
        await f.snack();
        await DailyLogRepository(f.a).closeDay(day);
        expect((await f.ea.run({'nutrition'})).completed, isTrue);
        expect((await f.eb.run({'nutrition'})).completed, isTrue);
        final restored = (await DailyLogRepository(f.b).getForDay(day))!;
        expect(restored.lifecycleState, 'closed');
        expect((await DailyLogRepository(f.b).readLedger(day)).calories, 180);
        expect(
          (await DailyLogRepository(f.b).readLedger(day)).netCarbohydrates,
          isNull,
        );
      } finally {
        await f.close();
      }
    },
  );
  test(
    'existing engine ignores delayed old close and reopen revisions instead of using device clocks',
    () async {
      final f = _Fixture();
      try {
        await f.init();
        final oldClose = Map<String, Object?>.from(
          f.server.records.values.firstWhere((r) => r['record_type'] == 'meal'),
        );
        await DailyLogRepository(f.a).reopenDay(day);
        expect((await f.ea.run({'nutrition'})).completed, isTrue);
        expect((await f.eb.run({'nutrition'})).completed, isTrue);
        final oldOpen = Map<String, Object?>.from(
          f.server.records.values.firstWhere((r) => r['record_type'] == 'meal'),
        );
        f.server.delay(oldClose);
        expect((await f.eb.run({'nutrition'})).completed, isTrue);
        expect(
          (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
          'open',
        );
        await f.snack();
        await DailyLogRepository(f.a).closeDay(day);
        expect((await f.ea.run({'nutrition'})).completed, isTrue);
        expect((await f.eb.run({'nutrition'})).completed, isTrue);
        f.server.delay(oldOpen);
        expect((await f.eb.run({'nutrition'})).completed, isTrue);
        expect(
          (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
          'closed',
        );
        expect((await DailyLogRepository(f.b).readLedger(day)).calories, 180);
      } finally {
        await f.close();
      }
    },
  );
  test(
    'local reopen versus remote reclose stays an existing durable conflict until reviewed',
    () async {
      final f = _Fixture();
      try {
        await f.init();
        await DailyLogRepository(f.b).reopenDay(day);
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
        final conflict = (await f.eb.conflicts({
          'nutrition',
        })).firstWhere((r) => r.type == 'meal');
        final token = await f.eb.conflictToken(conflict);
        await f.eb.resolveConflict(
          conflict.key,
          keepLocal: false,
          expectedToken: token,
        );
        expect(
          (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
          'closed',
        );
        expect((await f.eb.journal.entry(conflict.key))!.recovery, isNotNull);
      } finally {
        await f.close();
      }
    },
  );
  test('legacy attachment absence is no lifecycle instruction', () async {
    final f = _Fixture();
    try {
      await f.init();
      final codec = CloudNutritionSnapshotCodec(
        f.a,
        ownerId: owner,
        ownerIsCurrent: () => true,
      );
      final old = (await codec.capture(
        scopes: {'nutrition'},
      )).firstWhere((s) => s.type == 'meal');
      final data = Map<String, Object?>.from(old.data)
        ..remove('visionDayLifecycle')
        ..remove('closedVisionDay');
      await CloudNutritionSnapshotCodec(
        f.b,
        ownerId: owner,
        ownerIsCurrent: () => true,
      ).apply(
        CloudNutritionSnapshot(
          scope: old.scope,
          type: old.type,
          id: old.id,
          deleted: old.deleted,
          data: data,
        ),
      );
      expect(
        (await DailyLogRepository(f.b).getForDay(day))!.lifecycleState,
        'closed',
      );
    } finally {
      await f.close();
    }
  });

  test(
    'remote new sibling cannot reclose a locally reopened day before its conflict is reviewed',
    () async {
      final f = _Fixture();
      try {
        await f.init();
        await DailyLogRepository(f.b).reopenDay(day);
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
          (await f.b.select(f.b.meals).get()).where((m) => m.type == 'snack'),
          isEmpty,
        );
      } finally {
        await f.close();
      }
    },
  );
  test(
    'typed lifecycle changes only nutrition fields and keeps local private day context',
    () async {
      final f = _Fixture();
      try {
        await f.init();
        await DailyLogRepository(f.b).save(
          date: day,
          notes: 'Synthetic local note',
          sleepHours: 7,
          steps: 123,
          exerciseNotes: 'Synthetic local activity',
        );
        await DailyLogRepository(f.a).reopenDay(day);
        expect((await f.ea.run({'nutrition'})).completed, isTrue);
        expect((await f.eb.run({'nutrition'})).completed, isTrue);
        final actual = (await DailyLogRepository(f.b).getForDay(day))!;
        expect(actual.lifecycleState, 'open');
        expect(actual.notes, 'Synthetic local note');
        expect(actual.sleepHours, 7);
        expect(actual.steps, 123);
        expect(actual.exerciseNotes, 'Synthetic local activity');
        final payload = (await CloudNutritionSnapshotCodec(
          f.a,
          ownerId: owner,
          ownerIsCurrent: () => true,
        ).capture(scopes: {'nutrition'})).firstWhere((s) => s.type == 'meal');
        final encoded = jsonEncode(payload.toJson());
        expect(encoded, isNot(contains('Synthetic local note')));
        expect(encoded, isNot(contains('exerciseNotes')));
      } finally {
        await f.close();
      }
    },
  );
  test(
    'legacy closed-only attachment still restores with its strict existing binding',
    () async {
      final f = _Fixture();
      final fresh = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      try {
        await f.init();
        await LocalDataAccountBoundary(fresh).bindAuthenticatedOwner(owner);
        final old = (await CloudNutritionSnapshotCodec(
          f.a,
          ownerId: owner,
          ownerIsCurrent: () => true,
        ).capture(scopes: {'nutrition'})).firstWhere((s) => s.type == 'meal');
        final data = Map<String, Object?>.from(old.data);
        final lifecycle = data.remove('visionDayLifecycle');
        if (lifecycle is Map) {
          data['closedVisionDay'] = lifecycle['lastClosedSnapshot'];
        }
        await CloudNutritionSnapshotCodec(
          fresh,
          ownerId: owner,
          ownerIsCurrent: () => true,
        ).apply(
          CloudNutritionSnapshot(
            scope: old.scope,
            type: old.type,
            id: old.id,
            deleted: false,
            data: data,
          ),
        );
        expect(
          (await DailyLogRepository(fresh).getForDay(day))!.lifecycleState,
          'closed',
        );
        expect((await DailyLogRepository(fresh).readLedger(day)).calories, 160);
      } finally {
        await fresh.close();
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
