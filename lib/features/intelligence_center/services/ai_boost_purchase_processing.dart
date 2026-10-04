part of 'ai_boost_purchase_service.dart';

extension _AiBoostPurchaseProcessing on AiBoostPurchaseService {
  void _enqueue(List<PurchaseDetails> purchases) {
    final owner = _catalogOwner;
    if (_disposed || owner == null || _owner() != owner) return;
    final boosts = purchases
        .where(
          (item) =>
              item.productID == AiBoostPurchaseService.productId &&
              !_isCreditedReplayDuringAnotherPurchase(item, owner),
        )
        .toList();
    if (boosts.isEmpty) return;
    _generation++;
    _watchdog?.cancel();
    _queued++;
    _updates = _updates.then((_) async {
      try {
        for (final purchase in boosts) {
          if (_disposed || _owner() != owner) return;
          await _process(purchase, owner);
        }
      } finally {
        _queued--;
        _notifyReceiptLaneChanged();
      }
    });
  }

  Future<void> _process(PurchaseDetails purchase, String owner) async {
    if (_disposed || _owner() != owner) return;
    if (_isCreditedReplayDuringAnotherPurchase(purchase, owner)) return;
    if (purchase.status == PurchaseStatus.pending) {
      _unresolved = purchase;
      _publish(AiBoostPurchaseState.pending, null);
      _watchdog?.cancel();
      _watchdog = Timer(pendingTimeout, () {
        if (!_disposed &&
            _owner() == owner &&
            state == AiBoostPurchaseState.pending) {
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
        final verified = await _verify(
          purchase,
          owner,
        ).timeout(const Duration(seconds: 28));
        if (_disposed || _owner() != owner) return;
        if (!verified) throw StateError('verification_failed');
        if (_credited.add(key)) {
          if (_credited.length > 128) _credited.remove(_credited.first);
          verifiedCreditsRevision++;
        }
      }
    } on Object {
      if (!_disposed && _owner() == owner) {
        _publish(AiBoostPurchaseState.failed, 'verification_failed');
      }
      return;
    }
    // Durable credit and native finish are different outcomes. No local balance
    // is changed; refresh the server balance even when StoreKit finish fails.
    _publish(AiBoostPurchaseState.verified, null);
    try {
      if (defaultTargetPlatform != TargetPlatform.android &&
          purchase.pendingCompletePurchase) {
        await _purchase.completePurchase(purchase).timeout(launchTimeout);
      }
      if (_disposed || _owner() != owner) return;
      _unresolved = null;
      _publish(AiBoostPurchaseState.verified, null);
    } on Object {
      if (!_disposed && _owner() == owner) {
        _publish(AiBoostPurchaseState.verified, 'store_finish_pending');
      }
    }
  }

  String _receiptKey(PurchaseDetails purchase, String owner) => sha256
      .convert(
        utf8.encode(
          '$owner|${purchase.productID}|${purchase.purchaseID}|${purchase.verificationData.serverVerificationData}',
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

Future<bool> _verifyOnServer(PurchaseDetails purchase, String owner) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser?.id != owner) return false;
  final protectedBody = await BilMobileIntegrityService.instance.protect(
    action: 'store.verify_ai_boost',
    payload: <String, Object?>{
      'action': 'verify_ai_boost',
      'product_id': AiBoostPurchaseService.productId,
      'source': purchase.verificationData.source,
      'verification_data': purchase.verificationData.serverVerificationData,
    },
  );
  if (client.auth.currentUser?.id != owner) return false;
  final response = await client.functions.invoke(
    'verify-store-purchase',
    body: protectedBody,
  );
  final data = response.data;
  return client.auth.currentUser?.id == owner &&
      response.status == 200 &&
      data is Map &&
      data['verified'] == true;
}
