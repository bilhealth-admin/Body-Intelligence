import '../domain/coupon_definition.dart';
import '../domain/coupon_redemption.dart';

/// Server/cloud adapter contract without networking implementation.
abstract interface class CouponSyncContract {
  Future<List<CouponDefinition>> fetchDefinitions({DateTime? changedSince});

  Future<void> pushRedemptions(List<CouponRedemption> redemptions);
}
