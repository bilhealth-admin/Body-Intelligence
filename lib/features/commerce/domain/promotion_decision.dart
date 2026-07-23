import 'coupon_redemption.dart';

/// Deterministic rejection vocabulary for promotion evaluation.
enum PromotionRejectionReason {
  unknownCoupon,
  inactive,
  totalUsageLimitReached,
  perUserUsageLimitReached,
  planNotEligible,
  termNotEligible,
  stackingNotAllowed,
  currencyMismatch,
}

/// Result of evaluating one coupon against local facts.
final class PromotionDecision {
  const PromotionDecision._({
    required this.accepted,
    required this.discountAmountMinor,
    required this.freeDurationDays,
    required this.rejectionReason,
    required this.redemption,
  });

  const PromotionDecision.rejected(PromotionRejectionReason reason)
    : this._(
        accepted: false,
        discountAmountMinor: 0,
        freeDurationDays: 0,
        rejectionReason: reason,
        redemption: null,
      );

  const PromotionDecision.accepted({
    required int discountAmountMinor,
    required int freeDurationDays,
    required CouponRedemption redemption,
  }) : this._(
         accepted: true,
         discountAmountMinor: discountAmountMinor,
         freeDurationDays: freeDurationDays,
         rejectionReason: null,
         redemption: redemption,
       );

  final bool accepted;
  final int discountAmountMinor;
  final int freeDurationDays;
  final PromotionRejectionReason? rejectionReason;
  final CouponRedemption? redemption;
}
