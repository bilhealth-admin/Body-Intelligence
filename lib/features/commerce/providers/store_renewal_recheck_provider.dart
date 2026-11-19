import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/security/bil_mobile_integrity_service.dart';
import '../../community/services/community_owner_operation.dart';
import '../domain/commerce_plan.dart';
import '../domain/store_renewal_observation.dart';
import '../domain/subscription_state.dart';
import 'commerce_providers.dart';

typedef OwnSubscriptionRefresh = Future<void> Function();
typedef OwnSubscriptionIntegrityProtector =
    Future<Map<String, Object?>> Function({
      required String action,
      required Map<String, Object?> payload,
    });
final ownSubscriptionIntegrityProtectorProvider =
    Provider<OwnSubscriptionIntegrityProtector>(
      (_) => BilMobileIntegrityService.instance.protect,
    );

/// Quiet, purpose-bound truth refresh. Never opens a Store UI, repairs a
/// license, forwards a receipt, or treats a response as commercial authority.
final ownSubscriptionRefreshProvider = Provider<OwnSubscriptionRefresh>((ref) {
  final owner = ref.watch(verifiedEntitlementOwnerIdProvider);
  final visit = ref.watch(verifiedEntitlementOwnerVisitProvider);
  final protect = ref.watch(ownSubscriptionIntegrityProtectorProvider);
  bool current() =>
      ref.mounted &&
      ref.read(verifiedEntitlementOwnerIdProvider) == owner &&
      ref.read(verifiedEntitlementOwnerVisitProvider) == visit;
  return () async {
    if (owner == null || !current()) return;
    final client = Supabase.instance.client;
    if (client.auth.currentUser?.id != owner) return;
    await CommunityOwnerOperation.run(
      client: client,
      ownerId: owner,
      // Pure snapshot comparison: never call a zone-aware check recursively.
      isCurrentOwner: current,
      action: (operation) async {
        final body = await protect(
          action: 'store.refresh_subscription',
          payload: const {'action': 'refresh_subscription'},
        ).timeout(const Duration(seconds: 12));
        operation.check();
        await client.functions
            .invoke('verify-store-purchase', body: body)
            .timeout(const Duration(seconds: 10));
        operation.check();
      },
    );
  };
});

class _RenewalDisplayMemory {
  StoreRenewalObservation? last;
}

final _renewalDisplayMemoryProvider = Provider<_RenewalDisplayMemory>((ref) {
  ref.watch(verifiedEntitlementOwnerIdProvider);
  ref.watch(verifiedEntitlementOwnerVisitProvider);
  return _RenewalDisplayMemory();
});

/// Retains only this visit's display observation; no previous AsyncValue from
/// an owner dependency reload can seed a newly mounted member's screen.
final storeRenewalObservationProvider = Provider<StoreRenewalObservation?>((
  ref,
) {
  final owner = ref.watch(verifiedEntitlementOwnerIdProvider);
  ref.watch(verifiedEntitlementOwnerVisitProvider);
  final memory = ref.watch(_renewalDisplayMemoryProvider);
  final source = ref.watch(verifiedSubscriptionStateProvider);
  if (owner == null || (source.isLoading && !source.isRefreshing)) return null;
  if (!source.isLoading &&
      !source.hasError &&
      source.value?.authority == EntitlementAuthority.verifiedServer &&
      (source.value?.storeRenewalDefinitivelyInactive == true ||
          (source.value?.plan != CommercePlan.free &&
              source.value?.storeRenewalObservation == null))) {
    memory.last = null;
    return null;
  }
  final hint = source.value?.storeRenewalObservation;
  if (!source.hasError && hint?.ownerId == owner) memory.last = hint;
  final retained = memory.last;
  final now = ref.watch(verifiedEntitlementClockProvider)().toUtc();
  final futureStart = retained?.periodStart?.toUtc();
  if (futureStart != null && futureStart.isAfter(now)) {
    final timer = Timer(futureStart.difference(now), () {
      if (!ref.mounted) return;
      ref.invalidate(verifiedSubscriptionStateProvider);
      ref.invalidate(aiCoachCreditAccessProvider);
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
  }
  return retained?.ownerId == owner ? retained : null;
});

final storeRenewalPresentationPendingProvider = Provider.autoDispose<bool>((
  ref,
) {
  final hint = ref.watch(storeRenewalObservationProvider);
  final now = ref.watch(verifiedEntitlementClockProvider)().toUtc();
  final access = ref.watch(verifiedSubscriptionAccessProvider);
  final pending =
      hint?.pendingAt(now) == true &&
      (access.isLoading ||
          access.hasError ||
          access.value?.plan == CommercePlan.free);
  if (pending) ref.watch(storeRenewalRecheckProvider).begin(hint!);
  return pending;
});

final storeRenewalRecheckProvider = Provider<StoreRenewalReadBurst>((ref) {
  final owner = ref.watch(verifiedEntitlementOwnerIdProvider);
  final visit = ref.watch(verifiedEntitlementOwnerVisitProvider);
  final reconcile = ref.watch(ownSubscriptionRefreshProvider);
  final burst = StoreRenewalReadBurst(
    ownerId: owner,
    now: () => ref.read(verifiedEntitlementClockProvider)().toUtc(),
    current: () =>
        ref.mounted &&
        ref.read(verifiedEntitlementOwnerIdProvider) == owner &&
        ref.read(verifiedEntitlementOwnerVisitProvider) == visit,
    relevant: (hint) =>
        ref.read(storeRenewalObservationProvider)?.periodKey == hint.periodKey,
    loading: () => ref.read(verifiedSubscriptionStateProvider).isLoading,
    refresh: () {
      ref.invalidate(verifiedSubscriptionStateProvider);
      ref.invalidate(aiCoachCreditAccessProvider);
    },
    reconcile: reconcile,
  );
  ref.listen(verifiedSubscriptionStateProvider, (previous, next) {
    final oldKey = previous?.value?.storeRenewalObservation?.periodKey;
    final newHint = next.value?.storeRenewalObservation;
    if (!next.isLoading &&
        !next.hasError &&
        newHint != null &&
        newHint.hadAiAllowance &&
        newHint.periodKey != oldKey) {
      // A quota read started before canonical renewal may still report Free.
      // Resolve that race with one fresh quota read after the new period lands.
      ref.invalidate(aiCoachCreditAccessProvider);
    }
  });
  ref.onDispose(burst.dispose);
  return burst;
});

/// Bounded read scheduling only. The previous 30-second observed authority
/// reload remains unchanged; no Billing/receipt replay or paid action runs.
class StoreRenewalReadBurst extends ChangeNotifier {
  StoreRenewalReadBurst({
    required this.ownerId,
    required this.now,
    required this.current,
    required this.relevant,
    required this.loading,
    required this.refresh,
    this.reconcile,
  });
  final String? ownerId;
  final DateTime Function() now;
  final bool Function() current;
  final bool Function(StoreRenewalObservation) relevant;
  final bool Function() loading;
  final VoidCallback refresh;
  final OwnSubscriptionRefresh? reconcile;
  final _periods = <String, _StoreRenewalReadPeriod>{};
  bool _disposed = false;

  void begin(StoreRenewalObservation hint) {
    if (_disposed ||
        !current() ||
        hint.ownerId != ownerId ||
        !hint.pendingAt(now()) ||
        _periods.containsKey(hint.periodKey)) {
      return;
    }
    if (_periods.length >= 16) _periods.remove(_periods.keys.first)!.retire();
    final period = _StoreRenewalReadPeriod();
    _periods[hint.periodKey] = period;
    for (final seconds in [0, 2, 5, 10, 20]) {
      late final Timer timer;
      timer = Timer(Duration(seconds: seconds), () {
        period.timers.remove(timer);
        if (!_eligible(hint)) return;
        if (seconds % 10 == 0 && reconcile != null && !period.reconciling) {
          unawaited(_reconcile(period, hint));
        } else if (!loading()) {
          refresh();
        }
      });
      period.timers.add(timer);
    }
    period.timers.add(
      Timer(const Duration(seconds: 25), () {
        if (_disposed || !current()) return;
        period.retire();
        period.timedOut = true;
        notifyListeners();
      }),
    );
  }

  bool _eligible(StoreRenewalObservation hint) =>
      !_disposed && current() && relevant(hint);
  Future<void> _reconcile(
    _StoreRenewalReadPeriod period,
    StoreRenewalObservation hint,
  ) async {
    period.reconciling = true;
    try {
      await reconcile!();
    } on Object {
      /* Neutral; canonical proof still owns rights. */
    } finally {
      period.reconciling = false;
      if (!period.timedOut &&
          identical(_periods[hint.periodKey], period) &&
          _eligible(hint) &&
          !loading()) {
        refresh();
      }
    }
  }

  void retry(StoreRenewalObservation hint) {
    if (!_eligible(hint)) return;
    final old = _periods.remove(hint.periodKey);
    if (old != null && old.reconciling) {
      _periods[hint.periodKey] = old;
      return;
    }
    old?.retire();
    begin(hint);
  }

  bool timedOut(StoreRenewalObservation hint) =>
      _periods[hint.periodKey]?.timedOut ?? false;
  @override
  void dispose() {
    _disposed = true;
    for (final period in _periods.values) {
      period.retire();
    }
    _periods.clear();
    super.dispose();
  }
}

class _StoreRenewalReadPeriod {
  final timers = <Timer>[];
  bool timedOut = false, reconciling = false;
  void retire() {
    for (final timer in timers) {
      timer.cancel();
    }
    timers.clear();
  }
}
