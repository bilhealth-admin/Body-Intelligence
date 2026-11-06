import '../domain/commerce_plan.dart';
import '../domain/subscription_lifecycle.dart';
import '../domain/subscription_state.dart';

/// A short, owner-scoped continuity window for a previously server-verified
/// paid entitlement.
///
/// It is consulted only after a transient server read failure or an
/// unreadable/incomplete snapshot. A valid verified Free/terminal response
/// clears it immediately, it never crosses account boundaries, and it never
/// outlives either the entitlement period or five minutes. This prevents
/// route-to-route Premium/Free flicker without treating local state as
/// purchase authority.
final class VerifiedEntitlementSessionCache {
  VerifiedEntitlementSessionCache({
    this.maximumAge = const Duration(minutes: 5),
  });

  final Duration maximumAge;
  final Map<String, _VerifiedEntitlementCacheEntry> _entries = {};

  void discardPendingPeriods({String? ownerId}) {
    for (final key in ownerId == null ? _entries.keys.toList() : [ownerId]) {
      final entry = _entries[key];
      if (entry != null && entry.state.verifiedNextPeriod != null) {
        _entries[key] = _VerifiedEntitlementCacheEntry(
          entry.state.withVerifiedNextPeriod(null),
          entry.validUntil,
        );
      }
    }
  }

  void remember({
    required String ownerId,
    required SubscriptionState state,
    required DateTime now,
  }) {
    if (state.authority != EntitlementAuthority.verifiedServer ||
        state.plan == CommercePlan.free) {
      _entries.remove(ownerId);
      return;
    }
    final entitlementBoundary = switch (state.lifecycle) {
      SubscriptionLifecycle.trial => state.trialEndsAt,
      SubscriptionLifecycle.gracePeriod => state.gracePeriodEndsAt,
      SubscriptionLifecycle.active ||
      SubscriptionLifecycle.cancelled => state.currentPeriodEndsAt,
      _ => null,
    };
    if (entitlementBoundary == null) {
      _entries.remove(ownerId);
      return;
    }
    final next = state.verifiedNextPeriod;
    final pendingStart = next?.startedAt?.toUtc();
    final nextBoundary = next == null
        ? null
        : verifiedSubscriptionBoundary(next);
    final retainsFutureProof =
        pendingStart != null &&
        !pendingStart.isAfter(entitlementBoundary.toUtc()) &&
        nextBoundary != null &&
        nextBoundary.isAfter(pendingStart);
    final proofBoundary = retainsFutureProof
        ? nextBoundary
        : entitlementBoundary;
    final continuityBoundary = now.toUtc().add(maximumAge);
    final validUntil = proofBoundary.toUtc().isBefore(continuityBoundary)
        ? proofBoundary.toUtc()
        : continuityBoundary;
    if (!validUntil.isAfter(now.toUtc())) {
      _entries.remove(ownerId);
      return;
    }
    _entries[ownerId] = _VerifiedEntitlementCacheEntry(state, validUntil);
  }

  SubscriptionState? fallbackFor({
    required String ownerId,
    required DateTime now,
  }) {
    final entry = _entries[ownerId];
    if (entry == null) return null;
    if (!entry.validUntil.isAfter(now.toUtc())) {
      _entries.remove(ownerId);
      return null;
    }
    final effective = verifiedSubscriptionPeriodAt(entry.state, now);
    final boundary = verifiedSubscriptionBoundary(effective);
    if (boundary == null || !boundary.toUtc().isAfter(now.toUtc())) return null;
    return effective;
  }
}

final class _VerifiedEntitlementCacheEntry {
  const _VerifiedEntitlementCacheEntry(this.state, this.validUntil);

  final SubscriptionState state;
  final DateTime validUntil;
}
