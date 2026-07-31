import 'commerce_plan.dart';
import 'subscription_term.dart';

/// Immutable local redemption fact ready for later server synchronization.
final class CouponRedemption {
  CouponRedemption({
    required String couponCode,
    required this.userReference,
    required this.plan,
    required this.term,
    required this.redeemedAt,
    required this.discountAmountMinor,
    required this.freeDurationDays,
    required this.commissionBasisPoints,
    required this.attributionReference,
  }) : couponCode = couponCode.trim().toUpperCase() {
    if (this.couponCode.isEmpty || userReference.trim().isEmpty) {
      throw ArgumentError('Coupon code and user reference are required.');
    }
    if (discountAmountMinor < 0 || freeDurationDays < 0) {
      throw ArgumentError('Resolved promotion values must be non-negative.');
    }
  }

  final String couponCode;
  final String userReference;
  final CommercePlan plan;
  final SubscriptionTerm term;
  final DateTime redeemedAt;
  final int discountAmountMinor;
  final int freeDurationDays;
  final int commissionBasisPoints;
  final String? attributionReference;
}
