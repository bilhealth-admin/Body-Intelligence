/// Supported coupon benefit shapes.
enum CouponBenefitType { percentage, fixedAmount, freeDuration }

/// Immutable promotion value using deterministic integer units.
///
/// Percentages use basis points (10_000 = 100%). Fixed amounts use minor
/// currency units. Free durations use whole days.
final class CouponBenefit {
  const CouponBenefit.percentage({required int basisPoints})
    : type = CouponBenefitType.percentage,
      percentageBasisPoints = basisPoints,
      fixedAmountMinor = null,
      freeDurationDays = null,
      assert(basisPoints > 0 && basisPoints <= 10000);

  const CouponBenefit.fixedAmount({required int amountMinor})
    : type = CouponBenefitType.fixedAmount,
      percentageBasisPoints = null,
      fixedAmountMinor = amountMinor,
      freeDurationDays = null,
      assert(amountMinor > 0);

  const CouponBenefit.freeDuration({required int days})
    : type = CouponBenefitType.freeDuration,
      percentageBasisPoints = null,
      fixedAmountMinor = null,
      freeDurationDays = days,
      assert(days > 0);

  final CouponBenefitType type;
  final int? percentageBasisPoints;
  final int? fixedAmountMinor;
  final int? freeDurationDays;
}
