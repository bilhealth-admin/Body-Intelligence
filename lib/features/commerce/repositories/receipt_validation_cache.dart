import '../domain/receipt_validation_result.dart';

abstract interface class ReceiptValidationCache {
  ReceiptValidationResult? find(String transactionId);

  void save(ReceiptValidationResult result);

  void remove(String transactionId);
}
