import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/coupon_benefit.dart';
import 'package:body_intelligence_log/features/commerce/domain/coupon_definition.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_term.dart';
import 'package:body_intelligence_log/features/commerce/repositories/local_coupon_repository.dart';
import 'package:body_intelligence_log/features/commerce/services/coupon_promotion_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('promotion evaluation never grants runtime entitlements', () {
    final freeBefore = FreePlan.createState();
    final definition = CouponDefinition(
      code: 'PLUSYEAR',
      benefit: const CouponBenefit.freeDuration(days: 30),
      startsAt: DateTime.utc(2026),
      endsAt: DateTime.utc(2027),
      totalUsageLimit: 10,
      perUserUsageLimit: 1,
      eligiblePlans: const {CommercePlan.plus},
      eligibleTerms: const {SubscriptionTerm.oneYear},
      stackable: false,
      attributionSource: CouponAttributionSource.campaign,
    );
    final repository = LocalCouponRepository(coupons: [definition]);

    final decision = const CouponPromotionEngine().evaluate(
      request: PromotionRequest(
        couponCode: 'PLUSYEAR',
        userReference: 'user',
        plan: CommercePlan.plus,
        term: SubscriptionTerm.oneYear,
        subtotalMinor: 10000,
        currencyCode: 'USD',
        now: DateTime.utc(2026, 7, 23),
      ),
      repository: repository,
    );

    expect(decision.accepted, isTrue);
    expect(freeBefore.plan, CommercePlan.free);
    expect(
      freeBefore.grants(CommerceEntitlement.advancedIntelligence),
      isFalse,
    );
    expect(repository.redemptionsForCode('PLUSYEAR'), isEmpty);
  });

  test('evaluation is side-effect free until caller records redemption', () {
    final definition = CouponDefinition(
      code: 'MONTH10',
      benefit: const CouponBenefit.percentage(basisPoints: 1000),
      startsAt: DateTime.utc(2026),
      endsAt: DateTime.utc(2027),
      totalUsageLimit: 1,
      perUserUsageLimit: 1,
      eligiblePlans: const {CommercePlan.pro},
      eligibleTerms: const {SubscriptionTerm.oneMonth},
      stackable: false,
      attributionSource: CouponAttributionSource.blogger,
      ownerReference: 'blogger-1',
      commissionBasisPoints: 500,
    );
    final repository = LocalCouponRepository(coupons: [definition]);
    final request = PromotionRequest(
      couponCode: 'month10',
      userReference: 'user',
      plan: CommercePlan.pro,
      term: SubscriptionTerm.oneMonth,
      subtotalMinor: 10000,
      currencyCode: 'USD',
      now: DateTime.utc(2026, 7, 23),
    );

    final first = const CouponPromotionEngine().evaluate(
      request: request,
      repository: repository,
    );
    final second = const CouponPromotionEngine().evaluate(
      request: request,
      repository: repository,
    );

    expect(first.accepted, isTrue);
    expect(second.accepted, isTrue);
    expect(repository.redemptionsForCode('MONTH10'), isEmpty);
  });
}
