import 'store_provider.dart';

class StoreReceipt {
  const StoreReceipt({
    required this.provider,
    required this.transactionId,
    required this.productId,
    required this.accountId,
    required this.purchasedAt,
    required this.rawReceipt,
    this.originalTransactionId,
  });

  final StoreProvider provider;
  final String transactionId;
  final String? originalTransactionId;
  final String productId;
  final String accountId;
  final DateTime purchasedAt;
  final String rawReceipt;

  bool get hasRequiredIdentity =>
      transactionId.trim().isNotEmpty &&
      productId.trim().isNotEmpty &&
      accountId.trim().isNotEmpty;
}
