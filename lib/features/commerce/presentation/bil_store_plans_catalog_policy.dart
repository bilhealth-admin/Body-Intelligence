part of 'bil_store_plans_page.dart';

// Choosing another term is not a new purchase attempt. Only retryable launch
// or cancellation feedback may clear. Pending and verification failures stay
// visible and fail closed until their native transaction resolves.
bool _mayClearOfferFeedback({
  required bool restoring,
  required String? feedback,
}) =>
    !restoring &&
    feedback != null &&
    !const {
      'purchase_awaiting_approval',
      'purchase_in_progress',
      'purchase_verification_unavailable',
      'purchase_confirmation_pending',
      'purchase_reconciliation_pending',
      'purchase_reconciliation_failed',
      'purchase_owned_by_another_account',
      'restore_verification_failed',
    }.contains(feedback);

Future<List<BilStoreOfferMetadata>> _loadVisibleStoreOffers(
  BilStoreCatalogGateway catalog,
  Set<String> productIds,
) async {
  List<BilStoreOfferMetadata> offers;
  try {
    // An unavailable device store must settle into truthful unavailable prices.
    offers = await catalog
        .loadOffers(productIds)
        .timeout(BilStoreCatalogGateway.loadTimeout);
  } on TimeoutException {
    offers = const [];
  } catch (_) {
    offers = const [];
  }
  // Malformed provider entries remain retryable on the next tap or app resume.
  return MarketOfferPolicy.visibleOffers(offers);
}

bool _hasUnresolvedStorePurchase(
  AiBoostPurchaseService? boost,
  VerifiedStorePurchaseService? store,
) =>
    boost?.canRetry == true ||
    store != null &&
        (store.busy ||
            store.verificationBackedOff ||
            const {
              'reconciliation_verification_failed',
              'verification_failed',
              'restore_verification_failed',
              'purchase_status_unknown',
              'store_finish_pending',
            }.contains(store.messageCode));

CommercePlan? _verifiedPlan(AsyncValue<SubscriptionState> snapshot) {
  final state = snapshot.asData?.value;
  return state?.authority == EntitlementAuthority.verifiedServer
      ? state!.plan
      : null;
}
