part of 'commerce_providers.dart';

/// Injectable only for deterministic expiry tests; the device clock never
/// creates an entitlement, it can only shorten an already verified grant.
final verifiedEntitlementClockProvider = Provider<DateTime Function()>(
  (_) =>
      () => DateTime.now().toUtc(),
);

/// One immediate read per observed period boundary, scoped to the auth owner.
/// Remembering the boundary across provider generations prevents an unchanged
/// expired server row (or an offline read) from creating a refresh loop.
final class VerifiedSubscriptionBoundaryRefresh {
  final Set<DateTime> _requested = {};
  bool claim(DateTime boundary) {
    if (!_requested.add(boundary.toUtc())) return false;
    if (_requested.length > 16) _requested.remove(_requested.first);
    return true;
  }
}

final verifiedSubscriptionBoundaryRefreshProvider =
    Provider<VerifiedSubscriptionBoundaryRefresh>((ref) {
      ref.watch(verifiedEntitlementOwnerIdProvider);
      return VerifiedSubscriptionBoundaryRefresh();
    });

final class _VerifiedSubscriptionCanonicalSnapshot {
  SubscriptionState? verified;

  void observe(SubscriptionState state) {
    if (state.authority == EntitlementAuthority.verifiedServer) {
      verified = state;
    } else if (state.plan == CommercePlan.free &&
        state.verifiedAt != null &&
        state.provider != null) {
      // This row retires its store proof even if a separate grant was unreadable.
      verified = state;
    } else if (verified?.provider == null) {
      // The repository already applies the independent grant/admin leases.
      // An unresolved composite contains no surviving proof from either one.
      verified = null;
    }
  }
}

// Canonical server proof, independent of Riverpod's refresh/reload decoration.
// This is not the presentation cache or a new lease: its original interval is
// re-evaluated below on every read and at the exact start/expiry timer.
final _verifiedSubscriptionCanonicalSnapshotProvider =
    Provider<_VerifiedSubscriptionCanonicalSnapshot>((ref) {
      ref.watch(verifiedEntitlementOwnerIdProvider);
      ref.watch(verifiedEntitlementOwnerVisitProvider);
      return _VerifiedSubscriptionCanonicalSnapshot();
    });

/// Server-verified access with an exact local cutoff. Rechecking an unchanged
/// owner cannot withdraw an already-proved period, including dependency reloads
/// and transient transport failures. A fresh denial or invalid session wins.
final verifiedSubscriptionAccessProvider =
    Provider.autoDispose<AsyncValue<SubscriptionState>>((ref) {
      final ownerId = ref.watch(verifiedEntitlementOwnerIdProvider);
      final canonical = ref.watch(
        _verifiedSubscriptionCanonicalSnapshotProvider,
      );
      final owner = ref.watch(verifiedEntitlementOwnerProvider);
      if (owner.hasError) {
        canonical.verified = null;
        return AsyncValue.error(owner.error!, owner.stackTrace!);
      }
      final now = ref.watch(verifiedEntitlementClockProvider)().toUtc();
      final source = ref.watch(verifiedSubscriptionStateProvider);
      var handoff = ref.watch(verifiedPurchaseHandoffProvider);
      final previous = canonical.verified;
      // A pending/error decoration can hide the last observed store denial
      // from the handoff comparison. Keep its version fence across rereads.
      final previousOrder = handoff == null
          ? null
          : comparePurchaseProofVersion(previous, handoff);
      if (handoff != null &&
          handoff.plan != CommercePlan.free &&
          previous?.plan == CommercePlan.free &&
          (previousOrder ?? -1) >= 0) {
        handoff = null;
      }
      var snapshot = purchaseHandoffView(source, handoff, now);
      if (isVerifiedCommerceSessionInvalid(source.error) ||
          isVerifiedCommerceSessionInvalid(snapshot.error)) {
        canonical.verified = null;
        return AsyncValue.error(snapshot.error!, snapshot.stackTrace!);
      }
      // A store denial retires only paid proof it could supersede. The
      // composite Free result remains available for presentation while its
      // next read is held. A later canonical repurchase keeps its own term.
      if (handoff?.authority == EntitlementAuthority.verifiedServer &&
          handoff?.plan == CommercePlan.free &&
          previous != null &&
          previous.plan != CommercePlan.free &&
          (previous.provider == SubscriptionProvider.apple ||
              previous.provider == SubscriptionProvider.google) &&
          (previousOrder ?? -1) <= 0) {
        canonical.verified = null;
      }
      final fresh = snapshot.asData?.value;
      if (!snapshot.isLoading &&
          !snapshot.hasError &&
          fresh?.authority == EntitlementAuthority.verifiedServer) {
        // A store-only denial can supersede an older store grant immediately.
        // Only a completed composite read can establish Free continuity for
        // periods when independent account authorities are unresolved.
        if (fresh!.plan != CommercePlan.free || !identical(fresh, handoff)) {
          canonical.verified = fresh;
        }
      } else if (ownerId != null &&
          canonical.verified?.authority ==
              EntitlementAuthority.verifiedServer &&
          canonical.verified?.plan != CommercePlan.free) {
        // Owner and visit changes create a new empty canonical slot above.
        // Even an expired proof goes through the exact-boundary logic below;
        // no retry can renew its dates or turn it into a fresh subscription.
        snapshot = AsyncValue.data(canonical.verified!);
      }
      // A new/unverified owner and a previous Free snapshot remain unresolved
      // during verification; they never borrow the AsyncValue's old account.
      if (snapshot.isLoading &&
          (!snapshot.isRefreshing ||
              !identical(snapshot.value, canonical.verified) ||
              snapshot.value?.authority !=
                  EntitlementAuthority.verifiedServer ||
              snapshot.value?.plan == CommercePlan.free)) {
        return const AsyncValue.loading();
      }
      if (snapshot.hasError) {
        // A failed read may carry Riverpod's old paid .value even after that
        // proof was retired while this consumer was absent. Expose the error
        // without the previous account/period payload.
        return AsyncValue.error(snapshot.error!, snapshot.stackTrace!);
      }
      final rawState = snapshot.value;
      final state = rawState == null
          ? null
          : verifiedSubscriptionPeriodAt(rawState, now);
      if (state == null || state.plan == CommercePlan.free) return snapshot;
      final boundary = verifiedSubscriptionBoundary(state)?.toUtc();
      final boundaryRefresh = ref.watch(
        verifiedSubscriptionBoundaryRefreshProvider,
      );
      void reloadAtBoundary(DateTime transition) {
        if (boundaryRefresh.claim(transition) &&
            !ref.read(verifiedSubscriptionStateProvider).isLoading) {
          ref.invalidate(verifiedSubscriptionStateProvider);
        }
        ref.invalidateSelf();
      }

      if (state.authority != EntitlementAuthority.verifiedServer ||
          boundary == null ||
          !boundary.toUtc().isAfter(now) ||
          (state.startedAt?.toUtc().isAfter(now) ?? false)) {
        if (state.authority == EntitlementAuthority.verifiedServer &&
            boundary != null &&
            !boundary.isAfter(now) &&
            boundaryRefresh.claim(boundary)) {
          final refresh = Timer(Duration.zero, () {
            if (!ref.read(verifiedSubscriptionStateProvider).isLoading) {
              ref.invalidate(verifiedSubscriptionStateProvider);
            }
          });
          ref.onDispose(refresh.cancel);
        }
        return AsyncValue.data(
          SubscriptionState(
            plan: CommercePlan.free,
            entitlements: FreePlan.entitlements,
            authority: state.authority,
            lifecycle: SubscriptionLifecycle.expired,
            storeRenewalObservation: state.storeRenewalObservation,
            storeRenewalDefinitivelyInactive:
                state.storeRenewalDefinitivelyInactive,
            provider: state.provider,
            isPurchasable: false,
            canRestorePurchases: state.canRestorePurchases,
          ),
        );
      }
      final nextStart = state.verifiedNextPeriod?.startedAt?.toUtc();
      final transition =
          nextStart != null &&
              nextStart.isAfter(now) &&
              !nextStart.isAfter(boundary)
          ? nextStart
          : boundary;
      final expiry = Timer(
        transition.difference(now),
        () => reloadAtBoundary(transition),
      );
      ref.onDispose(expiry.cancel);
      return AsyncValue.data(state);
    });

/// Pure fail-closed mapping from the server quota snapshot to AI Coach route
/// access. Subscription allowances and paid Boost credits unlock the coach;
/// neither source is converted into a Premium entitlement.
bool aiCoachAccessFromUsageStatus(Object? value) =>
    verifiedAiCoachAccessFromUsageStatus(value) == true;

/// Null is an unavailable authority response; it never means a verified zero.
bool? verifiedAiCoachAccessFromUsageStatus(Object? value) {
  if (value is! Map) return null;
  try {
    final status = Map<String, Object?>.from(value);
    final rawCredits = status['credits'];
    if (rawCredits is! Map) return null;
    final credits = Map<String, Object?>.from(rawCredits);
    // The server computes total_remaining from reserved-aware included and paid
    // balances in one transaction. Treat that single field as the access
    // authority regardless of whether the balance came from an AI subscription
    // allowance or a paid Boost. Reconstructing it (or gating it on the plan
    // label) can race an in-flight reserve and can incorrectly reject a Boost
    // owned by someone who also has ordinary Premium.
    final remaining = credits['total_remaining'];
    if (remaining is! num || !remaining.isFinite || remaining < 0) return null;
    return remaining > 0;
  } on Object {
    // Maps with non-string keys or malformed nested structures also fail
    // closed without incorrectly turning unavailable authority into an upsell.
    return null;
  }
}

bool hasVerifiedAiSubscription(SubscriptionState? state, {DateTime? now}) {
  if (state?.authority != EntitlementAuthority.verifiedServer ||
      state?.plan != CommercePlan.premiumAiCoach) {
    return false;
  }
  final boundary = switch (state!.lifecycle) {
    SubscriptionLifecycle.trial => state.trialEndsAt,
    SubscriptionLifecycle.active ||
    SubscriptionLifecycle.cancelled => state.currentPeriodEndsAt,
    SubscriptionLifecycle.gracePeriod => state.gracePeriodEndsAt,
    _ => null,
  };
  return boundary != null &&
      boundary.toUtc().isAfter((now ?? DateTime.now()).toUtc());
}
