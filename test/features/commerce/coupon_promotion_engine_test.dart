import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/coupon_benefit.dart';
import 'package:body_intelligence_log/features/commerce/domain/coupon_definition.dart';
import 'package:body_intelligence_log/features/commerce/domain/promotion_decision.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_term.dart';
import 'package:body_intelligence_log/features/commerce/repositories/local_coupon_repository.dart';
import 'package:body_intelligence_log/features/commerce/services/coupon_promotion_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 23, 12);

  CouponDefinition coupon({
    CouponBenefit benefit = const CouponBenefit.percentage(basisPoints: 1500),
    bool stackable = false,
    int totalLimit = 100,
    int userLimit = 1,
  }) => CouponDefinition(
    code: 'Creator15',
    benefit: benefit,
    startsAt: DateTime.utc(2026, 7, 1),
    endsAt: DateTime.utc(2026, 12, 31),
    totalUsageLimit: totalLimit,
    perUserUsageLimit: userLimit,
    eligiblePlans: const {CommercePlan.plus, CommercePlan.pro},
    eligibleTerms: const {
      SubscriptionTerm.oneMonth,
      SubscriptionTerm.threeMonths,
      SubscriptionTerm.sixMonths,
      SubscriptionTerm.oneYear,
    },
    stackable: stackable,
    attributionSource: CouponAttributionSource.celebrity,
    ownerReference: 'creator-42',
    commissionBasisPoints: 800,
  );

  PromotionRequest request({
    String code = ' creator15 ',
    CommercePlan plan = CommercePlan.pro,
    SubscriptionTerm term = SubscriptionTerm.threeMonths,
    int subtotal = 20000,
    List<CouponDefinition> applied = const [],
  }) => PromotionRequest(
    couponCode: code,
    userReference: 'user-1',
    plan: plan,
    term: term,
    subtotalMinor: subtotal,
    currencyCode: 'USD',
    now: now,
    appliedCoupons: applied,
  );

  test('percentage coupon resolves deterministic discount and attribution', () {
    final definition = coupon();
    final repository = LocalCouponRepository(coupons: [definition]);

    final decision = const CouponPromotionEngine().evaluate(
      request: request(),
      repository: repository,
    );

    expect(decision.accepted, isTrue);
    expect(decision.discountAmountMinor, 3000);
    expect(decision.freeDurationDays, 0);
    expect(decision.redemption!.couponCode, 'CREATOR15');
    expect(decision.redemption!.commissionBasisPoints, 800);
    expect(decision.redemption!.attributionReference, 'creator-42');
  });

  test('fixed discount is capped at subtotal', () {
    final definition = coupon(
      benefit: const CouponBenefit.fixedAmount(amountMinor: 5000),
    );
    final repository = LocalCouponRepository(coupons: [definition]);

    final decision = const CouponPromotionEngine().evaluate(
      request: request(subtotal: 3000),
      repository: repository,
    );

    expect(decision.accepted, isTrue);
    expect(decision.discountAmountMinor, 3000);
  });

  test('free duration coupon supports one year term', () {
    final definition = coupon(
      benefit: const CouponBenefit.freeDuration(days: 30),
    );
    final repository = LocalCouponRepository(coupons: [definition]);

    final decision = const CouponPromotionEngine().evaluate(
      request: request(term: SubscriptionTerm.oneYear),
      repository: repository,
    );

    expect(decision.accepted, isTrue);
    expect(decision.discountAmountMinor, 0);
    expect(decision.freeDurationDays, 30);
  });

  test('plan, term, active window, and stacking are enforced', () {
    final definition = coupon();
    final repository = LocalCouponRepository(coupons: [definition]);
    final engine = const CouponPromotionEngine();

    expect(
      engine
          .evaluate(
            request: request(plan: CommercePlan.enterprise),
            repository: repository,
          )
          .rejectionReason,
      PromotionRejectionReason.planNotEligible,
    );
    expect(
      engine
          .evaluate(
            request: request(applied: [coupon(stackable: true)]),
            repository: repository,
          )
          .rejectionReason,
      PromotionRejectionReason.stackingNotAllowed,
    );
  });

  test('per-user and total reuse limits fail closed', () {
    final definition = coupon(totalLimit: 1, userLimit: 1);
    final repository = LocalCouponRepository(coupons: [definition]);
    final engine = const CouponPromotionEngine();
    final first = engine.evaluate(request: request(), repository: repository);
    repository.record(first.redemption!);

    final second = engine.evaluate(request: request(), repository: repository);
    expect(
      second.rejectionReason,
      PromotionRejectionReason.totalUsageLimitReached,
    );
  });
}
