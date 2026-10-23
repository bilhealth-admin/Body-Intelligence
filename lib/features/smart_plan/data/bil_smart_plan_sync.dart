import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/preferences_repository.dart';
import '../domain/bil_smart_plan.dart';
import 'bil_smart_plan_repository.dart';
part 'bil_smart_plan_sync_conflict.dart';

class BilSmartPlanRemoteState {
  const BilSmartPlanRemoteState(this.revision, this.plan);
  final int revision;
  final String? plan; // null is a durable deletion, never absence of evidence.
}

abstract interface class BilSmartPlanRemote {
  Future<BilSmartPlanRemoteState> read();
  Future<BilSmartPlanRemoteState> compareAndSwap(int revision, String? plan);
}

/// No service-role credentials or caller-supplied owner IDs. The RPC derives
/// the owner from auth.uid(). This adapter is staged, never deployed by app code.
class SupabaseSmartPlanRemote implements BilSmartPlanRemote {
  SupabaseSmartPlanRemote(this.client);
  final SupabaseClient client;
  BilSmartPlanRemoteState _decode(Object? value) {
    if (value is! Map ||
        value['revision'] is! int ||
        value['revision'] as int < 0) {
      throw const FormatException('smart_plan_remote_state');
    }
    final payload = value['payload'];
    return BilSmartPlanRemoteState(
      value['revision'] as int,
      payload == null
          ? null
          : BilSmartPlan.decode(jsonEncode(payload)).encode(),
    );
  }

  @override
  Future<BilSmartPlanRemoteState> read() async =>
      _decode(await client.rpc('bil_smart_plan_read_v1'));
  @override
  Future<BilSmartPlanRemoteState> compareAndSwap(
    int revision,
    String? plan,
  ) async {
    try {
      return _decode(
        await client.rpc(
          'bil_smart_plan_cas_v1',
          params: {
            'expected_revision': revision,
            'next_payload': plan == null ? null : jsonDecode(plan),
          },
        ),
      );
    } on PostgrestException catch (error) {
      if (error.code == 'PT409') {
        throw StateError('smart_plan_sync_conflict');
      }
      rethrow;
    }
  }
}

/// A true three-way merge boundary. Changes on both devices require a human
/// choice; timestamps never authorize last-writer-wins over health records.
class BilSmartPlanSync {
  BilSmartPlanSync({
    required this.local,
    required this.preferences,
    required this.remote,
    required this.checkConsentAndAccess,
  });
  final BilSmartPlanRepository local;
  final PreferencesRepository preferences;
  final BilSmartPlanRemote remote;
  final void Function() checkConsentAndAccess;

  Future<void> synchronize(String owner) async {
    void check() {
      checkConsentAndAccess();
      if (preferences.localOwnerId != owner ||
          local.currentOwnerId() != owner) {
        throw StateError('smart_plan_owner_changed');
      }
    }

    check();
    final before = (await local.readFor(owner))?.encode();
    check();
    final deletionKey = local.deletionKey(owner);
    final deletionIntent = await preferences.get(deletionKey);
    check();
    final key = 'bil.smart-plan.sync.$owner.v1';
    final checkpointRaw = await preferences.get(key);
    check();
    final checkpoint = checkpointRaw == null
        ? null
        : jsonDecode(checkpointRaw) as Map;
    final cloud = await remote.read();
    check();
    if (await preferences.get(deletionKey) != deletionIntent) {
      throw StateError('smart_plan_local_changed_during_sync');
    }
    check();
    if (cloud.plan != null &&
        BilSmartPlan.decode(cloud.plan!).ownerId != owner) {
      throw StateError('smart_plan_foreign_owner');
    }
    if ((await local.readFor(owner))?.encode() != before) {
      throw StateError('smart_plan_local_changed_during_sync');
    }
    check();
    final baseline = checkpoint?['plan'] as String?;
    // A lost checkpoint must never turn an explicit local deletion into a
    // cloud restore. Unknown concurrent cloud content requires human review.
    final localChanged =
        before != baseline || (before == null && deletionIntent != null);
    final remoteChanged = cloud.plan != baseline;
    if (localChanged && remoteChanged && cloud.plan != before) {
      throw StateError('smart_plan_sync_conflict');
    }
    var accepted = cloud;
    if (localChanged && cloud.plan != before) {
      accepted = await remote.compareAndSwap(cloud.revision, before);
      check();
      if (accepted.revision != cloud.revision + 1 || accepted.plan != before) {
        throw StateError('smart_plan_sync_unverified');
      }
      final readback = await remote.read();
      check();
      if (readback.revision != accepted.revision || readback.plan != before) {
        throw StateError('smart_plan_sync_unverified');
      }
    } else if (remoteChanged && cloud.plan != before) {
      await local.restoreSnapshot(
        owner: owner,
        expected: before,
        next: cloud.plan,
      );
      check();
    }
    if ((await local.readFor(owner))?.encode() != accepted.plan) {
      throw StateError('smart_plan_local_changed_during_sync');
    }
    check();
    final savedRaw = await preferences.get(local.storageKey(owner));
    check();
    if ((savedRaw == null || savedRaw.isEmpty
            ? null
            : BilSmartPlan.decode(savedRaw).encode()) !=
        accepted.plan) {
      throw StateError('smart_plan_local_changed_during_sync');
    }
    final success = await preferences.mutateIfUnchanged(
      expected: {
        key: checkpointRaw,
        local.storageKey(owner): savedRaw,
        deletionKey: deletionIntent,
      },
      set: {
        key: jsonEncode({'revision': accepted.revision, 'plan': accepted.plan}),
      },
      remove: [deletionKey],
      isCurrent: () {
        check();
        return true;
      },
    );
    if (!success) throw StateError('smart_plan_local_changed_during_sync');
    check();
  }
}
