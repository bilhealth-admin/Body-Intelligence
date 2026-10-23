part of 'bil_smart_plan_sync.dart';

final class BilSmartPlanSyncConflict {
  const BilSmartPlanSyncConflict._(
    this.owner,
    this.localPlan,
    this.cloud,
    this.localRaw,
    this.checkpoint,
    this.deletion,
  );
  final String owner;
  final String? localPlan, localRaw, checkpoint, deletion;
  final BilSmartPlanRemoteState cloud;
}

extension BilSmartPlanConflictResolution on BilSmartPlanSync {
  String conflictHistoryKey(String owner) =>
      'bil.smart-plan.conflicts.$owner.v1';
  void _checkConflictAccess(String owner) {
    checkConsentAndAccess();
    if (preferences.localOwnerId != owner || local.currentOwnerId() != owner) {
      throw StateError('smart_plan_owner_changed');
    }
  }

  Future<BilSmartPlanSyncConflict> reviewConflict(String owner) async {
    _checkConflictAccess(owner);
    final localRaw = await preferences.get(local.storageKey(owner));
    final before = (await local.readFor(owner))?.encode();
    final checkpoint = await preferences.get('bil.smart-plan.sync.$owner.v1');
    final deletion = await preferences.get(local.deletionKey(owner));
    final cloud = await remote.read();
    _checkConflictAccess(owner);
    if (cloud.plan != null &&
        BilSmartPlan.decode(cloud.plan!).ownerId != owner) {
      throw StateError('smart_plan_foreign_owner');
    }
    if (await preferences.get(local.storageKey(owner)) != localRaw) {
      throw StateError('smart_plan_local_changed_during_sync');
    }
    _checkConflictAccess(owner);
    return BilSmartPlanSyncConflict._(
      owner,
      before,
      cloud,
      localRaw,
      checkpoint,
      deletion,
    );
  }

  /// Explicit choice over the exact two reviewed snapshots. Both are retained
  /// in private local export history; no diary or crypto record is overwritten.
  Future<void> resolveConflict(
    BilSmartPlanSyncConflict reviewed, {
    required bool keepLocal,
  }) async {
    final owner = reviewed.owner;
    void check() => _checkConflictAccess(owner);
    check();
    final cloud = await remote.read();
    check();
    if (cloud.revision != reviewed.cloud.revision ||
        cloud.plan != reviewed.cloud.plan ||
        await preferences.get(local.storageKey(owner)) != reviewed.localRaw ||
        await preferences.get('bil.smart-plan.sync.$owner.v1') !=
            reviewed.checkpoint ||
        await preferences.get(local.deletionKey(owner)) != reviewed.deletion) {
      throw StateError('smart_plan_revision_conflict');
    }
    check();
    final historyKey = conflictHistoryKey(owner);
    final historyRaw = await preferences.get(historyKey);
    check();
    final history = historyRaw == null
        ? <Object?>[]
        : jsonDecode(historyRaw) as List;
    if (history.length >= 10) throw StateError('smart_plan_archive_capacity');
    final nextHistory = jsonEncode([
      ...history,
      {
        'ownerId': owner,
        'local': reviewed.localPlan,
        'cloud': reviewed.cloud.plan,
        'cloudRevision': reviewed.cloud.revision,
        'selected': keepLocal ? 'local' : 'cloud',
        'at': DateTime.now().toUtc().toIso8601String(),
      },
    ]);
    if (utf8.encode(nextHistory).length > 2000000) {
      throw StateError('smart_plan_archive_capacity');
    }
    final selected = keepLocal ? reviewed.localPlan : reviewed.cloud.plan;
    var accepted = cloud;
    if (selected != cloud.plan) {
      accepted = await remote.compareAndSwap(cloud.revision, selected);
      check();
      final readback = await remote.read();
      check();
      if (accepted.revision != cloud.revision + 1 ||
          accepted.plan != selected ||
          readback.revision != accepted.revision ||
          readback.plan != selected) {
        throw StateError('smart_plan_sync_unverified');
      }
    }
    final committed = await preferences.mutateIfUnchanged(
      expected: {
        local.storageKey(owner): reviewed.localRaw,
        'bil.smart-plan.sync.$owner.v1': reviewed.checkpoint,
        local.deletionKey(owner): reviewed.deletion,
        historyKey: historyRaw,
      },
      set: {
        local.storageKey(owner): selected ?? '',
        historyKey: nextHistory,
        'bil.smart-plan.sync.$owner.v1': jsonEncode({
          'revision': accepted.revision,
          'plan': selected,
        }),
      },
      remove: [local.deletionKey(owner)],
      isCurrent: () {
        check();
        return true;
      },
    );
    check();
    if (!committed || (await local.readFor(owner))?.encode() != selected) {
      throw StateError('smart_plan_local_changed_during_sync');
    }
    check();
  }
}
