import '../domain/receipt_validation_result.dart';
import '../domain/receipt_validation_status.dart';
import '../domain/store_receipt.dart';
import '../repositories/receipt_validation_cache.dart';

class ReceiptValidationEngine {
  const ReceiptValidationEngine(this._cache);

  final ReceiptValidationCache _cache;

  ReceiptValidationResult resolveOffline({
    required StoreReceipt receipt,
    required DateTime now,
    Duration maximumCacheAge = const Duration(hours: 24),
  }) {
    if (!receipt.hasRequiredIdentity || receipt.rawReceipt.trim().isEmpty) {
      return ReceiptValidationResult(
        provider: receipt.provider,
        transactionId: receipt.transactionId,
        status: ReceiptValidationStatus.invalid,
        validatedAt: now,
        reasonCode: 'malformed_receipt',
      );
    }

    final cached = _cache.find(receipt.transactionId);
    if (cached == null) {
      return ReceiptValidationResult(
        provider: receipt.provider,
        transactionId: receipt.transactionId,
        status: ReceiptValidationStatus.notValidated,
        validatedAt: now,
        reasonCode: 'server_validation_required',
      );
    }

    final cacheAge = now.difference(cached.validatedAt);
    if (cacheAge.isNegative || cacheAge > maximumCacheAge) {
      return ReceiptValidationResult(
        provider: receipt.provider,
        transactionId: receipt.transactionId,
        status: ReceiptValidationStatus.notValidated,
        validatedAt: now,
        reasonCode: 'cached_validation_expired',
      );
    }

    if (cached.expiresAt != null && !cached.expiresAt!.isAfter(now)) {
      return ReceiptValidationResult(
        provider: cached.provider,
        transactionId: cached.transactionId,
        status: ReceiptValidationStatus.expired,
        validatedAt: now,
        expiresAt: cached.expiresAt,
        reasonCode: 'subscription_expired',
        serverReference: cached.serverReference,
      );
    }

    return cached;
  }

  void acceptServerResult(ReceiptValidationResult result) {
    _cache.save(result);
  }

  void invalidate(String transactionId) {
    _cache.remove(transactionId);
  }
}
