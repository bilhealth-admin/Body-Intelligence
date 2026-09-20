import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/presentation/workout_access_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('free workout stays available without commerce configuration', () {
    expect(workoutAccessGranted(WellnessContentAccess.free, null), isTrue);
  });

  test('paid workout fails closed without verified server authority', () {
    expect(workoutAccessGranted(WellnessContentAccess.plus, null), isFalse);
    expect(
      workoutAccessGranted(
        WellnessContentAccess.plus,
        _state(CommercePlan.free, EntitlementAuthority.localDefault),
      ),
      isFalse,
    );
  });

  test('verified plan hierarchy grants only its documented levels', () {
    final plus = _state(CommercePlan.plus, EntitlementAuthority.verifiedServer);
    final pro = _state(CommercePlan.pro, EntitlementAuthority.verifiedServer);
    final premium = _state(
      CommercePlan.premium,
      EntitlementAuthority.verifiedServer,
    );
    final premiumAiCoach = _state(
      CommercePlan.premiumAiCoach,
      EntitlementAuthority.verifiedServer,
    );

    expect(workoutAccessGranted(WellnessContentAccess.plus, plus), isTrue);
    expect(workoutAccessGranted(WellnessContentAccess.pro, plus), isFalse);
    expect(workoutAccessGranted(WellnessContentAccess.plus, pro), isTrue);
    expect(workoutAccessGranted(WellnessContentAccess.pro, pro), isTrue);
    expect(workoutAccessGranted(WellnessContentAccess.coach, pro), isFalse);
    expect(workoutAccessGranted(WellnessContentAccess.pro, premium), isTrue);
    expect(
      workoutAccessGranted(WellnessContentAccess.pro, premiumAiCoach),
      isTrue,
    );
    expect(
      workoutAccessGranted(WellnessContentAccess.coach, premiumAiCoach),
      isFalse,
    );
  });

  test('stale or revoked verified snapshots cannot retain paid access', () {
    expect(
      workoutAccessGranted(
        WellnessContentAccess.plus,
        _state(
          CommercePlan.pro,
          EntitlementAuthority.verifiedServer,
          lifecycle: SubscriptionLifecycle.revoked,
        ),
      ),
      isFalse,
    );
    expect(
      workoutAccessGranted(
        WellnessContentAccess.plus,
        _state(
          CommercePlan.pro,
          EntitlementAuthority.verifiedServer,
          currentPeriodEndsAt: DateTime.utc(2020),
        ),
      ),
      isFalse,
    );
  });
}

SubscriptionState _state(
  CommercePlan plan,
  EntitlementAuthority authority, {
  SubscriptionLifecycle lifecycle = SubscriptionLifecycle.active,
  DateTime? currentPeriodEndsAt,
}) => SubscriptionState(
  plan: plan,
  entitlements: const {},
  authority: authority,
  lifecycle: lifecycle,
  currentPeriodEndsAt: currentPeriodEndsAt ?? DateTime.utc(2099),
  isPurchasable: false,
  canRestorePurchases: false,
);
