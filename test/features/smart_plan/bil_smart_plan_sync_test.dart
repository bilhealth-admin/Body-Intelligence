import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/smart_plan/data/bil_smart_plan_repository.dart';
import 'package:body_intelligence_log/features/smart_plan/data/bil_smart_plan_sync.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'bil_smart_plan_engine_test.dart' show buildRequest;

class _Cloud implements BilSmartPlanRemote {
  BilSmartPlanRemoteState state = const BilSmartPlanRemoteState(0, null);
  Future<void> Function()? beforeRead;
  bool acknowledgeWithoutPersisting = false;
  int reads = 0, writes = 0;
  @override
  Future<BilSmartPlanRemoteState> read() async {
    reads++;
    await beforeRead?.call();
    return state;
  }

  @override
  Future<BilSmartPlanRemoteState> compareAndSwap(
    int revision,
    String? plan,
  ) async {
    writes++;
    if (state.revision != revision) throw StateError('remote_conflict');
    if (acknowledgeWithoutPersisting) {
      return BilSmartPlanRemoteState(revision + 1, plan);
    }
    return state = BilSmartPlanRemoteState(revision + 1, plan);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase a, b;
  late BilSmartPlanRepository localA, localB;
  late BilSmartPlanSync syncA, syncB;
  late _Cloud cloud;
  bool consent = true;
  final now = DateTime(2026, 10, 22);
  setUp(() {
    consent = true;
    a = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-123',
    );
    b = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'owner-123',
    );
    cloud = _Cloud();
    localA = BilSmartPlanRepository(
      preferences: PreferencesRepository(a),
      currentOwnerId: () => 'owner-123',
    );
    localB = BilSmartPlanRepository(
      preferences: PreferencesRepository(b),
      currentOwnerId: () => 'owner-123',
    );
    void check() {
      if (!consent) throw StateError('consent_revoked');
    }

    syncA = BilSmartPlanSync(
      local: localA,
      preferences: localA.preferences,
      remote: cloud,
      checkConsentAndAccess: check,
    );
    syncB = BilSmartPlanSync(
      local: localB,
      preferences: localB.preferences,
      remote: cloud,
      checkConsentAndAccess: check,
    );
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });
  Future<void> seed() async {
    await localA.save(
      const BilSmartPlanEngine().generate(buildRequest(), now),
      expectedRevision: 0,
    );
    await syncA.synchronize('owner-123');
    await syncB.synchronize('owner-123');
  }

  test(
    'real HTTP409 adapter opens review after exactly one request instead of retrying or acknowledging a write',
    () async {
      var calls = 0;
      final client = SupabaseClient(
        'https://fixture.invalid',
        'fixture-key',
        httpClient: MockClient((request) async {
          calls++;
          expect(request.url.path, '/rest/v1/rpc/bil_smart_plan_cas_v1');
          expect(jsonDecode(request.body)['expected_revision'], 7);
          return http.Response(
            jsonEncode({
              'code': 'PT409',
              'message': 'smart_plan_revision_conflict',
            }),
            409,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseSmartPlanRemote(client).compareAndSwap(7, null),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'reviewable conflict',
            'smart_plan_sync_conflict',
          ),
        ),
      );
      expect(calls, 1);
    },
  );

  test(
    'two devices upload, restore and reconnect without duplicate cloud revisions',
    () async {
      await seed();
      expect(
        (await localA.readFor('owner-123'))!.encode(),
        (await localB.readFor('owner-123'))!.encode(),
      );
      await syncA.synchronize('owner-123');
      await syncB.synchronize('owner-123');
      expect(cloud.state.revision, 1);
    },
  );
  test(
    'two independent edits conflict instead of silently overwriting',
    () async {
      await seed();
      final planA = (await localA.readFor('owner-123'))!;
      final planB = (await localB.readFor('owner-123'))!;
      await localA.save(
        planA.withStatus(BilPlanStatus.active, now),
        expectedRevision: 1,
      );
      final other = planB
          .withStatus(BilPlanStatus.active, now)
          .withStatus(BilPlanStatus.paused, now);
      // Save each revision through the local CAS contract.
      await localB.save(
        planB.withStatus(BilPlanStatus.active, now),
        expectedRevision: 1,
      );
      await localB.save(other, expectedRevision: 2);
      await syncA.synchronize('owner-123');
      await expectLater(syncB.synchronize('owner-123'), throwsStateError);
      expect((await localB.readFor('owner-123'))!.status, BilPlanStatus.paused);
      expect(
        BilSmartPlan.decode(cloud.state.plan!).status,
        BilPlanStatus.active,
      );
    },
  );
  test(
    'deletion tombstone propagates and does not resurrect on reconnect',
    () async {
      await seed();
      await localA.removeWithConfirmation(
        owner: 'owner-123',
        expectedId: 'plan-456',
        expectedRevision: 1,
      );
      await syncA.synchronize('owner-123');
      await syncB.synchronize('owner-123');
      expect(await localB.readFor('owner-123'), isNull);
      await syncB.synchronize('owner-123');
      expect(cloud.state.plan, isNull);
      expect(cloud.state.revision, 2);
    },
  );
  test(
    'lost upload checkpoint cannot resurrect an explicitly deleted plan',
    () async {
      final plan = const BilSmartPlanEngine().generate(buildRequest(), now);
      await localA.save(plan, expectedRevision: 0);
      cloud.state = BilSmartPlanRemoteState(1, plan.encode());
      await localA.removeWithConfirmation(
        owner: 'owner-123',
        expectedId: plan.id,
        expectedRevision: 1,
      );
      await expectLater(syncA.synchronize('owner-123'), throwsStateError);
      expect(await localA.readFor('owner-123'), isNull);
      expect(cloud.state.plan, plan.encode());
      expect(
        await localA.preferences.get(localA.deletionKey('owner-123')),
        isNotNull,
      );
    },
  );

  test(
    'deletion intent clears only after the remote tombstone is acknowledged',
    () async {
      await seed();
      await localA.removeWithConfirmation(
        owner: 'owner-123',
        expectedId: 'plan-456',
        expectedRevision: 1,
      );
      expect(
        await localA.preferences.get(localA.deletionKey('owner-123')),
        isNotNull,
      );
      await syncA.synchronize('owner-123');
      expect(cloud.state.plan, isNull);
      expect(
        await localA.preferences.get(localA.deletionKey('owner-123')),
        isNull,
      );
    },
  );

  test(
    'consent revoked while cloud reads cannot restore private data',
    () async {
      await seed();
      await localB.restoreSnapshot(
        owner: 'owner-123',
        expected: cloud.state.plan,
        next: null,
      );
      cloud.beforeRead = () async {
        consent = false;
      };
      await expectLater(syncB.synchronize('owner-123'), throwsStateError);
      expect(await localB.readFor('owner-123'), isNull);
    },
  );
  test('concurrent local edit during cloud await is preserved', () async {
    await seed();
    final barrier = Completer<void>();
    final started = Completer<void>();
    cloud.beforeRead = () async {
      started.complete();
      await barrier.future;
    };
    final inFlight = syncA.synchronize('owner-123');
    await started.future;
    final plan = (await localA.readFor('owner-123'))!;
    await localA.save(
      plan.withStatus(BilPlanStatus.active, now),
      expectedRevision: 1,
    );
    barrier.complete();
    await expectLater(inFlight, throwsStateError);
    expect((await localA.readFor('owner-123'))!.status, BilPlanStatus.active);
  });
  test(
    'a successful write response without actual remote readback fails once and keeps pending data',
    () async {
      final plan = const BilSmartPlanEngine().generate(buildRequest(), now);
      await localA.save(plan, expectedRevision: 0);
      cloud.acknowledgeWithoutPersisting = true;
      await expectLater(syncA.synchronize('owner-123'), throwsStateError);
      expect(cloud.writes, 1);
      expect(cloud.reads, 2);
      expect(cloud.state.revision, 0);
      expect((await localA.readFor('owner-123'))!.encode(), plan.encode());
      expect(
        await localA.preferences.get('bil.smart-plan.sync.owner-123.v1'),
        isNull,
      );
      cloud.acknowledgeWithoutPersisting = false;
      await syncA.synchronize('owner-123');
      expect(cloud.state.plan, plan.encode());
    },
  );
  for (final keepLocal in [true, false]) {
    test(
      'reviewed conflict chooses ${keepLocal ? 'device' : 'cloud'} with both versions retained and verified',
      () async {
        await seed();
        final original = (await localA.readFor('owner-123'))!;
        final active = await localA.save(
          original.withStatus(BilPlanStatus.active, now),
          expectedRevision: 1,
        );
        await syncA.synchronize('owner-123');
        await localB.save(
          original.withStatus(BilPlanStatus.active, now),
          expectedRevision: 1,
        );
        final paused = await localB.save(
          active.withStatus(BilPlanStatus.paused, now),
          expectedRevision: 2,
        );
        await expectLater(syncB.synchronize('owner-123'), throwsStateError);
        final reviewed = await syncB.reviewConflict('owner-123');
        await syncB.resolveConflict(reviewed, keepLocal: keepLocal);
        final selected = keepLocal ? paused : active;
        expect(cloud.state.plan, selected.encode());
        expect(
          (await localB.readFor('owner-123'))!.encode(),
          selected.encode(),
        );
        final retained =
            jsonDecode(
                  (await localB.preferences.get(
                    syncB.conflictHistoryKey('owner-123'),
                  ))!,
                )
                as List;
        expect(retained.single['local'], paused.encode());
        expect(retained.single['cloud'], active.encode());
        final revision = cloud.state.revision;
        await syncB.synchronize('owner-123');
        expect(cloud.state.revision, revision);
        expect(await b.select(b.dailyLogs).get(), isEmpty);
      },
    );
  }
  test(
    'changes after conflict review and revoked consent cannot be committed',
    () async {
      await seed();
      final reviewed = await syncA.reviewConflict('owner-123');
      final original = (await localA.readFor('owner-123'))!;
      await localA.save(
        original.withStatus(BilPlanStatus.active, now),
        expectedRevision: 1,
      );
      await expectLater(
        syncA.resolveConflict(reviewed, keepLocal: false),
        throwsStateError,
      );
      expect((await localA.readFor('owner-123'))!.status, BilPlanStatus.active);
      final latest = await syncA.reviewConflict('owner-123');
      consent = false;
      await expectLater(
        syncA.resolveConflict(latest, keepLocal: true),
        throwsStateError,
      );
      expect(
        BilSmartPlan.decode(cloud.state.plan!).status,
        BilPlanStatus.draft,
      );
    },
  );
}
