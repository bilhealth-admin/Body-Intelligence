import 'receipt_validation_status.dart';
import 'store_provider.dart';

class ReceiptValidationResult {
  const ReceiptValidationResult({
    required this.provider,
    required this.transactionId,
    required this.status,
    required this.validatedAt,
    this.expiresAt,
    this.reasonCode,
    this.serverReference,
  });

  final StoreProvider provider;
  final String transactionId;
  final ReceiptValidationStatus status;
  final DateTime validatedAt;
  final DateTime? expiresAt;
  final String? reasonCode;
  final String? serverReference;

  bool get grantsAccess => status == ReceiptValidationStatus.valid;
}
