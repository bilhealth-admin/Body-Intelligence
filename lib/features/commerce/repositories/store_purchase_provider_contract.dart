import '../domain/store_purchase_request.dart';
import '../domain/store_receipt.dart';

abstract interface class StorePurchaseProviderContract {
  Future<StoreReceipt> purchase(StorePurchaseRequest request);

  Future<List<StoreReceipt>> restore({required String accountId});
}
