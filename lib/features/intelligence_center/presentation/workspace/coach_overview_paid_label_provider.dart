import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../commerce/domain/commerce_entitlement.dart';
import '../../../commerce/domain/commerce_plan.dart';
import '../../../commerce/domain/subscription_lifecycle.dart';
import '../../../commerce/domain/subscription_state.dart';
import '../../../commerce/providers/commerce_providers.dart';

/// Presentation continuity uses the same Overview owner-visit memory as the
/// badge. This never grants a route, a token, or a server operation.
final coachOverviewCreditAccessProvider = Provider.autoDispose<bool>((ref) {
  ref.watch(_paidLabelMemoryProvider);
  final memory = ref.read(_paidLabelMemoryProvider.notifier);
  final owner = ref.watch(verifiedEntitlementOwnerIdProvider);
  final ownerSnapshot = ref.watch(verifiedEntitlementOwnerProvider);
  if (memory.owner != owner) {
    memory.retire(owner);
  }
  if (owner == null || ownerSnapshot.hasError) return false;
  final source = ref.watch(aiCoachCreditAccessProvider);
  final future = ref.watch(aiCoachCreditAccessProvider.future);
  final store = ref.read(aiCoachAccessSnapshotStoreProvider);
  memory.observedCreditStore = store;
  memory.observedCreditFuture = future;
  future.ignore();
  final currentRead = store.generation > 0
      ? !identical(store, memory.retiredCreditStore) ||
            store.generation > memory.retiredCreditGeneration
      : !memory.retiredCreditFutures.contains(future);
  if (!source.isLoading && !source.hasError && currentRead) {
    memory.creditAccess = source.asData?.value == true;
    memory.acceptedCreditFuture = future;
    memory.retiredCreditFutures.clear();
  }
  return memory.creditAccess == true;
});

/// The Overview label follows the same bounded server proof as paid access.
/// Independent Boost credits retain their own presentation semantics above.
final coachOverviewPaidLabelProvider = Provider.autoDispose<CommercePlan?>((
  ref,
) {
  final owner = ref.watch(verifiedEntitlementOwnerIdProvider);
  ref.watch(verifiedEntitlementOwnerVisitProvider);
  final ownerSnapshot = ref.watch(verifiedEntitlementOwnerProvider);
  if (owner == null || ownerSnapshot.hasError) return null;
  final access = ref.watch(verifiedSubscriptionAccessProvider);
  final now = ref.watch(verifiedEntitlementClockProvider)().toUtc();
  final lease = access.asData?.value;
  if (access.isLoading ||
      access.hasError ||
      lease == null ||
      !_isPaidLease(lease, now)) {
    return null;
  }
  final expiry = Timer(
    _leaseEnd(lease)!.toUtc().difference(now),
    ref.invalidateSelf,
  );
  ref.onDispose(expiry.cancel);
  return lease.plan;
});

DateTime? _leaseEnd(SubscriptionState state) => switch (state.lifecycle) {
  SubscriptionLifecycle.trial => state.trialEndsAt,
  SubscriptionLifecycle.active ||
  SubscriptionLifecycle.cancelled => state.currentPeriodEndsAt,
  SubscriptionLifecycle.gracePeriod => state.gracePeriodEndsAt,
  _ => null,
};

bool _isPaidLease(SubscriptionState state, DateTime now) =>
    state.authority == EntitlementAuthority.verifiedServer &&
    state.plan != CommercePlan.free &&
    state.grants(CommerceEntitlement.advancedIntelligence) &&
    (_leaseEnd(state)?.toUtc().isAfter(now) ?? false) &&
    !(state.startedAt?.toUtc().isAfter(now) ?? false);

// Credit presentation memory observes auth boundaries, not subscription/quota
// providers, so a hidden Overview adds no continuing quota poll.
final _paidLabelMemoryProvider = NotifierProvider<_PaidLabelMemory, int>(
  _PaidLabelMemory.new,
);

class _PaidLabelMemory extends Notifier<int> {
  String? owner;
  SubscriptionState? lease;
  Future<SubscriptionState>? acceptedFuture;
  Future<SubscriptionState>? observedFuture;
  final retiredFutures = <Future<SubscriptionState>>{};
  int retiredSubscriptionGeneration = -1;
  bool? creditAccess;
  Future<bool>? observedCreditFuture;
  Future<bool>? acceptedCreditFuture;
  final retiredCreditFutures = <Future<bool>>{};
  AiCoachAccessSnapshotStore? retiredCreditStore;
  AiCoachAccessSnapshotStore? observedCreditStore;
  int retiredCreditGeneration = -1;

  @override
  int build() {
    owner = ref.read(verifiedEntitlementOwnerIdProvider);
    ref.listen<AsyncValue<String?>>(verifiedEntitlementOwnerProvider, (
      _,
      next,
    ) {
      if (next.hasError || (next.hasValue && next.value != owner)) {
        retire(next.hasError ? null : next.value);
        state += 1;
        // A delivered account visit retires the existing source's continuity
        // store too, including A -> B -> A within one rendered frame.
        ref.invalidate(aiCoachAccessSnapshotStoreProvider);
      }
    });
    return 0;
  }

  void retire(String? nextOwner) {
    owner = nextOwner;
    lease = null;
    retiredSubscriptionGeneration = ref
        .read(verifiedSubscriptionReadWitnessProvider)
        .generation;
    retiredFutures.clear();
    if (acceptedFuture != null) {
      retiredFutures.add(acceptedFuture!);
    }
    if (observedFuture != null) {
      retiredFutures.add(observedFuture!);
    }
    creditAccess = null;
    // Do not read an owner-dependent provider inside the auth listener: that
    // could flush an intermediate account and start extra verification calls.
    retiredCreditStore = observedCreditStore;
    retiredCreditGeneration = retiredCreditStore?.generation ?? -1;
    retiredCreditFutures.clear();
    if (observedCreditFuture != null) {
      retiredCreditFutures.add(observedCreditFuture!);
    }
    if (acceptedCreditFuture != null) {
      retiredCreditFutures.add(acceptedCreditFuture!);
    }
  }

  void accept(SubscriptionState? nextLease, Future<SubscriptionState> source) {
    lease = nextLease;
    acceptedFuture = source;
    retiredFutures.clear();
  }
}
