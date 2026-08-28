import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../domain/commerce_plan.dart';
import '../domain/market_offer_policy.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/store_offer_metadata.dart';
import '../domain/subscription_state.dart';
import '../repositories/entitlement_repository.dart';
import '../repositories/local_entitlement_repository.dart';
import '../repositories/server_entitlement_repository.dart';

final entitlementRepositoryProvider = Provider<EntitlementRepository>(
  (ref) => const LocalEntitlementRepository(),
);

final subscriptionStateProvider = Provider<SubscriptionState>(
  (ref) => ref.watch(entitlementRepositoryProvider).current(),
);

/// Tracks the authenticated owner that server-verified entitlements belong to.
///
/// Entitlements must be refreshed when authentication changes. Otherwise a
/// cached Guest result can survive sign-in, or a verified Free result can
/// survive sign-out and incorrectly make a Guest eligible for ads.
final verifiedEntitlementOwnerProvider = StreamProvider<String?>((ref) async* {
  if (!AppEnvironment.supabaseRuntimeReady) {
    yield null;
    return;
  }

  final auth = Supabase.instance.client.auth;
  var previousOwnerId = auth.currentUser?.id;
  yield previousOwnerId;

  await for (final state in auth.onAuthStateChange) {
    final ownerId = state.session?.user.id;
    if (ownerId == previousOwnerId) continue;
    previousOwnerId = ownerId;
    yield ownerId;
  }
});

final verifiedSubscriptionStateProvider = FutureProvider<SubscriptionState>((
  ref,
) async {
  ref.watch(verifiedEntitlementOwnerProvider);
  return const ServerEntitlementRepository().current();
});

/// Server-owned AI access truth for token markets.
///
/// A local purchase callback is never enough to unlock the coach. The gate
/// opens only after Supabase reports a verified, spendable Boost balance (or
/// an active AI Coach plan). This keeps a consumed or forged store callback
/// from granting paid cloud access on the device.
final aiCoachCreditAccessProvider = FutureProvider<bool>((ref) async {
  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) return false;
  try {
    final value = await client.rpc('bil_get_ai_usage_status');
    final status = Map<String, Object?>.from(value as Map);
    if (status['plan']?.toString() == 'ai_coach') return true;
    final rawCredits = status['credits'];
    if (rawCredits is! Map) return false;
    final credits = Map<String, Object?>.from(rawCredits);
    if (status['plan']?.toString() == 'trial') {
      final included = credits['included_remaining'];
      return included is num && included > 0;
    }
    final paid = credits['paid_remaining'];
    return paid is num && paid > 0;
  } on Object {
    // Access fails closed when the server cannot establish credit truth.
    return false;
  }
});

/// Meal-photo analysis is purchased through AI Boost in every storefront.
/// It deliberately ignores subscription/included allowance and opens only
/// when Supabase confirms enough paid credit for one Vision reservation.
final aiBoostVisionAccessProvider = FutureProvider<bool>((ref) async {
  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) return false;
  try {
    final value = await client.rpc('bil_get_ai_usage_status');
    final status = Map<String, Object?>.from(value as Map);
    final rawCredits = status['credits'];
    if (rawCredits is! Map) return false;
    final credits = Map<String, Object?>.from(rawCredits);
    final paidRemaining = credits['paid_remaining'];
    return paidRemaining is num && paidRemaining >= 100;
  } on Object {
    // Cloud-paid access fails closed when current credit cannot be verified.
    return false;
  }
});

/// The device store is authoritative for the market-facing tier before a
/// purchase exists. Play/App Store already filter products by the account's
/// billing storefront, so no IP, language, or device locale is consulted.
final storefrontTargetPlanProvider = FutureProvider<CommercePlan?>((ref) async {
  if (!AppEnvironment.commerceConfigured) return null;
  final store = InAppPurchase.instance;
  if (!await store.isAvailable()) return null;
  final response = await store.queryProductDetails(
    StoreCatalogConfiguration.productIds,
  );
  if (response.error != null) return null;
  final kinds = response.productDetails.map((product) {
    final plan = StoreCatalogConfiguration.bindingForProduct(product.id)?.plan;
    return plan == CommercePlan.premiumAiCoach
        ? BilStoreProductKind.premiumAiCoachSubscription
        : plan == CommercePlan.premium
        ? BilStoreProductKind.premiumSubscription
        : null;
  }).whereType<BilStoreProductKind>();
  return MarketOfferPolicy.targetPlanForKinds(kinds);
});
