import '../domain/receipt_validation_result.dart';
import 'receipt_validation_cache.dart';

class LocalReceiptValidationCache implements ReceiptValidationCache {
  final Map<String, ReceiptValidationResult> _results =
      <String, ReceiptValidationResult>{};

  @override
  ReceiptValidationResult? find(String transactionId) =>
      _results[transactionId.trim()];

  @override
  void remove(String transactionId) {
    _results.remove(transactionId.trim());
  }

  @override
  void save(ReceiptValidationResult result) {
    _results[result.transactionId.trim()] = result;
  }
}
