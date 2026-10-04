import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/security/bil_mobile_integrity_service.dart';
import '../../commerce/domain/store_catalog_configuration.dart';
import '../../commerce/services/verified_store_catalog_adapter.dart';
import '../../commerce/services/verified_store_purchase_service.dart';

part 'ai_boost_purchase_processing.dart';

enum AiBoostPurchaseState {
  loading,
  ready,
  pending,
  verified,
  unavailable,
  failed,
}

/// Native callbacks never grant local credit. Uncertain transactions must
/// reconcile for this owner before another charge is offered.
final class AiBoostPurchaseService extends ChangeNotifier {
  AiBoostPurchaseService({
    InAppPurchase? purchase,
    String? Function()? owner,
    Future<bool> Function(PurchaseDetails, String)? verify,
    this._reconcile,
    this.launchTimeout = const Duration(seconds: 12),
    this.pendingTimeout = const Duration(seconds: 90),
  }) : _purchase = purchase ?? InAppPurchase.instance,
       _owner = owner ?? _currentOwner,
       _verify = verify ?? _verifyOnServer;

  static const productId = StoreCatalogConfiguration.aiBoost;
  final InAppPurchase _purchase;
  final String? Function() _owner;
  final Future<bool> Function(PurchaseDetails, String) _verify;
  final Future<List<PurchaseDetails>> Function()? _reconcile;
  final Duration launchTimeout;
  final Duration pendingTimeout;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void>? _initialization;
  Future<void> _updates = Future<void>.value();
  Timer? _watchdog;
  String? _catalogOwner;
  PurchaseDetails? _unresolved;
  final Set<String> _credited = <String>{};
  int _generation = 0;
  int _queued = 0;
  bool _reconciling = false;
  bool _disposed = false;
  ProductDetails? product;
  String? displayPrice;
  String? _purchaseOfferToken;
  AiBoostPurchaseState state = AiBoostPurchaseState.loading;
  String? errorCode;
  int verifiedCreditsRevision = 0;

  bool get canPurchase =>
      !_disposed &&
      _queued == 0 &&
      !_reconciling &&
      _unresolved == null &&
      product != null &&
      _owner() == _catalogOwner &&
      (state == AiBoostPurchaseState.ready ||
          state == AiBoostPurchaseState.verified);
  bool get canRetry =>
      !_disposed &&
      _queued == 0 &&
      !_reconciling &&
      state != AiBoostPurchaseState.pending &&
      _owner() == _catalogOwner &&
      (_unresolved != null || errorCode == 'purchase_status_unknown');

  Future<void> initialize() {
    if (_disposed ||
        _queued > 0 ||
        _reconciling ||
        (state == AiBoostPurchaseState.pending && _owner() == _catalogOwner)) {
      return Future<void>.value();
    }
    return _initialization ??= _initialize().whenComplete(
      () => _initialization = null,
    );
  }

  Future<void> _initialize() async {
    final owner = _owner();
    if (owner != _catalogOwner) {
      _catalogOwner = owner;
      _unresolved = null;
      _credited.clear();
      product = null;
      _watchdog?.cancel();
      _generation++;
      _publish(AiBoostPurchaseState.loading, null);
    }
    final generation = _generation;
    if (owner == null) {
      _publish(AiBoostPurchaseState.unavailable, 'authentication_required');
      return;
    }
    _subscription ??= _purchase.purchaseStream.listen(
      _enqueue,
      onError: (_) {
        if (_disposed || _queued > 0) return;
        if (state == AiBoostPurchaseState.pending) {
          _generation++;
          _watchdog?.cancel();
          _publish(AiBoostPurchaseState.failed, 'purchase_status_unknown');
        }
      },
    );
    try {
      if (!await _purchase.isAvailable().timeout(launchTimeout)) {
        if (_current(owner, generation)) {
          _publish(AiBoostPurchaseState.unavailable, 'store_unavailable');
        }
        return;
      }
      final response = await _purchase
          .queryProductDetails({productId})
          .timeout(launchTimeout);
      if (!_current(owner, generation)) return;
      product = response.productDetails
          .where((item) => item.id == productId)
          .firstOrNull;
      final discount = product == null
          ? null
          : googlePlayOneTimeDiscountMetadata(product!);
      displayPrice = discount?.localizedPrice ?? product?.price;
      _purchaseOfferToken = discount?.offerToken;
      if (response.error != null || product == null) {
        _publish(AiBoostPurchaseState.unavailable, 'product_not_available');
      } else if (_unresolved == null &&
          errorCode != 'purchase_status_unknown') {
        _publish(AiBoostPurchaseState.ready, null);
      }
    } on Object {
      if (_current(owner, generation)) {
        _publish(AiBoostPurchaseState.unavailable, 'store_unavailable');
      }
    }
  }

  Future<void> purchaseBoost() async {
    if (!canPurchase) return;
    final owner = _owner()!;
    final selected = product!;
    final generation = _generation;
    _publish(AiBoostPurchaseState.pending, null);
    _watchdog?.cancel();
    _watchdog = Timer(pendingTimeout, () {
      if (_current(owner, generation) &&
          state == AiBoostPurchaseState.pending) {
        _publish(AiBoostPurchaseState.failed, 'purchase_status_unknown');
      }
    });
    try {
      final started = await _purchase
          .buyConsumable(
            purchaseParam: verifiedBoostPurchaseParam(
              product: selected,
              accountHash: storeAccountIdentifier(
                ownerId: owner,
                platform: defaultTargetPlatform,
              ),
              platform: defaultTargetPlatform,
              offerToken: _purchaseOfferToken,
            ),
            autoConsume: false,
          )
          .timeout(launchTimeout);
      if (!_current(owner, generation) || started) return;
      _watchdog?.cancel();
      _publish(AiBoostPurchaseState.ready, 'purchase_not_started');
    } on TimeoutException {
      if (_current(owner, generation)) {
        _publish(AiBoostPurchaseState.failed, 'purchase_status_unknown');
      }
    } on Object {
      if (_current(owner, generation)) {
        _publish(AiBoostPurchaseState.failed, 'purchase_status_unknown');
      }
    }
  }

  Future<void> retryPendingTransaction() async {
    if (!canRetry) return;
    final owner = _catalogOwner!;
    _reconciling = true;
    notifyListeners();
    // Store callbacks and explicit reconciliation must share one receipt lane.
    // Otherwise a callback can verify/finish the same transaction during retry.
    final retry = _updates.then((_) async {
      try {
        final pending = _unresolved;
        if (pending != null && pending.status != PurchaseStatus.pending) {
          await _process(pending, owner);
        } else {
          final purchases = await (_reconcile?.call() ?? _readUnfinished())
              .timeout(launchTimeout);
          if (_disposed || _owner() != owner) return;
          final boosts = purchases
              .where((item) => item.productID == productId)
              .toList();
          for (final purchase in boosts) {
            await _process(purchase, owner);
          }
          if (boosts.isEmpty) {
            _unresolved = null;
            _publish(AiBoostPurchaseState.ready, null);
          }
        }
      } on Object {
        if (!_disposed && _owner() == owner) {
          _publish(AiBoostPurchaseState.failed, 'purchase_status_unknown');
        }
      } finally {
        _reconciling = false;
        if (!_disposed) notifyListeners();
      }
    });
    _updates = retry;
    await retry;
  }

  bool _current(String owner, int generation) =>
      !_disposed && _owner() == owner && generation == _generation;

  // Receipt-lane extensions call this instance boundary rather than accessing
  // ChangeNotifier's protected notifyListeners member directly.
  void _notifyReceiptLaneChanged() {
    if (!_disposed) notifyListeners();
  }

  void _publish(AiBoostPurchaseState next, String? error) {
    if (_disposed) return;
    state = next;
    errorCode = error;
    notifyListeners();
  }

  static String? _currentOwner() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } on Object {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
