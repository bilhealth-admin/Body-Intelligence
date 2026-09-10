import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refresh cannot replace an in-flight native purchase state', () async {
    final store = VerifiedStorePurchaseService()
      ..state = VerifiedStoreState.purchasePending
      ..messageCode = 'purchase_pending';
    addTearDown(store.dispose);
    await store.initialize();
    expect(store.state, VerifiedStoreState.purchasePending);
    expect(store.messageCode, 'purchase_pending');
    expect(store.busy, isTrue);
    expect(store.canStartPurchase, isFalse);
  });

  test(
    'concurrent initialization shares work and remains fail closed without configuration',
    () async {
      final store = VerifiedStorePurchaseService();
      final first = store.initialize();
      final second = store.initialize();
      expect(identical(first, second), isTrue);
      await Future.wait([first, second]);
      expect(store.state, VerifiedStoreState.unavailable);
      expect(store.entitlement, isNull);
      expect(store.products, isEmpty);
      store.dispose();
    },
  );

  test(
    'disposed service does not restart native initialization or notify listeners',
    () async {
      final store = VerifiedStorePurchaseService();
      var notifications = 0;
      store.addListener(() => notifications++);
      store.dispose();
      await store.initialize();
      store.notifyListeners();
      expect(notifications, 0);
      expect(store.entitlement, isNull);
    },
  );
}
