part of 'verified_store_purchase_service.dart';

enum GoogleReplacementDecision { clear, replace, blocked, unavailable }

final class GoogleReplacementProof {
  const GoogleReplacementProof(this.decision, [this.previous, this.validUntil]);
  final GoogleReplacementDecision decision;
  final GooglePlayPurchaseDetails? previous;
  final DateTime? validUntil;
  bool validAt(DateTime now) =>
      decision == GoogleReplacementDecision.clear ||
      decision == GoogleReplacementDecision.replace &&
          validUntil?.toUtc().isAfter(now.toUtc()) == true;
}

/// Read-only financial preflight. Defaults always use the actual SDK and RLS.
/// Tokens are compared in memory and never formatted, cached or logged here.
final class GoogleSubscriptionReplacementReader {
  const GoogleSubscriptionReplacementReader({
    this.inventoryReader,
    this.canonicalReader,
    this.clock,
  });
  final Future<QueryPurchaseDetailsResponse> Function(InAppPurchase)?
  inventoryReader;
  final Future<List<Map<String, dynamic>>> Function(String)? canonicalReader;
  final DateTime Function()? clock;

  Future<GoogleReplacementProof> read({
    required InAppPurchase purchase,
    required String owner,
    required String targetProductId,
    required bool Function() current,
    GooglePlayPurchaseDetails? requested,
  }) async {
    const blocked = GoogleReplacementProof(GoogleReplacementDecision.blocked);
    const unavailable = GoogleReplacementProof(
      GoogleReplacementDecision.unavailable,
    );
    try {
      if (!current()) return unavailable;
      final results = await Future.wait<Object>([
        Future<QueryPurchaseDetailsResponse>.sync(
          () =>
              inventoryReader?.call(purchase) ??
              purchase
                  .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
                  .queryPastPurchases(),
        ).timeout(const Duration(seconds: 8)),
        Future<List<Map<String, dynamic>>>.sync(
          () =>
              canonicalReader?.call(owner) ??
              Supabase.instance.client
                  .from('bil_subscriptions')
                  .select(
                    'owner_id,provider,product_id,plan_id,lifecycle,latest_transaction_id,started_at,expires_at,grace_period_ends_at,verified_at,revision,auto_renews',
                  )
                  .eq('owner_id', owner)
                  .limit(2),
        ).timeout(const Duration(seconds: 8)),
      ]);
      if (!current()) return unavailable;
      final inventory = results[0] as QueryPurchaseDetailsResponse;
      final rows = results[1] as List<Map<String, dynamic>>;
      if (inventory.error != null || rows.length > 1) return unavailable;
      final owned = <GooglePlayPurchaseDetails>[];
      for (final item in inventory.pastPurchases) {
        if (item.productID == StoreCatalogConfiguration.aiBoost) continue;
        if (StoreCatalogConfiguration.bindingForProduct(item.productID) ==
            null) {
          return blocked;
        }
        final native = item.billingClientPurchase;
        if (native.packageName != StoreCatalogConfiguration.packageName ||
            native.products.length != 1 ||
            native.products.single != item.productID ||
            native.purchaseToken.trim().isEmpty ||
            !native.isAcknowledged ||
            native.purchaseState != PurchaseStateWrapper.purchased) {
          return blocked;
        }
        owned.add(item);
      }
      if (owned.length > 1) return blocked;
      if (rows.isEmpty) {
        return owned.isEmpty
            ? const GoogleReplacementProof(GoogleReplacementDecision.clear)
            : blocked;
      }
      final row = rows.single;
      final now = (clock?.call() ?? DateTime.now()).toUtc();
      final provider = row['provider'];
      final binding = StoreCatalogConfiguration.bindingForProduct(
        '${row['product_id']}',
      );
      final verified = DateTime.tryParse('${row['verified_at']}')?.toUtc();
      final revision = row['revision'];
      if (row['owner_id'] != owner ||
          !const {'google', 'apple'}.contains(provider) ||
          binding == null ||
          verified == null ||
          !isAcceptableServerVerificationTimestamp(
            verifiedAt: verified,
            now: now,
          ) ||
          revision is! int ||
          revision < 0) {
        return unavailable;
      }
      final lifecycle = row['lifecycle'];
      final start = DateTime.tryParse('${row['started_at']}')?.toUtc();
      final end = DateTime.tryParse(
        '${lifecycle == 'grace_period' ? row['grace_period_ends_at'] : row['expires_at']}',
      )?.toUtc();
      final terminal = const {
        'expired',
        'refunded',
        'revoked',
        'paused',
        'suspended',
        'account_hold',
        'billing_retry',
        'deferred',
      }.contains(lifecycle);
      final nonrenewingExpired =
          const {'active', 'trial', 'cancelled'}.contains(lifecycle) &&
          end != null &&
          !end.isAfter(now) &&
          (lifecycle == 'cancelled' || row['auto_renews'] == false);
      if (terminal || nonrenewingExpired) {
        return owned.isEmpty
            ? const GoogleReplacementProof(GoogleReplacementDecision.clear)
            : blocked;
      }
      if (!const {
            'active',
            'trial',
            'grace_period',
            'cancelled',
          }.contains(lifecycle) ||
          end == null ||
          !end.isAfter(now) ||
          start == null ||
          start.isAfter(now) ||
          row['plan_id'] != binding.plan.id ||
          owned.length != 1 ||
          provider != 'google') {
        return blocked;
      }
      final previous = owned.single;
      if (previous.productID != row['product_id'] ||
          previous.productID == targetProductId ||
          row['latest_transaction_id'] !=
              previous.billingClientPurchase.purchaseToken) {
        return blocked;
      }
      if (requested != null &&
          (requested.productID != previous.productID ||
              requested.billingClientPurchase.purchaseToken !=
                  previous.billingClientPurchase.purchaseToken)) {
        return blocked;
      }
      return GoogleReplacementProof(
        GoogleReplacementDecision.replace,
        previous,
        end,
      );
    } on Object {
      return unavailable;
    }
  }
}

extension _FreshGoogleReplacement on VerifiedStorePurchaseService {
  bool _replacementProofCurrent(
    GoogleReplacementProof? proof,
    String owner,
    StoreAccountSnapshot visit,
    int generation,
  ) {
    if (!_canLaunchCheckout(owner, visit, generation)) return false;
    if (proof?.validAt(DateTime.now().toUtc()) == true) return true;
    state = VerifiedStoreState.failed;
    messageCode = 'purchase_status_unknown';
    notifyListeners();
    return false;
  }

  Future<GoogleReplacementProof?> _freshGoogleReplacement({
    required String owner,
    required StoreAccountSnapshot visit,
    required int generation,
    required String targetProductId,
    GooglePlayPurchaseDetails? requested,
  }) async {
    bool current() => _canLaunchCheckout(owner, visit, generation);
    // The operation invokes this predicate from its own zone check. Calling
    // _isCurrentStoreOwner here would recursively check that same operation.
    bool currentVisit() =>
        !_disposed &&
        _storeVisit.isCurrent(visit) &&
        _currentStoreOwnerId() == owner &&
        generation == _purchaseEventGeneration;
    bool ownsPhase() =>
        !_disposed &&
        _storeVisit.isCurrent(visit) &&
        _isCurrentStoreOwner(owner) &&
        generation == _purchaseEventGeneration &&
        state == VerifiedStoreState.loading &&
        messageCode == null;
    var accepted = false;
    if (!current()) return null;
    _checkoutPreflightInFlight = true;
    notifyListeners();
    try {
      if (!current()) return null;
      final proof = await CommunityOwnerOperation.run(
        client: Supabase.instance.client,
        ownerId: owner,
        isCurrentOwner: currentVisit,
        action: (_) => _googleReplacementReader.read(
          purchase: _purchase,
          owner: owner,
          targetProductId: targetProductId,
          current: current,
          requested: requested,
        ),
      );
      if (!current()) return null;
      switch (proof.decision) {
        case GoogleReplacementDecision.clear:
        case GoogleReplacementDecision.replace:
          accepted = true;
          return proof;
        case GoogleReplacementDecision.blocked:
          state = VerifiedStoreState.failed;
          messageCode = 'purchase_status_unknown';
        case GoogleReplacementDecision.unavailable:
          state = VerifiedStoreState.ready;
          messageCode = 'play_readiness_unavailable';
      }
      return null;
    } on CommunityOwnerOperationCancelled {
      return null;
    } finally {
      _checkoutPreflightInFlight = false;
      final unwind = !accepted && ownsPhase();
      if (unwind) {
        state = VerifiedStoreState.ready;
        messageCode = 'play_readiness_unavailable';
      }
      if (unwind || current()) notifyListeners();
    }
  }
}
