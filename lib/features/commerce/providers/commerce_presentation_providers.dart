part of 'commerce_providers.dart';

/// Access already checks owner, visit, handoff and the original period deadline.
/// Only a previously verified Free display can survive an unresolved reread.
final verifiedSubscriptionPresentationProvider =
    Provider.autoDispose<AsyncValue<SubscriptionState>>((ref) {
      final access = ref.watch(verifiedSubscriptionAccessProvider);
      final owner = ref.watch(verifiedEntitlementOwnerProvider);
      if (owner.hasError || isVerifiedCommerceSessionInvalid(access.error)) {
        return access;
      }
      if (ref.watch(verifiedEntitlementOwnerIdProvider) == null) {
        return const AsyncValue.loading();
      }
      final canonical = ref.watch(
        _verifiedSubscriptionCanonicalSnapshotProvider,
      );
      if ((access.isLoading ||
              access.hasError ||
              access.value?.authority != EntitlementAuthority.verifiedServer) &&
          canonical.freePresentation != null) {
        return AsyncValue.data(canonical.freePresentation!);
      }
      return access;
    });

/// Only a public, previously verified Free presentation can suppress a
/// checking decoration. This boolean never grants a positive capability.
final verifiedFreePresentationProvider = Provider.autoDispose<bool>((ref) {
  final display = ref.watch(verifiedSubscriptionPresentationProvider);
  final state = display.asData?.value;
  return state?.authority == EntitlementAuthority.verifiedServer &&
      state?.plan == CommercePlan.free;
});
