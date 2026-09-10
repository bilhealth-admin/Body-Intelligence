import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../domain/commerce_plan.dart';
import '../domain/market_offer_policy.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/store_offer_metadata.dart';
import '../domain/subscription_lifecycle.dart';
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

final verifiedEntitlementLoaderProvider =
    Provider<Future<SubscriptionState> Function()>(
      (_) => const ServerEntitlementRepository().current,
    );

/// Starts a non-overlapping refresh after a load finishes and only while its
/// provider is observed. Credit access must refresh independently of Premium.
void Function() _observedAuthorityReload(Ref ref, void Function() reload) {
  Timer? refresh;
  var disposed = false;
  var observed = true;
  var loaded = false;
  void schedule() {
    refresh?.cancel();
    refresh = Timer(const Duration(seconds: 30), reload);
  }

  ref.onCancel(() {
    observed = false;
    refresh?.cancel();
  });
  ref.onResume(() {
    observed = true;
    if (loaded) schedule();
  });
  ref.onDispose(() {
    disposed = true;
    refresh?.cancel();
  });
  return () {
    loaded = true;
    if (!disposed && observed) schedule();
  };
}

final verifiedSubscriptionStateProvider = FutureProvider<SubscriptionState>((
  ref,
) async {
  ref.watch(verifiedEntitlementOwnerProvider);
  final loaded = _observedAuthorityReload(ref, ref.invalidateSelf);
  try {
    return await ref.watch(verifiedEntitlementLoaderProvider)();
  } finally {
    loaded();
  }
});

double _positiveFiniteNumber(Object? value) {
  if (value is! num) return 0;
  final number = value.toDouble();
  return number.isFinite && number > 0 ? number : 0;
}

/// Pure fail-closed mapping from the server quota snapshot to AI Coach route
/// access. Subscription allowances and paid Boost credits unlock the coach;
/// neither source is converted into a Premium entitlement.
bool aiCoachAccessFromUsageStatus(Object? value) {
  if (value is! Map) return false;
  try {
    final status = Map<String, Object?>.from(value);
    final rawCredits = status['credits'];
    if (rawCredits is! Map) return false;
    final credits = Map<String, Object?>.from(rawCredits);
    // The server computes total_remaining from reserved-aware included and paid
    // balances in one transaction. Treat that single field as the access
    // authority regardless of whether the balance came from an AI subscription
    // allowance or a paid Boost. Reconstructing it (or gating it on the plan
    // label) can race an in-flight reserve and can incorrectly reject a Boost
    // owned by someone who also has ordinary Premium.
    return _positiveFiniteNumber(credits['total_remaining']) > 0;
  } on Object {
    // Maps with non-string keys or malformed nested structures also fail
    // closed instead of surfacing a parsing exception into the route gate.
    return false;
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

typedef AiCoachUsageStatusLoader = Future<Object?> Function();

/// Monotonic signal used by already-mounted AI Coach balance surfaces to
/// request a fresh server snapshot.
///
/// The signal intentionally carries no balance data. Reset notices only tell
/// consumers to reload; `bil_get_ai_usage_status` remains the sole authority
/// for the numbers that are shown and for route access.
final aiCoachUsageRefreshProvider =
    NotifierProvider<AiCoachUsageRefreshController, int>(
      AiCoachUsageRefreshController.new,
    );

final class AiCoachUsageRefreshController extends Notifier<int> {
  @override
  int build() => 0;

  void requestAuthoritativeReload() => state += 1;
}

/// Keeps the Supabase boundary injectable so the access provider's failure
/// state can be exercised without replacing the provider under test.
final aiCoachUsageStatusLoaderProvider = Provider<AiCoachUsageStatusLoader>(
  (_) => () async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return null;
    return client.rpc('bil_get_ai_usage_status');
  },
);

/// Server-owned AI access truth for token markets.
///
/// A local purchase callback is never enough to unlock the coach. The gate
/// opens only after Supabase reports a positive reserved-aware total from an
/// AI subscription allowance and/or verified Boost balance. An active plan at
/// zero does not bypass quota, and a consumed/forged callback grants nothing.
final aiCoachCreditAccessProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  ref.watch(verifiedEntitlementOwnerProvider);
  ref.watch(aiCoachUsageRefreshProvider);
  final loaded = _observedAuthorityReload(ref, () {
    ref.read(aiCoachUsageRefreshProvider.notifier).requestAuthoritativeReload();
  });
  // A signed-out or malformed response is a verified no-access result. An
  // RPC exception is deliberately allowed through so Riverpod exposes
  // AsyncError and the route shows retry instead of a purchase offer.
  try {
    final value = await ref
        .read(aiCoachUsageStatusLoaderProvider)()
        .timeout(const Duration(seconds: 10));
    return aiCoachAccessFromUsageStatus(value);
  } finally {
    loaded();
  }
}, retry: (_, _) => null);

/// Meal-photo analysis is purchased through AI Boost in every storefront.
/// It deliberately ignores subscription/included allowance and opens only
/// when Supabase confirms enough paid credit for one Vision reservation.
final aiBoostVisionAccessProvider = FutureProvider<bool>((ref) async {
  ref.watch(verifiedEntitlementOwnerProvider);
  ref.watch(aiCoachUsageRefreshProvider);
  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) return false;
  try {
    final value = await client.rpc('bil_get_ai_usage_status');
    final status = Map<String, Object?>.from(value as Map);
    final rawCredits = status['credits'];
    if (rawCredits is! Map) return false;
    final credits = Map<String, Object?>.from(rawCredits);
    final paidRemaining = credits['paid_remaining'];
    return paidRemaining is num &&
        paidRemaining.isFinite &&
        paidRemaining >= 100;
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
