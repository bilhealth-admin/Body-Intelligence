import 'commerce_entitlement.dart';
import 'commerce_plan.dart';
import 'paid_plan_catalog.dart';
import 'subscription_lifecycle.dart';
import 'subscription_provider.dart';

/// Source of an entitlement decision for the current app session.
enum EntitlementAuthority {
  /// Deterministic local default shipped with the application.
  localDefault,

  /// Reserved for a future server-verified commerce adapter.
  verifiedServer,
}

/// Immutable commercial access snapshot consumed by product surfaces.
final class SubscriptionState {
  SubscriptionState({
    required this.plan,
    required Set<CommerceEntitlement> entitlements,
    required this.authority,
    required this.isPurchasable,
    required this.canRestorePurchases,
    this.lifecycle = SubscriptionLifecycle.active,
    this.provider,
    this.startedAt,
    this.currentPeriodEndsAt,
    this.trialEndsAt,
    this.gracePeriodEndsAt,
    this.verifiedAt,
    this.serverRevision,
    this.storeOriginalTransactionId,
    this.verifiedNextPeriod,
  }) : entitlements = Set.unmodifiable(entitlements) {
    if (authority == EntitlementAuthority.localDefault &&
        (isPurchasable || canRestorePurchases)) {
      throw ArgumentError(
        'Local default commerce state cannot advertise purchase or restore.',
      );
    }
    if (authority == EntitlementAuthority.localDefault &&
        plan != CommercePlan.free) {
      throw ArgumentError('Local default authority cannot grant a paid plan.');
    }
  }

  final CommercePlan plan;
  final Set<CommerceEntitlement> entitlements;
  final EntitlementAuthority authority;
  final SubscriptionLifecycle lifecycle;
  final SubscriptionProvider? provider;
  final DateTime? startedAt;
  final DateTime? currentPeriodEndsAt;
  final DateTime? trialEndsAt;
  final DateTime? gracePeriodEndsAt;
  final DateTime? verifiedAt;
  final int? serverRevision;
  final String? storeOriginalTransactionId;

  /// An already verified, contiguous renewal. Its entitlements are not part of
  /// this period and may only be used at or after its own [startedAt]. This is
  /// session memory only; encrypted continuity never persists future rights.
  final SubscriptionState? verifiedNextPeriod;
  final bool isPurchasable;
  final bool canRestorePurchases;

  bool grants(CommerceEntitlement entitlement) =>
      entitlements.contains(entitlement);

  SubscriptionState withVerifiedNextPeriod(SubscriptionState? next) {
    final retiredBoundary = next == null
        ? verifiedSubscriptionPriorBoundary(this)
        : null;
    return SubscriptionState(
      plan: plan,
      entitlements: entitlements,
      authority: authority,
      lifecycle: lifecycle,
      provider: provider,
      startedAt: startedAt,
      currentPeriodEndsAt:
          lifecycle == SubscriptionLifecycle.active ||
              lifecycle == SubscriptionLifecycle.cancelled
          ? retiredBoundary ?? currentPeriodEndsAt
          : currentPeriodEndsAt,
      trialEndsAt: lifecycle == SubscriptionLifecycle.trial
          ? retiredBoundary ?? trialEndsAt
          : trialEndsAt,
      gracePeriodEndsAt: lifecycle == SubscriptionLifecycle.gracePeriod
          ? retiredBoundary ?? gracePeriodEndsAt
          : gracePeriodEndsAt,
      verifiedAt: verifiedAt,
      serverRevision: serverRevision,
      storeOriginalTransactionId: storeOriginalTransactionId,
      verifiedNextPeriod: next,
      isPurchasable: isPurchasable,
      canRestorePurchases: canRestorePurchases,
    );
  }
}

DateTime? verifiedSubscriptionBoundary(SubscriptionState state) =>
    switch (state.lifecycle) {
      SubscriptionLifecycle.trial => state.trialEndsAt,
      SubscriptionLifecycle.gracePeriod => state.gracePeriodEndsAt,
      SubscriptionLifecycle.active ||
      SubscriptionLifecycle.cancelled => state.currentPeriodEndsAt,
      _ => null,
    };

/// Selects only a verified renewal whose own interval has begun. In
/// particular, this never joins a gap or lends the renewal's end to the old
/// period. Recheck the interval here as well as at the repository boundary.
SubscriptionState verifiedSubscriptionPeriodAt(
  SubscriptionState state,
  DateTime now,
) {
  final next = state.verifiedNextPeriod;
  final oldEnd = verifiedSubscriptionBoundary(state)?.toUtc();
  final start = next?.startedAt?.toUtc();
  final end = next == null ? null : verifiedSubscriptionBoundary(next)?.toUtc();
  if (state.authority != EntitlementAuthority.verifiedServer ||
      state.plan == CommercePlan.free ||
      next?.authority != EntitlementAuthority.verifiedServer ||
      next?.provider != state.provider ||
      next?.plan == CommercePlan.free ||
      oldEnd == null ||
      start == null ||
      start.isAfter(oldEnd) ||
      start.isAfter(now.toUtc()) ||
      end == null ||
      !end.isAfter(start) ||
      (!sameVerifiedStoreLineage(state, next!) && !end.isAfter(now.toUtc()))) {
    return state;
  }
  if (!sameVerifiedStoreLineage(state, next) &&
      oldEnd.isAfter(now.toUtc()) &&
      !(state.startedAt?.toUtc().isAfter(now.toUtc()) ?? false) &&
      PaidPlanCatalog.entryFor(state.plan).rank >=
          PaidPlanCatalog.entryFor(next.plan).rank) {
    // An independent lower/equal tier cannot replace a still-valid stronger
    // lease. Same-lineage replacements may legitimately downgrade at start.
    return state;
  }
  return next;
}

bool sameVerifiedStoreLineage(
  SubscriptionState first,
  SubscriptionState second,
) =>
    first.provider != null &&
    first.provider == second.provider &&
    first.storeOriginalTransactionId != null &&
    first.storeOriginalTransactionId == second.storeOriginalTransactionId;

/// Only an explicitly identified replacement may cap the old store lease.
/// Another chain/provider and independent admin grants remain additive.
DateTime? verifiedSubscriptionPriorBoundary(SubscriptionState state) {
  final boundary = verifiedSubscriptionBoundary(state)?.toUtc();
  final next = state.verifiedNextPeriod;
  final start = next?.startedAt?.toUtc();
  if (boundary == null ||
      next == null ||
      start == null ||
      !sameVerifiedStoreLineage(state, next) ||
      !identical(verifiedSubscriptionPeriodAt(state, start), next)) {
    return boundary;
  }
  return start.isBefore(boundary) ? start : boundary;
}
