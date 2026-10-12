import 'store_catalog_configuration.dart';

/// Authenticated v2 transport result, distinct from a native purchase callback.
/// This is never a substitute for server entitlement/RLS authorization.
final class StoreBenefitDelivery {
  const StoreBenefitDelivery({
    required this.ownerId,
    required this.store,
    required this.environment,
    required this.eventKey,
    required this.productId,
    required this.verifiedAt,
    required this.active,
    required this.isBoost,
    required this.finishPending,
    this.quantity,
    this.creditedNow = false,
  });
  final String ownerId, store, environment, eventKey, productId;
  final DateTime verifiedAt;
  final bool active, isBoost, finishPending, creditedNow;
  final int? quantity;

  static StoreBenefitDelivery? parse(
    Object? data, {
    required String ownerId,
    required String productId,
    required String source,
  }) {
    if (data is! Map ||
        data['version'] != 2 ||
        data['owner_id'] != ownerId ||
        data['product_id'] != productId ||
        data['store'] != source ||
        !const {'app_store', 'google_play'}.contains(source) ||
        !const {'sandbox', 'production'}.contains(data['environment']) ||
        data['event_key'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['event_key'] as String) ||
        data['active'] is! bool ||
        data['finish_pending'] is! bool) {
      return null;
    }
    final boost = productId == StoreCatalogConfiguration.aiBoost;
    if ((!boost &&
            StoreCatalogConfiguration.bindingForProduct(productId) == null) ||
        data['kind'] != (boost ? 'boost' : 'subscription')) {
      return null;
    }
    final at = DateTime.tryParse('${data['verified_at']}');
    if (at == null ||
        at.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 5)))) {
      return null;
    }
    final active = data['active'] as bool;
    final quantity = data['quantity'];
    if (boost &&
        (data['credited_now'] is! bool ||
            quantity is! int ||
            (active ? quantity <= 0 : quantity != 0))) {
      return null;
    }
    return StoreBenefitDelivery(
      ownerId: ownerId,
      store: source,
      environment: data['environment'] as String,
      eventKey: data['event_key'] as String,
      productId: productId,
      verifiedAt: at.toUtc(),
      active: active,
      isBoost: boost,
      finishPending: data['finish_pending'] as bool,
      quantity: boost ? quantity as int : null,
      creditedNow: data['credited_now'] == true,
    );
  }
}

final class StoreVerificationOutcome {
  const StoreVerificationOutcome(this.verified, {this.delivery});
  final bool verified;
  final StoreBenefitDelivery? delivery;
}
