import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/commerce_plan.dart';
import 'commerce_providers.dart';
import '../domain/subscription_lifecycle.dart';
import '../domain/subscription_state.dart';
import '../domain/subscription_provider.dart';

final verifiedPurchaseHandoffProvider =
    NotifierProvider<VerifiedPurchaseHandoff, SubscriptionState?>(
      VerifiedPurchaseHandoff.new,
    );

/// A bounded UI handoff of an already-read canonical server row. It creates
/// no entitlement and never extends the row's actual lifecycle boundary.
class VerifiedPurchaseHandoff extends Notifier<SubscriptionState?> {
  Timer? _expiry;
  @override
  SubscriptionState? build() {
    ref.watch(verifiedEntitlementOwnerIdProvider);
    _expiry?.cancel();
    ref.onDispose(() => _expiry?.cancel());
    return null;
  }

  void publish(SubscriptionState? value) {
    _expiry?.cancel();
    if (value == null ||
        value.authority != EntitlementAuthority.verifiedServer ||
        value.verifiedAt == null) {
      state = null;
      return;
    }
    state = value;
    if (value.plan != CommercePlan.free) {
      _expiry = Timer(const Duration(minutes: 2), () => state = null);
    }
  }

  void retire() => publish(null);
}

AsyncValue<SubscriptionState> purchaseHandoffView(
  AsyncValue<SubscriptionState> read,
  SubscriptionState? handoff,
  DateTime now,
) {
  if (handoff == null) return read;
  final current = read.asData?.value ?? (read.isRefreshing ? read.value : null);
  bool independentGrant() =>
      current?.authority == EntitlementAuthority.verifiedServer &&
      current != null &&
      current.plan != CommercePlan.free &&
      current.provider != SubscriptionProvider.apple &&
      current.provider != SubscriptionProvider.google &&
      current.currentPeriodEndsAt?.isAfter(now) == true;
  if (handoff.plan == CommercePlan.free) {
    if (independentGrant()) return AsyncValue.data(current!);
    // Store revocation is not evidence about an unreadable independent grant.
    // Fail closed with Checking/Retry, never an invented Free upsell.
    if (read.isLoading) return const AsyncValue.loading();
    if (read.hasError) return AsyncValue.error(read.error!, read.stackTrace!);
    if (current?.authority != EntitlementAuthority.verifiedServer) return read;
    if (current?.verifiedAt != null &&
        !current!.verifiedAt!.isBefore(handoff.verifiedAt!)) {
      return read;
    }
    return AsyncValue.data(handoff);
  }
  final end = switch (handoff.lifecycle) {
    SubscriptionLifecycle.trial => handoff.trialEndsAt,
    SubscriptionLifecycle.gracePeriod => handoff.gracePeriodEndsAt,
    SubscriptionLifecycle.active ||
    SubscriptionLifecycle.cancelled => handoff.currentPeriodEndsAt,
    _ => null,
  };
  if (end == null || !end.isAfter(now)) return read;
  // Preserve an independently verified higher grant; store and administration
  // are additive authorities, not interchangeable roles.
  if (independentGrant() &&
      current?.plan == CommercePlan.premiumAiCoach &&
      handoff.plan == CommercePlan.premium) {
    return read;
  }
  if (current?.verifiedAt != null &&
      !current!.verifiedAt!.isBefore(handoff.verifiedAt!)) {
    return read;
  }
  return AsyncValue.data(handoff);
}
