import 'package:body_intelligence_log/features/commerce/domain/receipt_validation_result.dart';
import 'package:body_intelligence_log/features/commerce/domain/receipt_validation_status.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_receipt.dart';
import 'package:body_intelligence_log/features/commerce/repositories/local_receipt_validation_cache.dart';
import 'package:body_intelligence_log/features/commerce/services/receipt_validation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 23, 10);

  StoreReceipt receipt() => StoreReceipt(
    provider: StoreProvider.google,
    transactionId: 'txn-1',
    productId: 'bil.pro.monthly',
    accountId: 'account-1',
    purchasedAt: now.subtract(const Duration(hours: 1)),
    rawReceipt: 'opaque-provider-payload',
  );

  test('unvalidated receipts never grant access offline', () {
    final engine = ReceiptValidationEngine(LocalReceiptValidationCache());

    final result = engine.resolveOffline(receipt: receipt(), now: now);

    expect(result.status, ReceiptValidationStatus.notValidated);
    expect(result.grantsAccess, isFalse);
  });

  test('fresh valid cached server result grants access deterministically', () {
    final cache = LocalReceiptValidationCache();
    final engine = ReceiptValidationEngine(cache);
    engine.acceptServerResult(
      ReceiptValidationResult(
        provider: StoreProvider.google,
        transactionId: 'txn-1',
        status: ReceiptValidationStatus.valid,
        validatedAt: now.subtract(const Duration(minutes: 10)),
        expiresAt: now.add(const Duration(days: 30)),
      ),
    );

    final result = engine.resolveOffline(receipt: receipt(), now: now);

    expect(result.status, ReceiptValidationStatus.valid);
    expect(result.grantsAccess, isTrue);
  });

  test('stale cached validation requires server validation again', () {
    final cache = LocalReceiptValidationCache();
    final engine = ReceiptValidationEngine(cache);
    engine.acceptServerResult(
      ReceiptValidationResult(
        provider: StoreProvider.google,
        transactionId: 'txn-1',
        status: ReceiptValidationStatus.valid,
        validatedAt: now.subtract(const Duration(days: 2)),
      ),
    );

    final result = engine.resolveOffline(receipt: receipt(), now: now);

    expect(result.status, ReceiptValidationStatus.notValidated);
    expect(result.reasonCode, 'cached_validation_expired');
  });

  test('expired subscription cannot grant access', () {
    final cache = LocalReceiptValidationCache();
    final engine = ReceiptValidationEngine(cache);
    engine.acceptServerResult(
      ReceiptValidationResult(
        provider: StoreProvider.google,
        transactionId: 'txn-1',
        status: ReceiptValidationStatus.valid,
        validatedAt: now.subtract(const Duration(minutes: 5)),
        expiresAt: now.subtract(const Duration(seconds: 1)),
      ),
    );

    final result = engine.resolveOffline(receipt: receipt(), now: now);

    expect(result.status, ReceiptValidationStatus.expired);
    expect(result.grantsAccess, isFalse);
  });

  test('malformed receipts are rejected locally', () {
    final engine = ReceiptValidationEngine(LocalReceiptValidationCache());
    final malformed = StoreReceipt(
      provider: StoreProvider.apple,
      transactionId: '',
      productId: 'bil.plus.monthly',
      accountId: 'account-1',
      purchasedAt: now,
      rawReceipt: '',
    );

    final result = engine.resolveOffline(receipt: malformed, now: now);

    expect(result.status, ReceiptValidationStatus.invalid);
    expect(result.reasonCode, 'malformed_receipt');
  });
}
