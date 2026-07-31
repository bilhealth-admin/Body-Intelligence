import '../domain/coupon_definition.dart';
import '../domain/coupon_redemption.dart';
import 'coupon_repository.dart';

/// Deterministic in-memory repository for offline evaluation and tests.
final class LocalCouponRepository implements CouponRepository {
  LocalCouponRepository({Iterable<CouponDefinition> coupons = const []})
    : _coupons = {for (final coupon in coupons) coupon.code: coupon};

  final Map<String, CouponDefinition> _coupons;
  final List<CouponRedemption> _redemptions = [];

  @override
  CouponDefinition? findByCode(String code) =>
      _coupons[CouponDefinition.normalizeCode(code)];

  @override
  List<CouponRedemption> redemptionsForCode(String code) {
    final normalized = CouponDefinition.normalizeCode(code);
    return List.unmodifiable(
      _redemptions.where((item) => item.couponCode == normalized),
    );
  }

  @override
  List<CouponRedemption> redemptionsForUser(String userReference) =>
      List.unmodifiable(
        _redemptions.where((item) => item.userReference == userReference),
      );

  @override
  void record(CouponRedemption redemption) {
    _redemptions.add(redemption);
  }
}
