import '../domain/receipt_validation_result.dart';
import '../domain/store_receipt.dart';

abstract interface class ReceiptValidationContract {
  Future<ReceiptValidationResult> validate(StoreReceipt receipt);
}
