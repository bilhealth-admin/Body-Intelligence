import '../domain/coupon_definition.dart';
import '../domain/coupon_redemption.dart';

/// Local-first coupon lookup and redemption ledger boundary.
abstract interface class CouponRepository {
  CouponDefinition? findByCode(String code);

  List<CouponRedemption> redemptionsForCode(String code);

  List<CouponRedemption> redemptionsForUser(String userReference);

  void record(CouponRedemption redemption);
}
