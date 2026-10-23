import 'dart:async';
import 'dart:convert';

import '../../../data/repositories/preferences_repository.dart';
import '../domain/bil_smart_plan.dart';
part 'bil_smart_plan_draft_repository.dart';

/// Private local copy tied to the same owner-scoped Drift DB as the diary.
/// The active plan has a separate, explicitly consented cloud synchronization.
final class BilSmartPlanRepository {
  BilSmartPlanRepository({
    required this.preferences,
    required this.currentOwnerId,
  });

  final PreferencesRepository preferences;
  final String? Function() currentOwnerId;

  String _keyFor(String owner) => 'bil.smart-plan.owner.$owner.v1';

  String storageKey(String owner) => _keyFor(owner);
  String deletionKey(String owner) => 'bil.smart-plan.deleted.$owner.v1';

  /// Used only after the three-way cloud conflict/consent checks. A concurrent
  /// local edit, auth change, or foreign owner aborts the SQLite transaction.
  Future<void> restoreSnapshot({
    required String owner,
    required String? expected,
    required String? next,
  }) async {
    _requireOwner(owner);
    if (next != null && BilSmartPlan.decode(next).ownerId != owner) {
      throw StateError('smart_plan_foreign_owner');
    }
    await preferences.update(
      _keyFor(owner),
      (raw) {
        _requireOwner(owner);
        final current = raw == null || raw.isEmpty
            ? null
            : BilSmartPlan.decode(raw).encode();
        if (current != expected) {
          throw StateError('smart_plan_revision_conflict');
        }
        return next ?? '';
      },
      isCurrent: () =>
          currentOwnerId() == owner && preferences.localOwnerId == owner,
    );
    _requireOwner(owner);
  }

  void _requireOwner(String owner) {
    if (owner.isEmpty ||
        currentOwnerId() != owner ||
        preferences.localOwnerId != owner) {
      throw StateError('smart_plan_owner_changed');
    }
  }

  Future<BilSmartPlan?> readFor(String owner) async {
    _requireOwner(owner);
    final raw = await preferences.get(_keyFor(owner));
    _requireOwner(owner);
    if (raw == null || raw.isEmpty) return null;
    final plan = BilSmartPlan.decode(raw);
    if (plan.ownerId != owner) {
      throw StateError('smart_plan_foreign_owner');
    }
    return plan;
  }

  /// Atomic compare-and-swap. Conflicting writers must reload; never overwrite.
  Future<BilSmartPlan> save(
    BilSmartPlan next, {
    required int expectedRevision,
  }) async {
    final owner = next.ownerId;
    _requireOwner(owner);
    // Validate encoding/size before entering the write transaction. A failed
    // readback must never leave an oversized, unreadable schedule on disk.
    final encoded = next.encode();
    await preferences.update(
      _keyFor(owner),
      (current) {
        _requireOwner(owner);
        final previous = current == null || current.isEmpty
            ? null
            : BilSmartPlan.decode(current);
        if (previous != null && previous.ownerId != owner) {
          throw StateError('smart_plan_foreign_owner');
        }
        if ((previous?.revision ?? 0) != expectedRevision ||
            next.revision != expectedRevision + 1) {
          throw StateError('smart_plan_revision_conflict');
        }
        if (previous != null && previous.id != next.id) {
          // A plan replacement needs an explicit archive/replace journey.
          throw StateError('smart_plan_existing_plan');
        }
        return encoded;
      },
      isCurrent: () =>
          currentOwnerId() == owner && preferences.localOwnerId == owner,
    );
    _requireOwner(owner);
    final readback = await readFor(owner);
    if (readback == null ||
        readback.revision != next.revision ||
        readback.id != next.id ||
        readback.encode() != next.encode()) {
      throw StateError('smart_plan_save_unverified');
    }
    return readback;
  }

  Future<Map<String, Object?>> exportWorkoutReceipts(BilSmartPlan plan) async {
    _requireOwner(plan.ownerId);
    final keys = [
      for (final day in plan.days)
        'bil.smart-plan.workout.${plan.id}.${day.date}',
    ];
    final raw = await preferences.watchSnapshot(keys).first;
    _requireOwner(plan.ownerId);
    final receipts = <String, Object?>{};
    for (final item in raw.entries) {
      final receipt = jsonDecode(item.value);
      if (receipt is! Map || receipt['ownerId'] != plan.ownerId) {
        throw StateError('smart_plan_foreign_receipt');
      }
      receipts[item.key] = receipt;
    }
    return receipts;
  }

  Future<void> removeWithConfirmation({
    required String owner,
    required String expectedId,
    required int expectedRevision,
  }) async {
    _requireOwner(owner);
    final current = await readFor(owner);
    if (current == null ||
        current.id != expectedId ||
        current.revision != expectedRevision) {
      throw StateError('smart_plan_revision_conflict');
    }
    final raw = await preferences.get(_keyFor(owner));
    _requireOwner(owner);
    final latest = raw == null || raw.isEmpty ? null : BilSmartPlan.decode(raw);
    if (latest?.id != expectedId || latest?.revision != expectedRevision) {
      throw StateError('smart_plan_revision_conflict');
    }
    final removed = await preferences.mutateIfUnchanged(
      expected: {_keyFor(owner): raw},
      set: {
        _keyFor(owner): '',
        deletionKey(owner): jsonEncode({
          'id': current.id,
          'revision': current.revision,
        }),
      },
      remove: [
        for (final day in current.days)
          'bil.smart-plan.workout.${current.id}.${day.date}',
      ],
      isCurrent: () =>
          currentOwnerId() == owner && preferences.localOwnerId == owner,
    );
    if (!removed) throw StateError('smart_plan_revision_conflict');
    _requireOwner(owner);
  }
}
