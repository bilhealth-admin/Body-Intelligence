import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a startup purchase-stream fault does not disable a loaded catalog', () {
    final outcome = storePurchaseStreamFailureOutcome(
      productsAvailable: true,
      initiatedByCurrentService: false,
    );

    expect(outcome.state, VerifiedStoreState.ready);
    expect(outcome.messageCode, isNull);
  });

  test(
    'a purchase-stream fault during the current attempt stays fail-closed',
    () {
      final outcome = storePurchaseStreamFailureOutcome(
        productsAvailable: true,
        initiatedByCurrentService: true,
      );

      expect(outcome.state, VerifiedStoreState.failed);
      expect(outcome.messageCode, 'store_stream_failed');
    },
  );

  test('a fault while a native transaction is pending stays fail-closed', () {
    final outcome = storePurchaseStreamFailureOutcome(
      productsAvailable: true,
      initiatedByCurrentService: false,
      purchasePending: true,
    );

    expect(outcome.state, VerifiedStoreState.failed);
    expect(outcome.messageCode, 'store_stream_failed');
  });
}
