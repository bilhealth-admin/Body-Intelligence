import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../auth/retryable_auth_session.dart';
import '../domain/commerce_plan.dart';
import '../domain/ai_coach_access_snapshot.dart';
import 'verified_purchase_handoff.dart';
import '../domain/free_plan.dart';
import '../domain/market_offer_policy.dart';
import '../domain/storefront_market_policy.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/store_offer_metadata.dart';
import '../domain/subscription_lifecycle.dart';
import '../domain/subscription_provider.dart';
import '../domain/subscription_state.dart';
import '../repositories/entitlement_repository.dart';
import '../repositories/local_entitlement_repository.dart';
import '../repositories/server_entitlement_repository.dart';

export '../domain/ai_coach_access_snapshot.dart';
export '../repositories/server_entitlement_repository.dart'
    show isVerifiedCommerceSessionInvalid;

part 'commerce_presentation_providers.dart';
part 'commerce_subscription_access.dart';

final entitlementRepositoryProvider = Provider<EntitlementRepository>(
  (ref) => const LocalEntitlementRepository(),
);

final subscriptionStateProvider = Provider<SubscriptionState>(
  (ref) => ref.watch(entitlementRepositoryProvider).current(),
);

/// The real SDK auth client; injectable only at the identity I/O boundary.
final verifiedEntitlementAuthClientProvider = Provider<GoTrueClient?>((_) {
  if (!AppEnvironment.supabaseRuntimeReady) {
    return null;
  }
  return Supabase.instance.client.auth;
});

/// Tracks the authenticated owner that server-verified entitlements belong to.
///
/// Entitlements must be refreshed when authentication changes. Otherwise a
/// cached Guest result can survive sign-in, or a verified Free result can
/// survive sign-out and incorrectly make a Guest eligible for ads.
final verifiedEntitlementOwnerProvider = StreamProvider<String?>((ref) async* {
  final auth = ref.watch(verifiedEntitlementAuthClientProvider);
  if (auth == null) {
    yield null;
    return;
  }
  var previousOwnerId = auth.currentUser?.id;
  yield previousOwnerId;

  final changes = auth.onAuthStateChange.transform(
    StreamTransformer<AuthState, AuthState>.fromHandlers(
      handleError: (error, stack, sink) {
        if (isSameOwnerRetryableAuthReadFailure(
          error,
          auth: auth,
          previousOwnerId: previousOwnerId,
        )) {
          return;
        }
        sink.addError(error, stack);
      },
    ),
  );
  await for (final state in changes) {
    // Native session persistence can emit a transient null. An explicit
    // sign-out remains authoritative and clears all owner-scoped state.
    if (state.session == null && state.event != AuthChangeEvent.signedOut) {
      continue;
    }
    final ownerId = state.session?.user.id;
    if (ownerId == previousOwnerId) continue;
    previousOwnerId = ownerId;
    yield ownerId;
  }
});

/// Synchronous owner seed used only until the auth stream publishes its first
/// value. This prevents an AsyncLoading -> AsyncData transition for the same
/// signed-in member from looking like an account change to access providers.
final verifiedEntitlementOwnerSeedProvider = Provider<String?>((ref) {
  return ref.watch(verifiedEntitlementAuthClientProvider)?.currentUser?.id;
});

/// Stable scalar owner identity. Once the stream has emitted, including an
/// authoritative signed-out null, that stream value always wins over the
/// startup seed.
final verifiedEntitlementOwnerIdProvider = Provider<String?>((ref) {
  final owner = ref.watch(verifiedEntitlementOwnerProvider);
  if (owner.hasValue) return owner.value;
  return ref.watch(verifiedEntitlementOwnerSeedProvider);
});

/// A -> B -> A can occur between UI frames, when a scalar owner read has
/// coalesced back to A. Observe every actual auth-owner emission so no cached
/// display or in-flight authority read is reused from the retired visit.
final verifiedEntitlementOwnerVisitProvider =
    NotifierProvider<VerifiedEntitlementOwnerVisit, int>(
      VerifiedEntitlementOwnerVisit.new,
    );

final class VerifiedEntitlementOwnerVisit extends Notifier<int> {
  @override
  int build() {
    var previous = ref.read(verifiedEntitlementOwnerSeedProvider);
    // Keep only identity events observed when every route goes offscreen.
    // A paused stream can buffer A -> B -> A until after a synchronous tap.
    final identity = ref.container.listen(verifiedEntitlementOwnerProvider, (
      _,
      next,
    ) {
      if (next.hasError) {
        state += 1;
        return;
      }
      if (!next.hasValue || next.isLoading) return;
      final owner = next.value;
      if (owner == previous) return;
      previous = owner;
      state += 1;
    });
    ref.onDispose(identity.close);
    return 0;
  }
}

/// Owner-scoped memory of a store receipt that the server has proved belongs
/// to another BIL account. This is presentation state only: the backend remains
/// the entitlement authority. Keeping it above the plans route prevents closing
/// and reopening that route from re-enabling a second purchase attempt.
final class PurchaseOwnershipConflictStore {
  final Set<BilStoreProductKind> _blockedKinds = <BilStoreProductKind>{};

  bool get blocked => _blockedKinds.isNotEmpty;
  Set<BilStoreProductKind> get blockedKinds =>
      Set<BilStoreProductKind>.unmodifiable(_blockedKinds);

  bool blockedFor(BilStoreProductKind kind) => _blockedKinds.contains(kind);

  void recordConflict(String? productId) {
    final kind = _kindForProduct(productId);
    if (kind != null) _blockedKinds.add(kind);
  }

  void clearAfterVerifiedOwnership(String? productId) {
    final kind = _kindForProduct(productId);
    if (kind != null) _blockedKinds.remove(kind);
  }

  BilStoreProductKind? _kindForProduct(String? productId) {
    if (productId == null || productId.isEmpty) return null;
    if (productId == StoreCatalogConfiguration.aiBoost) {
      return BilStoreProductKind.aiBoostConsumable;
    }
    final binding = StoreCatalogConfiguration.bindingForProduct(productId);
    return switch (binding?.plan) {
      CommercePlan.premium => BilStoreProductKind.premiumSubscription,
      CommercePlan.premiumAiCoach =>
        BilStoreProductKind.premiumAiCoachSubscription,
      _ => null,
    };
  }
}

final purchaseOwnershipConflictStoreProvider =
    Provider<PurchaseOwnershipConflictStore>((ref) {
      // A different signed-in BIL owner receives a fresh state. Route disposal,
      // catalog refresh, cancellation, and ordinary store errors do not clear it.
      ref.watch(verifiedEntitlementOwnerIdProvider);
      return PurchaseOwnershipConflictStore();
    });

final verifiedEntitlementLoaderProvider =
    Provider<Future<SubscriptionState> Function()>(
      (_) => const ServerEntitlementRepository().current,
    );

/// Avoids the extra lifecycle transition assumptions of
/// AppLifecycleListener. Each observed verification owns exactly one listener
/// that is removed when Riverpod invalidates or disposes that generation.
final class _VerifiedCommerceResumeObserver with WidgetsBindingObserver {
  _VerifiedCommerceResumeObserver(this.onResumed);

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}

/// Starts a non-overlapping refresh after a load finishes and only while its
/// provider is observed. Credit access must refresh independently of Premium.
void Function() _observedAuthorityReload(
  Ref ref,
  void Function() reload, {
  void Function()? resumeReload,
  Duration Function()? refreshDelay,
}) {
  Timer? refresh;
  var disposed = false;
  var observed = true;
  var loaded = false;
  // A resumed Play/TestFlight process must immediately refresh its
  // server-owned rights and credits; background-paused timers can be stale.
  // Auth owner changes continue to invalidate separately via Riverpod.
  // Headless Riverpod consumers (including entitlement policy tests) do not
  // install a Flutter WidgetsBinding. Keep their 30-second refresh operational
  // without assuming that an application lifecycle exists.
  WidgetsBinding? binding;
  try {
    binding = WidgetsBinding.instance;
  } on FlutterError {
    // Headless Riverpod tests have no WidgetsBinding. Keep the periodic and
    // owner-triggered verified refreshes without a Flutter lifecycle observer.
  }
  _VerifiedCommerceResumeObserver? appLifecycle;
  if (binding != null) {
    appLifecycle = _VerifiedCommerceResumeObserver(() {
      // QA-only trace contains no user identifiers, credits, or tokens. A
      // lifecycle event does not by itself establish account entitlement.
      if (disposed || !observed || !loaded) return;
      refresh?.cancel();
      (resumeReload ?? reload)();
    });
    binding.addObserver(appLifecycle);
  }
  ref.onDispose(() {
    if (binding != null && appLifecycle != null) {
      binding.removeObserver(appLifecycle);
    }
  });
  void schedule() {
    refresh?.cancel();
    refresh = Timer(
      refreshDelay?.call() ?? const Duration(seconds: 30),
      reload,
    );
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

/// A local read identity, containing no entitlement or user data. Riverpod may
/// forward one pending `.future` through several refreshes, so display-only
/// consumers cannot use Future identity to identify a genuinely new read.
final class VerifiedSubscriptionReadWitness {
  int _generation = 0;
  int get generation => _generation;
  void begin() => _generation += 1;
}

final verifiedSubscriptionReadWitnessProvider =
    Provider<VerifiedSubscriptionReadWitness>(
      (_) => VerifiedSubscriptionReadWitness(),
    );

final verifiedSubscriptionStateProvider = FutureProvider<SubscriptionState>((
  ref,
) async {
  final ownerId = ref.watch(verifiedEntitlementOwnerIdProvider);
  final ownerVisit = ref.watch(verifiedEntitlementOwnerVisitProvider);
  final canonical = ref.watch(_verifiedSubscriptionCanonicalSnapshotProvider);
  final loaded = _observedAuthorityReload(ref, ref.invalidateSelf);
  final witness = ref.read(verifiedSubscriptionReadWitnessProvider)..begin();
  final generation = witness.generation;
  bool currentVisit() =>
      ref.mounted &&
      witness.generation == generation &&
      ref.read(verifiedEntitlementOwnerIdProvider) == ownerId &&
      ref.read(verifiedEntitlementOwnerVisitProvider) == ownerVisit &&
      identical(
        canonical,
        ref.read(_verifiedSubscriptionCanonicalSnapshotProvider),
      );
  ref.listen(verifiedEntitlementOwnerProvider, (_, next) {
    if (next.hasError && currentVisit()) canonical.verified = null;
  });
  try {
    final loader = ref.watch(verifiedEntitlementLoaderProvider);
    final state = await loader();
    // The authority owns this observation, not an auto-disposed route. A
    // denial received while no access consumer exists must retire old proof
    // before a later pending/error read can reopen that route.
    if (currentVisit() &&
        !ref.read(verifiedEntitlementOwnerProvider).hasError) {
      canonical.observe(state);
    }
    return state;
  } on Object catch (error) {
    if (isVerifiedCommerceSessionInvalid(error) && currentVisit()) {
      canonical.verified = null;
    }
    rethrow;
  } finally {
    loaded();
  }
});

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
/// A new store for every owner transition, including sign-out. Pending work
/// from an earlier session cannot populate the new session's continuity cache.
final aiCoachAccessSnapshotStoreProvider = Provider<AiCoachAccessSnapshotStore>(
  (ref) {
    ref.watch(verifiedEntitlementOwnerIdProvider);
    ref.watch(verifiedEntitlementOwnerVisitProvider);
    return AiCoachAccessSnapshotStore();
  },
);

final aiCoachCreditAccessProvider = FutureProvider<bool>((ref) async {
  final ownerId = ref.watch(verifiedEntitlementOwnerIdProvider);
  final ownerVisit = ref.watch(verifiedEntitlementOwnerVisitProvider);
  final ownerError = ref.watch(
    verifiedEntitlementOwnerProvider.select((owner) => owner.hasError),
  );
  final snapshot = ref.watch(aiCoachAccessSnapshotStoreProvider);
  ref.watch(aiCoachUsageRefreshProvider);
  // The auth stream already filters proven same-session transport failures.
  // A remaining error cannot authorize a balance read against the old seed.
  if (ownerId == null || ownerError) return false;
  final generation = ++snapshot.generation;
  snapshot.usageResponseFresh = false;
  snapshot.prepaidProof = null;
  var active = true;
  ref.onDispose(() => active = false);
  bool current() => active && generation == snapshot.generation;
  // Freshness is bounded by when this request began, not when a delayed
  // response arrived. Owner/generation checks still retire old requests.
  final clock = ref.read(verifiedEntitlementClockProvider);
  final requestedAt = clock().toUtc();
  final loaded = _observedAuthorityReload(
    ref,
    () {
      final usageRefresh = ref.read(aiCoachUsageRefreshProvider.notifier);
      usageRefresh.requestAuthoritativeReload();
    },
    // Refresh the observed Coach access itself on app resume, rather than
    // relying on a broadcast signal whose notification can be coalesced with
    // an in-flight owner/permission refresh.
    resumeReload: ref.invalidateSelf,
    refreshDelay: () {
      final now = clock().toUtc();
      final remaining =
          VerifiedPrepaidAiCredit.maximumAge - now.difference(requestedAt);
      if (remaining > VerifiedPrepaidAiCredit.maximumAge) {
        return VerifiedPrepaidAiCredit.maximumAge;
      }
      return remaining.isNegative ? Duration.zero : remaining;
    },
  );
  // Only a successful server response creates access. Retain the same owner's
  // last verified positive result on transient failure; a previous zero is not
  // evidence of a fresh denial after a failed check.
  try {
    final value = await ref
        .read(aiCoachUsageStatusLoaderProvider)()
        .timeout(const Duration(seconds: 10));
    if (!current()) throw StateError('ai_usage_status_superseded');
    final access = verifiedAiCoachAccessFromUsageStatus(value);
    if (access == null) throw StateError('ai_usage_status_unavailable');
    snapshot.verifiedAccess = access;
    snapshot.prepaidProof = VerifiedPrepaidAiCredit.fromUsageStatus(
      value,
      ownerId: ownerId,
      ownerVisit: ownerVisit,
      generation: generation,
      requestedAt: requestedAt,
    );
    snapshot.verifiedUsagePlan =
        value is Map && const {'free', 'ai_coach'}.contains(value['plan'])
        ? value['plan'] as String
        : null;
    snapshot.usageRequestedAt = requestedAt;
    snapshot.usageObservedAt = ref
        .read(verifiedEntitlementClockProvider)()
        .toUtc();
    snapshot.usageResponseFresh = true;
    return access;
  } on Object {
    // A disposed/older load cannot borrow continuity from a later generation.
    if (!current()) rethrow;
    final retained = snapshot.verifiedAccess;
    if (retained == true) return true;
    rethrow;
  } finally {
    loaded();
  }
}, retry: (_, _) => null);

/// Meal-photo analysis uses the same shared BIL AI Token balance as AI Coach.
/// The server reports a reserved-aware total, so the client never unlocks a
/// request from a stale local purchase callback or a plan label alone.
enum AiVisionCreditState { available, insufficient, unavailable }

final aiVisionCreditStateProvider = FutureProvider<AiVisionCreditState>((
  ref,
) async {
  final owner = ref.watch(verifiedEntitlementOwnerIdProvider);
  ref.watch(aiCoachUsageRefreshProvider);
  var active = true;
  ref.onDispose(() => active = false);
  if (owner == null || !AppEnvironment.supabaseRuntimeReady) {
    return AiVisionCreditState.unavailable;
  }
  try {
    final client = Supabase.instance.client;
    if (client.auth.currentUser?.id != owner) {
      return AiVisionCreditState.unavailable;
    }
    final value = await client
        .rpc('bil_get_ai_usage_status')
        .timeout(const Duration(seconds: 8));
    if (!active || client.auth.currentUser?.id != owner || value is! Map) {
      return AiVisionCreditState.unavailable;
    }
    final credits = value['credits'];
    if (credits is! Map) return AiVisionCreditState.unavailable;
    final remaining = credits['total_remaining'];
    if (remaining is! num || !remaining.isFinite || remaining < 0) {
      return AiVisionCreditState.unavailable;
    }
    return remaining >= 100
        ? AiVisionCreditState.available
        : AiVisionCreditState.insufficient;
  } on Object {
    return AiVisionCreditState.unavailable;
  }
}, retry: (_, _) => null);

final aiBoostVisionAccessProvider = FutureProvider<bool>((ref) async {
  ref.watch(verifiedEntitlementOwnerIdProvider);
  return await ref.watch(aiVisionCreditStateProvider.future) ==
      AiVisionCreditState.available;
});

/// Injectable read-only SDK/config boundaries; production defaults are fixed.
final storefrontPurchaseClientProvider = Provider<InAppPurchase>(
  (_) => InAppPurchase.instance,
);
final storefrontCatalogConfiguredProvider = Provider<bool>(
  (_) => AppEnvironment.commerceConfigured,
);

/// Billing country comes from StoreKit/Play, never locale or profile data.
/// Each owner visit retires pending reads, including A -> B -> A.
final storefrontTargetPlanProvider = FutureProvider<CommercePlan?>((ref) async {
  final ownerVisit = ref.watch(verifiedEntitlementOwnerVisitProvider);
  final owner = ref.watch(verifiedEntitlementOwnerIdProvider);
  bool current() =>
      ref.mounted &&
      ref.read(verifiedEntitlementOwnerVisitProvider) == ownerVisit &&
      ref.read(verifiedEntitlementOwnerIdProvider) == owner;
  // No polling: only a visible consumer's actual app resume requests a new
  // ephemeral storefront read. A FutureProvider refresh keeps its last value
  // until the new catalog settles; it never starts checkout or grants access.
  var observed = true;
  ref.onCancel(() => observed = false);
  ref.onResume(() {
    observed = true;
  });
  WidgetsBinding? binding;
  try {
    binding = WidgetsBinding.instance;
  } on FlutterError {
    /* Headless. */
  }
  final lifecycleBinding = binding;
  if (lifecycleBinding != null) {
    final observer = _VerifiedCommerceResumeObserver(() {
      if (observed && ref.mounted) ref.invalidateSelf();
    });
    lifecycleBinding.addObserver(observer);
    ref.onDispose(() => lifecycleBinding.removeObserver(observer));
  }
  if (!ref.watch(storefrontCatalogConfiguredProvider)) return null;
  final store = ref.watch(storefrontPurchaseClientProvider);
  if (!await store.isAvailable() || !current()) return null;
  Future<String?> readCountry() async {
    try {
      return StorefrontMarketPolicy.normalizeCountry(
        await store.countryCode().timeout(const Duration(seconds: 4)),
      );
    } on Object {
      // Unknown retains the conservative query-only behavior, never a grant.
      return null;
    }
  }

  final country = await readCountry();
  if (!current() || StorefrontMarketPolicy.isHeld(country)) return null;
  final response = await store.queryProductDetails(
    StorefrontMarketPolicy.productIds(
      StoreCatalogConfiguration.productIds,
      country,
    ),
  );
  if (!current() || response.error != null) return null;
  final afterCountry = await readCountry();
  if (!current() || afterCountry != country) return null;
  final kinds = response.productDetails
      .where(
        (product) => StorefrontMarketPolicy.allowsProduct(product.id, country),
      )
      .map((product) {
        final plan = StoreCatalogConfiguration.bindingForProduct(
          product.id,
        )?.plan;
        return plan == CommercePlan.premiumAiCoach
            ? BilStoreProductKind.premiumAiCoachSubscription
            : plan == CommercePlan.premium
            ? BilStoreProductKind.premiumSubscription
            : null;
      })
      .whereType<BilStoreProductKind>();
  return MarketOfferPolicy.targetPlanForKinds(kinds);
});
