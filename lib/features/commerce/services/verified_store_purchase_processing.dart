part of 'verified_store_purchase_service.dart';

// Uses the service's existing owner-scoped state and serialized purchase queue.
// Keep receipt processing separate from catalog, checkout and lifecycle setup.
extension _VerifiedStorePurchaseProcessing on VerifiedStorePurchaseService {
  Future<void> _queryCompletedAndroidPurchases() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final addition = _purchase
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases().timeout(
        const Duration(seconds: 8),
      );
      if (response.error == null) {
        for (final purchase in response.pastPurchases) {
          if (StoreCatalogConfiguration.bindingForProduct(purchase.productID) !=
              null) {
            _activeGooglePurchase = purchase;
            break;
          }
        }
        await _enqueuePurchaseUpdates(response.pastPurchases);
      }
    } on Object {
      // Server refresh remains authoritative while Play is offline.
    }
  }

  Future<void> _handlePurchases(
    List<_QueuedStorePurchaseUpdate> updates,
  ) async {
    for (final update in updates) {
      final purchase = update.purchase;
      if (_disposed) {
        final attempt = update.transactionAttempt;
        if (attempt != null) {
          _finishTransactionAttempt(attempt, settled: false);
        }
        continue;
      }
      final origin = _purchaseEventOriginFor(purchase);
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = VerifiedStoreState.purchasePending;
          messageCode = switch (origin) {
            _StorePurchaseEventOrigin.purchase => 'purchase_pending',
            _StorePurchaseEventOrigin.restore => 'restore_pending',
            _StorePurchaseEventOrigin.reconciliation =>
              'reconciliation_pending',
          };
          notifyListeners();
        case PurchaseStatus.error:
          if (origin == _StorePurchaseEventOrigin.reconciliation) {
            // A StoreKit error replayed while merely opening the Plans screen
            // is not a new checkout and does not represent a charge.  It is
            // safe to keep the loaded catalog actionable.
            if (products.isEmpty && state == VerifiedStoreState.loading) {
              // StoreKit can publish a historical error before the product
              // query settles.  Treat it like a startup transport fault: a
              // subsequent valid catalog must remain purchasable.
              _storeStartupFaultBeforeCatalog = true;
            }
            state = products.isEmpty
                ? VerifiedStoreState.unavailable
                : VerifiedStoreState.ready;
            messageCode = null;
          } else {
            state = VerifiedStoreState.failed;
            messageCode = origin == _StorePurchaseEventOrigin.restore
                ? 'restore_failed'
                : 'purchase_failed';
          }
          if (origin == _StorePurchaseEventOrigin.purchase) {
            _clearPurchaseInitiation();
          }
          notifyListeners();
        case PurchaseStatus.canceled:
          // A StoreKit/Play cancellation is neither a failed receipt nor an
          // entitlement. Return to the already loaded catalog immediately so
          // the member can choose another term (for example annual -> monthly)
          // without reopening the Plans route or being told that access failed.
          state = products.isEmpty
              ? VerifiedStoreState.unavailable
              : VerifiedStoreState.ready;
          messageCode = null;
          if (origin == _StorePurchaseEventOrigin.purchase) {
            _clearPurchaseInitiation();
          }
          notifyListeners();
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleVerifiedPurchase(
            purchase,
            origin: origin,
            transactionAttempt: update.transactionAttempt,
          );
      }
    }
  }

  Future<void> _handleVerifiedPurchase(
    PurchaseDetails purchase, {
    required _StorePurchaseEventOrigin origin,
    required _StoreTransactionAttempt? transactionAttempt,
  }) async {
    var transactionSettled = false;
    try {
      final boost = purchase.productID == StoreCatalogConfiguration.aiBoost;
      final ownerId = _currentStoreOwnerId();
      if (ownerId == null) return;
      final verification = boost
          ? await _verifyBoostOnServer(purchase)
          : await _verifyOnServer(purchase, ownerId: ownerId);
      if (_disposed || !_isCurrentStoreOwner(ownerId)) return;
      final verifiedActive =
          verification == _StoreReceiptVerificationResult.verifiedActive;
      final verifiedReceipt =
          verification == _StoreReceiptVerificationResult.verifiedActive ||
          verification == _StoreReceiptVerificationResult.verifiedInactive;
      if (!boost && verifiedActive && purchase is GooglePlayPurchaseDetails) {
        _activeGooglePurchase = purchase;
      }
      // Google consumables are consumed by the server only after the durable,
      // idempotent credit succeeds. StoreKit still requires the transaction to
      // be completed on-device. A server failure deliberately remains
      // unfinished and therefore fail-closed.
      if (verifiedReceipt && purchase.pendingCompletePurchase) {
        if (!boost || defaultTargetPlatform != TargetPlatform.android) {
          try {
            await _purchase
                .completePurchase(purchase)
                .timeout(const Duration(seconds: 12));
          } on Object {
            // Do not leave the Plans screen in an endless pending state when
            // StoreKit accepts the receipt but never acknowledges completion.
            // The unfinished transaction remains eligible for a later native
            // replay, while the server entitlement stays authoritative.
            state = VerifiedStoreState.failed;
            messageCode = 'verification_failed';
            if (origin == _StorePurchaseEventOrigin.purchase) {
              _clearPurchaseInitiation();
            }
            notifyListeners();
            return;
          }
        }
      }
      transactionSettled = verifiedReceipt;
      // completePurchase can yield to the platform. Never publish the old
      // account's receipt result into a newer signed-in member's Plans state.
      if (_disposed || !_isCurrentStoreOwner(ownerId)) return;
      switch (verification) {
        case _StoreReceiptVerificationResult.ownershipConflict:
          // Do not acknowledge, transfer, or retry billing for another owner.
          // Keep this result through the rest of a multi-receipt restore.
          if (_restoring) _restoreOwnershipConflict = true;
          state = VerifiedStoreState.failed;
          messageCode = 'purchase_owned_by_another_account';
        case _StoreReceiptVerificationResult.verifiedActive:
          state = VerifiedStoreState.verified;
          messageCode = boost ? 'ai_boost_verified' : 'subscription_verified';
        case _StoreReceiptVerificationResult.verifiedInactive:
          // An authentic but expired/refunded/revoked transaction must stop
          // replaying without granting paid access.
          state = products.isEmpty
              ? VerifiedStoreState.unavailable
              : VerifiedStoreState.ready;
          messageCode = 'no_restorable_purchases';
        case _StoreReceiptVerificationResult.failed:
          state = VerifiedStoreState.failed;
          messageCode = switch (origin) {
            _StorePurchaseEventOrigin.purchase => 'verification_failed',
            _StorePurchaseEventOrigin.restore => 'restore_verification_failed',
            _StorePurchaseEventOrigin.reconciliation =>
              'reconciliation_verification_failed',
          };
      }
      if (origin == _StorePurchaseEventOrigin.purchase) {
        _clearPurchaseInitiation();
      }
      notifyListeners();
    } finally {
      if (transactionAttempt != null) {
        _finishTransactionAttempt(
          transactionAttempt,
          settled: transactionSettled,
        );
      }
    }
  }

  Future<void> _consumePurchaseUpdates(
    List<_QueuedStorePurchaseUpdate> updates,
  ) async {
    if (_disposed) {
      for (final update in updates) {
        final attempt = update.transactionAttempt;
        if (attempt != null) {
          _finishTransactionAttempt(attempt, settled: false);
        }
      }
      return;
    }
    try {
      await _handlePurchases(updates);
    } on Object {
      for (final update in updates) {
        final attempt = update.transactionAttempt;
        if (attempt != null) {
          _finishTransactionAttempt(attempt, settled: false);
        }
      }
      if (_disposed) return;
      state = VerifiedStoreState.failed;
      // Receipt delivery/acknowledgement may already follow a charge. This is
      // not a safe pre-launch retry and must never enable a second purchase.
      messageCode = 'verification_failed';
      notifyListeners();
    }
  }

  Future<void> _enqueuePurchaseUpdates(List<PurchaseDetails> purchases) {
    if (_disposed || purchases.isEmpty) return Future<void>.value();
    final updates = <_QueuedStorePurchaseUpdate>[];
    var cooledDownReplaySuppressed = false;
    for (final purchase in purchases) {
      final transactionAttempt = _transactionAttemptFor(purchase);
      if (transactionAttempt != null) {
        switch (_reserveTransactionAttempt(transactionAttempt)) {
          case _StoreTransactionReservation.accepted:
            break;
          case _StoreTransactionReservation.alreadyQueued:
            continue;
          case _StoreTransactionReservation.cooledDown:
            cooledDownReplaySuppressed = true;
            continue;
        }
      }
      updates.add(
        _QueuedStorePurchaseUpdate(
          purchase: purchase,
          transactionAttempt: transactionAttempt,
        ),
      );
    }
    if (updates.isEmpty) {
      if (cooledDownReplaySuppressed) {
        _reportCooledDownReplay();
      }
      return Future<void>.value();
    }
    if (updates.any(
      (update) =>
          update.purchase.status == PurchaseStatus.purchased ||
          update.purchase.status == PurchaseStatus.restored,
    )) {
      // A genuine native transaction now owns the outcome. Do not allow an
      // earlier startup stream fault to turn a subsequent verification failure
      // back into a catalog-ready state when the price query eventually ends.
      _storeStartupFaultBeforeCatalog = false;
    }
    final restoreEventObserved = _restoreEventObserved;
    if (restoreEventObserved != null && !restoreEventObserved.isCompleted) {
      restoreEventObserved.complete();
    }
    // Store callbacks own transaction outcomes. An older price/launch Future
    // must not publish a stale failure after any newer native transaction event.
    _purchaseEventGeneration++;
    _queuedPurchaseUpdates++;
    notifyListeners();
    // Native callbacks may overlap server verification. Preserve arrival order
    // and never acknowledge a pending or unverified transaction.
    return _purchaseUpdates = _purchaseUpdates.then((_) async {
      try {
        await _consumePurchaseUpdates(updates);
      } finally {
        _queuedPurchaseUpdates--;
        notifyListeners();
      }
    });
  }

  _StoreTransactionAttempt? _transactionAttemptFor(PurchaseDetails purchase) {
    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      return null;
    }
    final fingerprint = _transactionFingerprint(purchase);
    if (fingerprint == null) return null;
    final cooldownKey = _transactionCooldownKey(fingerprint);
    return _StoreTransactionAttempt(
      queueKey: cooldownKey ?? fingerprint,
      cooldownKey: cooldownKey,
    );
  }

  _StoreTransactionReservation _reserveTransactionAttempt(
    _StoreTransactionAttempt attempt,
  ) {
    if (!_queuedTransactionKeys.add(attempt.queueKey)) {
      return _StoreTransactionReservation.alreadyQueued;
    }
    if (_restoring) {
      // A Restore tap may deliberately retry a prior failure, but a second
      // StoreKit callback for that same transaction during this one tap must
      // not consume another verification/rate-limit slot.
      if (!_explicitRestoreTransactionKeys.add(attempt.queueKey)) {
        _queuedTransactionKeys.remove(attempt.queueKey);
        return _StoreTransactionReservation.alreadyQueued;
      }
      return _StoreTransactionReservation.accepted;
    }
    final cooldownKey = attempt.cooldownKey;
    if (cooldownKey == null) {
      return _StoreTransactionReservation.accepted;
    }
    final now = DateTime.now().toUtc();
    _VerifiedStorePurchaseProcessing._pruneExpiredTransactionCooldowns(now);
    final expiresAt =
        VerifiedStorePurchaseService._failedTransactionCooldowns[cooldownKey];
    if (expiresAt != null && expiresAt.isAfter(now)) {
      _queuedTransactionKeys.remove(attempt.queueKey);
      return _StoreTransactionReservation.cooledDown;
    }
    return _StoreTransactionReservation.accepted;
  }

  void _finishTransactionAttempt(
    _StoreTransactionAttempt attempt, {
    required bool settled,
  }) {
    if (!_queuedTransactionKeys.remove(attempt.queueKey)) return;
    final cooldownKey = attempt.cooldownKey;
    if (cooldownKey == null) return;
    final now = DateTime.now().toUtc();
    _VerifiedStorePurchaseProcessing._pruneExpiredTransactionCooldowns(now);
    if (settled) {
      // Only failed attempts are remembered. A verified transaction is not a
      // local entitlement and must never be cached as one.
      VerifiedStorePurchaseService._failedTransactionCooldowns.remove(
        cooldownKey,
      );
    } else {
      VerifiedStorePurchaseService._failedTransactionCooldowns[cooldownKey] =
          now.add(
            VerifiedStorePurchaseService._failedTransactionReplayCooldown,
          );
      _VerifiedStorePurchaseProcessing._pruneExpiredTransactionCooldowns(now);
    }
  }

  void _reportCooledDownReplay() {
    if (_disposed) return;
    // An old StoreKit replay must never replace the pending state for a new
    // explicit checkout. Its eventual native update still owns that checkout.
    if (_purchaseInitiatedByThisService &&
        state == VerifiedStoreState.purchasePending) {
      return;
    }
    _storeStartupFaultBeforeCatalog = false;
    _purchaseEventGeneration++;
    final origin = _restoring
        ? _StorePurchaseEventOrigin.restore
        : _purchaseInitiatedByThisService
        ? _StorePurchaseEventOrigin.purchase
        : _StorePurchaseEventOrigin.reconciliation;
    state = VerifiedStoreState.failed;
    messageCode = switch (origin) {
      _StorePurchaseEventOrigin.purchase => 'verification_failed',
      _StorePurchaseEventOrigin.restore => 'restore_verification_failed',
      _StorePurchaseEventOrigin.reconciliation =>
        'reconciliation_verification_failed',
    };
    if (origin == _StorePurchaseEventOrigin.purchase) {
      _clearPurchaseInitiation();
    }
    notifyListeners();
  }

  String? _transactionFingerprint(PurchaseDetails purchase) {
    final purchaseId = purchase.purchaseID?.trim();
    final verificationData = purchase.verificationData.serverVerificationData
        .trim();
    if ((purchaseId == null || purchaseId.isEmpty) &&
        verificationData.isEmpty) {
      return null;
    }
    // Prefer the platform transaction id. The server-verification payload is
    // only a fallback, and is hashed before it is retained in any key.
    final transactionIdentity = purchaseId != null && purchaseId.isNotEmpty
        ? 'purchase:$purchaseId'
        : 'receipt:${sha256.convert(utf8.encode(verificationData))}';
    final source = purchase.verificationData.source.trim();
    return sha256
        .convert(
          utf8.encode('$source|${purchase.productID}|$transactionIdentity'),
        )
        .toString();
  }

  String? _currentStoreOwnerId() => AppEnvironment.supabaseRuntimeReady
      ? Supabase.instance.client.auth.currentUser?.id
      : null;

  bool _isCurrentStoreOwner(String ownerId) =>
      _currentStoreOwnerId() == ownerId;

  void _markServerVerifiedInactive(
    String ownerId, {
    required DateTime? verifiedAt,
  }) {
    final receivedAt = DateTime.now().toUtc();
    _serverVerifiedInactiveOwnerId = ownerId;
    _serverVerifiedInactiveAt = verifiedAt ?? receivedAt;
    // Older deployed functions did not include the canonical verification
    // timestamp. Preserve fail-closed behavior for this receipt, but do not
    // keep blocking a later genuine subscription forever.
    _serverVerifiedInactiveFallbackExpiresAt = verifiedAt == null
        ? receivedAt.add(const Duration(minutes: 1))
        : null;
    _clearEntitlement();
  }

  bool _hasServerVerifiedInactiveMarker(String ownerId) {
    if (_serverVerifiedInactiveOwnerId != ownerId) return false;
    final fallbackExpiresAt = _serverVerifiedInactiveFallbackExpiresAt;
    if (fallbackExpiresAt != null &&
        !fallbackExpiresAt.isAfter(DateTime.now().toUtc())) {
      _clearServerVerifiedInactiveOwner(ownerId);
      return false;
    }
    return true;
  }

  void _clearServerVerifiedInactiveOwner(String ownerId) {
    if (_serverVerifiedInactiveOwnerId == ownerId) {
      _serverVerifiedInactiveOwnerId = null;
      _serverVerifiedInactiveAt = null;
      _serverVerifiedInactiveFallbackExpiresAt = null;
    }
  }

  String? _transactionCooldownKey(String fingerprint) {
    final ownerId = _currentStoreOwnerId();
    if (ownerId == null || ownerId.isEmpty) return null;
    // Scope the process-local cooldown to the member, provider/product and
    // transaction fingerprint without retaining any raw account or receipt.
    return sha256
        .convert(utf8.encode('bil-store-replay:$ownerId:$fingerprint'))
        .toString();
  }

  static void _pruneExpiredTransactionCooldowns(DateTime now) {
    VerifiedStorePurchaseService._failedTransactionCooldowns.removeWhere(
      (_, expiresAt) => !expiresAt.isAfter(now),
    );
    final excess =
        VerifiedStorePurchaseService._failedTransactionCooldowns.length -
        VerifiedStorePurchaseService._maximumFailedTransactionCooldowns;
    if (excess <= 0) return;
    final oldest =
        VerifiedStorePurchaseService._failedTransactionCooldowns.entries
            .toList()
          ..sort((left, right) => left.value.compareTo(right.value));
    for (final entry in oldest.take(excess)) {
      VerifiedStorePurchaseService._failedTransactionCooldowns.remove(
        entry.key,
      );
    }
  }

  Future<_StoreReceiptVerificationResult> _verifyOnServer(
    PurchaseDetails purchase, {
    required String ownerId,
  }) async {
    if (StoreCatalogConfiguration.bindingForProduct(purchase.productID) ==
        null) {
      return _StoreReceiptVerificationResult.failed;
    }
    try {
      if (!_isCurrentStoreOwner(ownerId)) {
        return _StoreReceiptVerificationResult.failed;
      }
      final body = <String, Object?>{
        'action': 'verify_purchase',
        'product_id': purchase.productID,
        'purchase_id': purchase.purchaseID,
        'source': purchase.verificationData.source,
        'verification_data': purchase.verificationData.serverVerificationData,
      };
      final protectedBody = await BilMobileIntegrityService.instance
          .protect(action: 'store.verify_purchase', payload: body)
          .timeout(const Duration(seconds: 12));
      if (!_isCurrentStoreOwner(ownerId)) {
        return _StoreReceiptVerificationResult.failed;
      }
      final response = await Supabase.instance.client.functions
          .invoke('verify-store-purchase', body: protectedBody)
          .timeout(const Duration(seconds: 30));
      final data = response.data;
      if (!_isCurrentStoreOwner(ownerId) ||
          response.status != 200 ||
          data is! Map ||
          data['verified'] != true) {
        return _verificationFailure(data);
      }
      final entitlementActive = data['entitlement_active'];
      if (entitlementActive == true) {
        // If a prior receipt was authoritatively inactive, retain its
        // watermark until the canonical active row proves it is newer. This
        // preserves fail-closed behavior during read-replica lag.
        // The verification function persists first, but the read replica can
        // briefly lag. Retry the read a few times before reporting a false
        // verification failure to the native purchase queue.
        for (var attempt = 0; attempt < 3; attempt++) {
          if (!_isCurrentStoreOwner(ownerId)) {
            return _StoreReceiptVerificationResult.failed;
          }
          await refreshEntitlement();
          if (!_isCurrentStoreOwner(ownerId)) {
            return _StoreReceiptVerificationResult.failed;
          }
          if (entitlement?.grantsPaidAccess == true) break;
          if (attempt < 2) {
            await Future<void>.delayed(
              Duration(milliseconds: attempt == 0 ? 150 : 300),
            );
          }
        }
        // An active response without a durable, access-granting canonical row
        // stays fail-closed. Completing it would discard the StoreKit evidence
        // before BIL can prove the entitlement.
        return entitlement?.grantsPaidAccess == true
            ? _StoreReceiptVerificationResult.verifiedActive
            : _StoreReceiptVerificationResult.failed;
      }
      if (entitlementActive == false) {
        // The server has verified and persisted an inactive lifecycle. Clear
        // any stale local paid snapshot first: a read failure must not retain
        // access after the server explicitly says it is inactive.
        _markServerVerifiedInactive(
          ownerId,
          verifiedAt: DateTime.tryParse('${data['verified_at']}')?.toUtc(),
        );
        await refreshEntitlement();
        if (!_isCurrentStoreOwner(ownerId)) {
          return _StoreReceiptVerificationResult.failed;
        }
        // The marker rejects only older replica rows. If the canonical read
        // already observes a newer active verification, publish that current
        // entitlement instead of reporting an obsolete empty restore.
        return entitlement?.grantsPaidAccess == true
            ? _StoreReceiptVerificationResult.verifiedActive
            : _StoreReceiptVerificationResult.verifiedInactive;
      }
      return _StoreReceiptVerificationResult.failed;
    } on FunctionException catch (error) {
      return _verificationFailure(error.details);
    } on Object {
      return _StoreReceiptVerificationResult.failed;
    }
  }

  Future<_StoreReceiptVerificationResult> _verifyBoostOnServer(
    PurchaseDetails purchase,
  ) async {
    if (purchase.productID != StoreCatalogConfiguration.aiBoost) {
      return _StoreReceiptVerificationResult.failed;
    }
    try {
      final body = <String, Object?>{
        'action': 'verify_ai_boost',
        'product_id': purchase.productID,
        'source': purchase.verificationData.source,
        'verification_data': purchase.verificationData.serverVerificationData,
      };
      final protectedBody = await BilMobileIntegrityService.instance
          .protect(action: 'store.verify_ai_boost', payload: body)
          .timeout(const Duration(seconds: 12));
      final response = await Supabase.instance.client.functions
          .invoke('verify-store-purchase', body: protectedBody)
          .timeout(const Duration(seconds: 30));
      final data = response.data;
      return response.status == 200 && data is Map && data['verified'] == true
          ? _StoreReceiptVerificationResult.verifiedActive
          : _verificationFailure(data);
    } on FunctionException catch (error) {
      return _verificationFailure(error.details);
    } on Object {
      return _StoreReceiptVerificationResult.failed;
    }
  }

  _StoreReceiptVerificationResult _verificationFailure(Object? data) {
    // Allowlist the server's public code; never render raw error/receipt data
    // or the identity of the other account in the storefront.
    return data is Map && data['error'] == 'purchase_owned_by_another_account'
        ? _StoreReceiptVerificationResult.ownershipConflict
        : _StoreReceiptVerificationResult.failed;
  }

  _StorePurchaseEventOrigin _purchaseEventOriginFor(PurchaseDetails purchase) {
    if (_restoring) return _StorePurchaseEventOrigin.restore;
    if (_purchaseInitiatedByThisService &&
        _purchaseInitiatedProductId == purchase.productID) {
      return _StorePurchaseEventOrigin.purchase;
    }
    return _StorePurchaseEventOrigin.reconciliation;
  }

  void _clearPurchaseInitiation() {
    _purchaseWatchdog?.cancel();
    _purchaseWatchdog = null;
    _purchaseInitiatedByThisService = false;
    _purchaseInitiatedProductId = null;
  }

  CommercePlan _planFromId(String value) {
    return CommercePlan.values.firstWhere(
      (plan) => plan.id == value,
      orElse: () => CommercePlan.free,
    );
  }

  CommercePlan? _planFromIdOrNull(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized == 'free') {
      return normalized == 'free' ? CommercePlan.free : null;
    }
    final plan = _planFromId(normalized);
    return plan == CommercePlan.free ? null : plan;
  }
}

enum _StorePurchaseEventOrigin { purchase, restore, reconciliation }

enum _StoreReceiptVerificationResult {
  failed,
  ownershipConflict,
  verifiedInactive,
  verifiedActive,
}

enum _StoreTransactionReservation { accepted, alreadyQueued, cooledDown }

final class _QueuedStorePurchaseUpdate {
  const _QueuedStorePurchaseUpdate({
    required this.purchase,
    required this.transactionAttempt,
  });

  final PurchaseDetails purchase;
  final _StoreTransactionAttempt? transactionAttempt;
}

final class _StoreTransactionAttempt {
  const _StoreTransactionAttempt({
    required this.queueKey,
    required this.cooldownKey,
  });

  final String queueKey;
  final String? cooldownKey;
}
