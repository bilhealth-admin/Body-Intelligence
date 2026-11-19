import 'dart:async';
import 'package:body_intelligence_log/features/intelligence_center/services/ai_boost_purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class Native extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  int launches = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: [
          ProductDetails(
            id: AiBoostPurchaseService.productId,
            title: 'Boost',
            description: 'fixture',
            price: 'USD 2.49',
            rawPrice: 2.49,
            currencyCode: 'USD',
          ),
        ],
        notFoundIDs: [],
      );
  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    launches++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Android explicit Buy cannot take payment without fresh licensing readiness',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final native = Native();
      final service = AiBoostPurchaseService(
        purchase: native,
        owner: () => 'fixture-owner',
        ownerChanges: const Stream.empty(),
        verify: (_, _) async => true,
        reconcile: () async => [],
      );
      try {
        await service.initialize();
        expect(service.canPurchase, isTrue);
        await service.purchaseBoost();
        expect(native.launches, 0);
        expect(service.state, isNot(AiBoostPurchaseState.pending));
        expect(service.verifiedCreditsRevision, 0);
      } finally {
        service.dispose();
        await native.updates.close();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
