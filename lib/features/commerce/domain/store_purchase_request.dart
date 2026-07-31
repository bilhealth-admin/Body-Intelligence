import 'store_provider.dart';

class StorePurchaseRequest {
  const StorePurchaseRequest({
    required this.provider,
    required this.productId,
    required this.accountId,
    required this.idempotencyKey,
  });

  final StoreProvider provider;
  final String productId;
  final String accountId;
  final String idempotencyKey;
}
