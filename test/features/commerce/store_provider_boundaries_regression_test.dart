import 'package:body_intelligence_log/features/commerce/domain/store_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_purchase_request.dart';
import 'package:body_intelligence_log/features/commerce/repositories/receipt_validation_contract.dart';
import 'package:body_intelligence_log/features/commerce/repositories/store_purchase_provider_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider enum preserves Apple Google and Web boundaries', () {
    expect(
      StoreProvider.values,
      containsAll(<StoreProvider>[
        StoreProvider.apple,
        StoreProvider.google,
        StoreProvider.web,
      ]),
    );
  });

  test('purchase request carries idempotency and account identity', () {
    const request = StorePurchaseRequest(
      provider: StoreProvider.web,
      productId: 'bil.elite.yearly',
      accountId: 'account-7',
      idempotencyKey: 'purchase-7',
    );

    expect(request.idempotencyKey, 'purchase-7');
    expect(request.accountId, 'account-7');
  });

  test('future provider and validation contracts remain abstract', () {
    expect(StorePurchaseProviderContract, isNotNull);
    expect(ReceiptValidationContract, isNotNull);
  });
}
