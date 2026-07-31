import 'commerce_plan.dart';
import 'coupon_benefit.dart';
import 'subscription_term.dart';

/// Marketing attribution attached to a coupon code.
enum CouponAttributionSource {
  campaign,
  celebrity,
  blogger,
  affiliate,
  partner,
}

/// Immutable coupon/promotion policy definition.
final class CouponDefinition {
  CouponDefinition({
    required String code,
    required this.benefit,
    required this.startsAt,
    required this.endsAt,
    required this.totalUsageLimit,
    required this.perUserUsageLimit,
    required Set<CommercePlan> eligiblePlans,
    required Set<SubscriptionTerm> eligibleTerms,
    required this.stackable,
    required this.attributionSource,
    this.ownerReference,
    this.commissionBasisPoints = 0,
  }) : code = normalizeCode(code),
       eligiblePlans = Set.unmodifiable(eligiblePlans),
       eligibleTerms = Set.unmodifiable(eligibleTerms) {
    if (this.code.isEmpty) {
      throw ArgumentError.value(code, 'code', 'must not be empty');
    }
    if (!endsAt.toUtc().isAfter(startsAt.toUtc())) {
      throw ArgumentError('endsAt must be after startsAt.');
    }
    if (totalUsageLimit <= 0) {
      throw ArgumentError.value(
        totalUsageLimit,
        'totalUsageLimit',
        'must be positive',
      );
    }
    if (perUserUsageLimit <= 0 || perUserUsageLimit > totalUsageLimit) {
      throw ArgumentError.value(
        perUserUsageLimit,
        'perUserUsageLimit',
        'must be positive and not exceed totalUsageLimit',
      );
    }
    if (eligiblePlans.isEmpty || eligibleTerms.isEmpty) {
      throw ArgumentError('Coupon eligibility sets must not be empty.');
    }
    if (commissionBasisPoints < 0 || commissionBasisPoints > 10000) {
      throw ArgumentError.value(
        commissionBasisPoints,
        'commissionBasisPoints',
        'must be between 0 and 10000',
      );
    }
    if (commissionBasisPoints > 0 &&
        (ownerReference == null || ownerReference!.trim().isEmpty)) {
      throw ArgumentError(
        'Commission-bearing coupons require an ownerReference.',
      );
    }
  }

  final String code;
  final CouponBenefit benefit;
  final DateTime startsAt;
  final DateTime endsAt;
  final int totalUsageLimit;
  final int perUserUsageLimit;
  final Set<CommercePlan> eligiblePlans;
  final Set<SubscriptionTerm> eligibleTerms;
  final bool stackable;
  final CouponAttributionSource attributionSource;
  final String? ownerReference;
  final int commissionBasisPoints;

  bool isActiveAt(DateTime now) {
    final instant = now.toUtc();
    return !instant.isBefore(startsAt.toUtc()) &&
        !instant.isAfter(endsAt.toUtc());
  }

  static String normalizeCode(String value) => value.trim().toUpperCase();
}
