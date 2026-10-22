import 'dart:async';

import '../../../data/repositories/preferences_repository.dart';
import '../domain/bil_smart_plan.dart';

/// Private local copy tied to the same owner-scoped Drift DB as the diary.
/// This is not yet multi-device cloud synchronization.
final class BilSmartPlanRepository {
  BilSmartPlanRepository({
    required this.preferences,
    required this.currentOwnerId,
  });

  final PreferencesRepository preferences;
  final String? Function() currentOwnerId;

  String _keyFor(String owner) => 'bil.smart-plan.owner.' + owner + '.v1';

  void _requireOwner(String owner) {
    if (owner.isEmpty || currentOwnerId() != owner ||
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
    await preferences.update(_keyFor(owner), (current) {
      _requireOwner(owner);
      final previous = current == null || current.isEmpty
          ? null : BilSmartPlan.decode(current);
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
      return next.encode();
    }, isCurrent: () => currentOwnerId() == owner &&
        preferences.localOwnerId == owner);
    _requireOwner(owner);
    final readback = await readFor(owner);
    if (readback == null || readback.revision != next.revision ||
        readback.id != next.id) {
      throw StateError('smart_plan_save_unverified');
    }
    return readback;
  }

  Future<void> removeWithConfirmation({
    required String owner,
    required String expectedId,
    required int expectedRevision,
  }) async {
    _requireOwner(owner);
    final current = await readFor(owner);
    if (current == null || current.id != expectedId ||
        current.revision != expectedRevision) {
      throw StateError('smart_plan_revision_conflict');
    }
    await preferences.update(_keyFor(owner), (raw) {
      _requireOwner(owner);
      final latest = raw == null ? null : BilSmartPlan.decode(raw);
      if (latest?.id != expectedId ||
          latest?.revision != expectedRevision) {
        throw StateError('smart_plan_revision_conflict');
      }
      // update cannot delete; dedicated deletion outside the transaction is
      // intentionally not allowed. Persist a tombstone until Cloud sync arrives.
      return '';
    }, isCurrent: () => currentOwnerId() == owner &&
        preferences.localOwnerId == owner);
    _requireOwner(owner);
  }
}
