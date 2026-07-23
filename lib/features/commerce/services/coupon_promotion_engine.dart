import '../domain/commerce_plan.dart';
import '../domain/coupon_benefit.dart';
import '../domain/coupon_definition.dart';
import '../domain/coupon_redemption.dart';
import '../domain/promotion_decision.dart';
import '../domain/subscription_term.dart';
import '../repositories/coupon_repository.dart';

/// Immutable input for one local coupon evaluation.
final class PromotionRequest {
  PromotionRequest({
    required String couponCode,
    required this.userReference,
    required this.plan,
    required this.term,
    required this.subtotalMinor,
    required this.currencyCode,
    required this.now,
    this.appliedCoupons = const <CouponDefinition>[],
  }) : couponCode = CouponDefinition.normalizeCode(couponCode) {
    if (this.couponCode.isEmpty || userReference.trim().isEmpty) {
      throw ArgumentError('Coupon code and user reference are required.');
    }
    if (subtotalMinor < 0) {
      throw ArgumentError.value(
        subtotalMinor,
        'subtotalMinor',
        'must be non-negative',
      );
    }
    if (currencyCode.trim().length != 3) {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'must be a 3-letter ISO currency code',
      );
    }
  }

  final String couponCode;
  final String userReference;
  final CommercePlan plan;
  final SubscriptionTerm term;
  final int subtotalMinor;
  final String currencyCode;
  final DateTime now;
  final List<CouponDefinition> appliedCoupons;
}

/// Deterministic local evaluator. It never performs payment or grants access.
final class CouponPromotionEngine {
  const CouponPromotionEngine();

  PromotionDecision evaluate({
    required PromotionRequest request,
    required CouponRepository repository,
  }) {
    final coupon = repository.findByCode(request.couponCode);
    if (coupon == null) {
      return const PromotionDecision.rejected(
        PromotionRejectionReason.unknownCoupon,
      );
    }
    if (!coupon.isActiveAt(request.now)) {
      return const PromotionDecision.rejected(
        PromotionRejectionReason.inactive,
      );
    }

    final codeRedemptions = repository.redemptionsForCode(coupon.code);
    if (codeRedemptions.length >= coupon.totalUsageLimit) {
      return const PromotionDecision.rejected(
        PromotionRejectionReason.totalUsageLimitReached,
      );
    }

    final userUsage = repository
        .redemptionsForUser(request.userReference)
        .where((item) => item.couponCode == coupon.code)
        .length;
    if (userUsage >= coupon.perUserUsageLimit) {
      return const PromotionDecision.rejected(
        PromotionRejectionReason.perUserUsageLimitReached,
      );
    }
    if (!coupon.eligiblePlans.contains(request.plan)) {
      return const PromotionDecision.rejected(
        PromotionRejectionReason.planNotEligible,
      );
    }
    if (!coupon.eligibleTerms.contains(request.term)) {
      return const PromotionDecision.rejected(
        PromotionRejectionReason.termNotEligible,
      );
    }
    if (request.appliedCoupons.isNotEmpty &&
        (!coupon.stackable ||
            request.appliedCoupons.any((item) => !item.stackable))) {
      return const PromotionDecision.rejected(
        PromotionRejectionReason.stackingNotAllowed,
      );
    }

    final discountAmountMinor = switch (coupon.benefit.type) {
      CouponBenefitType.percentage =>
        (request.subtotalMinor * coupon.benefit.percentageBasisPoints!) ~/
            10000,
      CouponBenefitType.fixedAmount =>
        coupon.benefit.fixedAmountMinor! > request.subtotalMinor
            ? request.subtotalMinor
            : coupon.benefit.fixedAmountMinor!,
      CouponBenefitType.freeDuration => 0,
    };
    final freeDurationDays = coupon.benefit.freeDurationDays ?? 0;

    final redemption = CouponRedemption(
      couponCode: coupon.code,
      userReference: request.userReference,
      plan: request.plan,
      term: request.term,
      redeemedAt: request.now.toUtc(),
      discountAmountMinor: discountAmountMinor,
      freeDurationDays: freeDurationDays,
      commissionBasisPoints: coupon.commissionBasisPoints,
      attributionReference: coupon.ownerReference,
    );

    return PromotionDecision.accepted(
      discountAmountMinor: discountAmountMinor,
      freeDurationDays: freeDurationDays,
      redemption: redemption,
    );
  }
}
