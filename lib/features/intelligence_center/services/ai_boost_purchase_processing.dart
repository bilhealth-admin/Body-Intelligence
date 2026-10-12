part of 'ai_boost_purchase_service.dart';

extension _AiBoostPurchaseProcessing on AiBoostPurchaseService {
  void _enqueue(List<PurchaseDetails> purchases) {
    final owner = _catalogOwner;
    final visit = _accountVisit.capture();
    if (_disposed || owner == null || _owner() != owner) return;
    final boosts = purchases
        .where(
          (item) =>
              item.productID == AiBoostPurchaseService.productId &&
              !_isCreditedReplayDuringAnotherPurchase(item, owner),
        )
        .toList();
    if (boosts.isEmpty) return;
    checkoutTrace?.mark(StorePurchaseStage.nativeCallback);
    _generation++;
    _watchdog?.cancel();
    _queued++;
    _updates = _updates.then((_) async {
      try {
        for (final purchase in boosts) {
          if (_disposed ||
              _owner() != owner ||
              !_accountVisit.isCurrent(visit)) {
            return;
          }
          await _process(purchase, owner, expectedVisit: visit);
        }
      } finally {
        _queued--;
        _notifyReceiptLaneChanged();
      }
    });
  }

  Future<void> _process(
    PurchaseDetails purchase,
    String owner, {
    StoreAccountSnapshot? expectedVisit,
  }) async {
    final visit = expectedVisit ?? _accountVisit.capture();
    bool current() =>
        !_disposed && _owner() == owner && _accountVisit.isCurrent(visit);
    if (!current()) return;
    if (_isCreditedReplayDuringAnotherPurchase(purchase, owner)) return;
    if (purchase.status == PurchaseStatus.pending) {
      _unresolved = purchase;
      _publish(AiBoostPurchaseState.pending, null);
      _watchdog?.cancel();
      _watchdog = Timer(pendingTimeout, () {
        if (current() && state == AiBoostPurchaseState.pending) {
          _publish(AiBoostPurchaseState.failed, 'purchase_status_unknown');
        }
      });
      return;
    }
    if (purchase.status == PurchaseStatus.canceled ||
        purchase.status == PurchaseStatus.error) {
      _unresolved = null;
      _publish(
        AiBoostPurchaseState.ready,
        purchase.status == PurchaseStatus.canceled
            ? 'purchase_cancelled'
            : 'purchase_failed',
      );
      return;
    }
    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      return;
    }
    _unresolved = purchase;
    final key = _receiptKey(purchase, owner);
    try {
      if (!_credited.contains(key)) {
        checkoutTrace?.mark(StorePurchaseStage.verificationStarted);
        final verified = await _verify(
          purchase,
          owner,
        ).timeout(const Duration(seconds: 28));
        if (!current()) return;
        if (!verified.verified) throw StateError('verification_failed');
        checkoutTrace?.mark(StorePurchaseStage.serverProof);
        _acceptDelivery(verified.delivery);
        if (lastDelivery != null) {
          StorePurchaseTraceRegistry.bind(
            lastDelivery!.eventKey,
            checkoutTrace,
          );
        }
        lastDeliveryIsUserPurchase =
            _userInitiatedProduct == purchase.productID &&
            purchase.status == PurchaseStatus.purchased;
        if (verified.delivery?.active == false) {
          if (purchase.pendingCompletePurchase &&
              defaultTargetPlatform != TargetPlatform.android) {
            await _purchase.completePurchase(purchase).timeout(launchTimeout);
          }
          if (!current()) return;
          _unresolved = null;
          _userInitiatedProduct = null;
          _publish(AiBoostPurchaseState.ready, 'purchase_inactive');
          return;
        }
        if (_credited.add(key)) {
          if (_credited.length > 128) _credited.remove(_credited.first);
          verifiedCreditsRevision++;
        }
      }
    } on Object {
      if (current()) {
        _publish(AiBoostPurchaseState.failed, 'verification_failed');
      }
      return;
    }
    // Durable credit and native finish are different outcomes. No local balance
    // is changed; refresh the server balance even when StoreKit finish fails.
    checkoutTrace?.mark(StorePurchaseStage.benefitPublished);
    _publish(AiBoostPurchaseState.verified, null);
    checkoutTrace?.mark(StorePurchaseStage.finishStarted);
    try {
      if (defaultTargetPlatform == TargetPlatform.android &&
          lastDelivery?.finishPending == true) {
        final finished = await _finishVerification!(
          purchase,
          owner,
        ).timeout(const Duration(seconds: 28));
        if (!current()) return;
        if (!finished.verified ||
            finished.delivery?.active != true ||
            finished.delivery?.finishPending != false) {
          throw StateError('store_finish_pending');
        }
        _acceptDelivery(finished.delivery);
      }
      if (defaultTargetPlatform != TargetPlatform.android &&
          purchase.pendingCompletePurchase) {
        await _purchase.completePurchase(purchase).timeout(launchTimeout);
      }
      if (!current()) return;
      checkoutTrace?.mark(StorePurchaseStage.finishCompleted);
      _unresolved = null;
      _userInitiatedProduct = null;
      _publish(AiBoostPurchaseState.verified, null);
    } on Object {
      if (current()) {
        _publish(AiBoostPurchaseState.verified, 'store_finish_pending');
      }
    }
  }

  String _receiptKey(PurchaseDetails purchase, String owner) => sha256
      .convert(
        utf8.encode(
          '$owner|${purchase.verificationData.source}|${purchase.productID}|${purchase.purchaseID?.trim().isNotEmpty == true ? 'transaction:${purchase.purchaseID}' : 'receipt:${sha256.convert(utf8.encode(purchase.verificationData.serverVerificationData))}'}',
        ),
      )
      .toString();

  bool _isCreditedReplayDuringAnotherPurchase(
    PurchaseDetails purchase,
    String owner,
  ) {
    final key = _receiptKey(purchase, owner);
    if (!_credited.contains(key)) return false;
    return state == AiBoostPurchaseState.pending ||
        errorCode == 'purchase_status_unknown' ||
        (_unresolved != null && _receiptKey(_unresolved!, owner) != key);
  }

  Future<List<PurchaseDetails>> _readUnfinished() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final response = await _purchase
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .queryPastPurchases();
      if (response.error != null) {
        throw StateError('store_reconciliation_failed');
      }
      return response.pastPurchases;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final unfinished = await SK2Transaction.unfinishedTransactions();
      return unfinished
          .where(
            (transaction) =>
                transaction.productId == AiBoostPurchaseService.productId,
          )
          .map(
            (transaction) => SK2PurchaseDetails(
              productID: transaction.productId,
              purchaseID: transaction.id,
              verificationData: PurchaseVerificationData(
                localVerificationData: transaction.jsonRepresentation ?? '',
                serverVerificationData: transaction.receiptData ?? '',
                source: 'app_store',
              ),
              transactionDate: transaction.purchaseDate,
              status: PurchaseStatus.purchased,
              appAccountToken: transaction.appAccountToken,
            ),
          )
          .toList();
    }
    throw StateError('store_reconciliation_unavailable');
  }
}

Future<StoreVerificationOutcome> _verifyOnServer(
  PurchaseDetails purchase,
  String owner,
) => _verifyOnServerPhase(purchase, owner, finishStore: false);
Future<StoreVerificationOutcome> _finishOnServer(
  PurchaseDetails purchase,
  String owner,
) => _verifyOnServerPhase(purchase, owner, finishStore: true);
Future<StoreVerificationOutcome> _verifyOnServerPhase(
  PurchaseDetails purchase,
  String owner, {
  required bool finishStore,
}) async {
  final client = Supabase.instance.client;
  return CommunityOwnerOperation.run(
    client: client,
    ownerId: owner,
    action: (_) =>
        _verifyOwnedBoost(client, purchase, owner, finishStore: finishStore),
  );
}

Future<StoreVerificationOutcome> _verifyOwnedBoost(
  SupabaseClient client,
  PurchaseDetails purchase,
  String owner, {
  required bool finishStore,
}) async {
  if (client.auth.currentUser?.id != owner) {
    return const StoreVerificationOutcome(false);
  }
  final protectedBody = await BilMobileIntegrityService.instance.protect(
    action: 'store.verify_ai_boost',
    payload: <String, Object?>{
      'action': 'verify_ai_boost',
      'delivery_version': 2,
      'finish_store': finishStore,
      'product_id': AiBoostPurchaseService.productId,
      'source': purchase.verificationData.source,
      'verification_data': purchase.verificationData.serverVerificationData,
    },
  );
  if (client.auth.currentUser?.id != owner) {
    return const StoreVerificationOutcome(false);
  }
  final response = await client.functions.invoke(
    'verify-store-purchase',
    body: protectedBody,
  );
  final data = response.data;
  if (client.auth.currentUser?.id != owner ||
      response.status != 200 ||
      data is! Map ||
      data['verified'] != true) {
    return const StoreVerificationOutcome(false);
  }
  final delivery = StoreBenefitDelivery.parse(
    data['delivery'],
    ownerId: owner,
    productId: purchase.productID,
    source: purchase.verificationData.source,
  );
  // Legacy credited=true proves a fresh committed grant, but carries no
  // quantity for presentation. credited=false cannot distinguish a replay
  // from a refund, so it stays unresolved until v2 verification is available.
  return StoreVerificationOutcome(
    delivery != null || data['credited'] == true,
    delivery: delivery,
  );
}
