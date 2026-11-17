part of 'commerce_providers.dart';

final class _SubscriptionPresentationSnapshot {
  SubscriptionState? verified;
}

final _subscriptionPresentationSnapshotProvider =
    Provider<_SubscriptionPresentationSnapshot>((ref) {
      ref.watch(verifiedEntitlementOwnerIdProvider);
      ref.watch(verifiedEntitlementOwnerVisitProvider);
      return _SubscriptionPresentationSnapshot();
    });

/// Display continuity, never the authority for checkout or a protected write.
/// All commands continue reading [verifiedSubscriptionAccessProvider]. A
/// background check must not replace already verified content with a spinner.
final verifiedSubscriptionPresentationProvider =
    Provider.autoDispose<AsyncValue<SubscriptionState>>((ref) {
      final owner = ref.watch(verifiedEntitlementOwnerIdProvider);
      final store = ref.watch(_subscriptionPresentationSnapshotProvider);
      final access = ref.watch(verifiedSubscriptionAccessProvider);
      final source = ref.watch(verifiedSubscriptionStateProvider);
      final ownerSnapshot = ref.watch(verifiedEntitlementOwnerProvider);
      final now = ref.watch(verifiedEntitlementClockProvider)().toUtc();
      final value = access.asData?.value;
      final sessionInvalid =
          isVerifiedCommerceSessionInvalid(access.error) ||
          isVerifiedCommerceSessionInvalid(source.error) ||
          ownerSnapshot.hasError;
      if (sessionInvalid) {
        store.verified = null;
        if (ownerSnapshot.hasError) {
          return AsyncValue.error(
            ownerSnapshot.error!,
            ownerSnapshot.stackTrace!,
          );
        }
        final denied = source.hasError ? source : access;
        return AsyncValue.error(denied.error!, denied.stackTrace!);
      }
      if (owner == null || (source.isLoading && source.isReloading)) {
        store.verified = null;
        return const AsyncValue.loading();
      }
      if (!access.isLoading &&
          !access.hasError &&
          value?.authority == EntitlementAuthority.verifiedServer) {
        store.verified = value;
      }
      final previous = store.verified;
      if (previous == null) {
        // AsyncError may carry a previous value through Riverpod refreshes.
        // A retired display must not borrow that older owner's/visit's value.
        return access.hasError
            ? AsyncValue.error(access.error!, access.stackTrace!)
            : access;
      }
      // Use the same canonical handoff ordering as the access provider: a
      // verified revocation must replace a store-backed paid display promptly.
      final handoff = purchaseHandoffView(
        AsyncValue.data(previous),
        ref.watch(verifiedPurchaseHandoffProvider),
        now,
      );
      var retained = verifiedSubscriptionPeriodAt(
        handoff.asData?.value ?? previous,
        now,
      );
      final boundary = verifiedSubscriptionBoundary(retained)?.toUtc();
      if (retained.plan != CommercePlan.free &&
          (boundary == null ||
              !boundary.isAfter(now) ||
              (retained.startedAt?.toUtc().isAfter(now) ?? false))) {
        retained = SubscriptionState(
          plan: CommercePlan.free,
          entitlements: FreePlan.entitlements,
          authority: retained.authority,
          lifecycle: SubscriptionLifecycle.expired,
          provider: retained.provider,
          isPurchasable: false,
          canRestorePurchases: retained.canRestorePurchases,
        );
      }
      if (boundary != null && boundary.isAfter(now)) {
        final nextStart = retained.verifiedNextPeriod?.startedAt?.toUtc();
        final transition =
            nextStart != null &&
                nextStart.isAfter(now) &&
                nextStart.isBefore(boundary)
            ? nextStart
            : boundary;
        final timer = Timer(transition.difference(now), ref.invalidateSelf);
        ref.onDispose(timer.cancel);
      }
      return AsyncValue.data(retained);
    });

/// Only a public, previously verified Free presentation can suppress a
/// checking decoration. This boolean never grants a positive capability.
final verifiedFreePresentationProvider = Provider.autoDispose<bool>((ref) {
  final display = ref.watch(verifiedSubscriptionPresentationProvider);
  final state = display.asData?.value;
  return state?.authority == EntitlementAuthority.verifiedServer &&
      state?.plan == CommercePlan.free;
});
