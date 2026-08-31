import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_record.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_recovery_decision.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_recovery_policy.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_snapshot.dart';
import 'package:body_intelligence_log/features/commerce/services/subscription_recovery_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = SubscriptionRecoveryEngine();
  final policy = SubscriptionRecoveryPolicy(
    maximumOfflineAge: Duration(days: 3),
  );
  final now = DateTime.utc(2026, 7, 24, 12);

  SubscriptionSnapshot snapshot({
    SubscriptionLifecycle lifecycle = SubscriptionLifecycle.active,
    DateTime? verifiedAt,
    DateTime? periodEnd,
    DateTime? trialEnd,
    DateTime? graceEnd,
  }) => SubscriptionSnapshot(
    record: SubscriptionRecord(
      plan: CommercePlan.pro,
      lifecycle: lifecycle,
      authorityVerified: true,
      provider: SubscriptionProvider.apple,
      startedAt: now.subtract(const Duration(days: 10)),
      currentPeriodEndsAt: periodEnd,
      trialEndsAt: trialEnd,
      gracePeriodEndsAt: graceEnd,
    ),
    verifiedAt: verifiedAt ?? now.subtract(const Duration(hours: 1)),
    persistedAt: now,
  );

  test('recovery policy rejects negative offline authority windows', () {
    expect(
      () => SubscriptionRecoveryPolicy(
        maximumOfflineAge: const Duration(seconds: -1),
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('fresh active snapshot restores paid access without network', () {
    final decision = engine.recover(
      snapshot: snapshot(periodEnd: now.add(const Duration(days: 2))),
      policy: policy,
      now: now,
    );

    expect(decision.action, SubscriptionRecoveryAction.none);
    expect(decision.usedCachedRecord, isTrue);
    expect(decision.state.plan, CommercePlan.pro);
    expect(
      decision.state.grants(CommerceEntitlement.advancedIntelligence),
      isTrue,
    );
  });

  test('fresh trial expires and refreshes at the exact boundary', () {
    final decision = engine.recover(
      snapshot: snapshot(lifecycle: SubscriptionLifecycle.trial, trialEnd: now),
      policy: policy,
      now: now,
    );

    expect(decision.action, SubscriptionRecoveryAction.refreshFromProvider);
    expect(decision.state.plan, CommercePlan.free);
  });

  test('fresh grace snapshot restores through grace boundary', () {
    final decision = engine.recover(
      snapshot: snapshot(
        lifecycle: SubscriptionLifecycle.gracePeriod,
        periodEnd: now.subtract(const Duration(days: 1)),
        graceEnd: now.add(const Duration(hours: 6)),
      ),
      policy: policy,
      now: now,
    );

    expect(decision.action, SubscriptionRecoveryAction.none);
    expect(decision.state.plan, CommercePlan.pro);
  });

  test('stale snapshot fails closed and requests provider refresh', () {
    final decision = engine.recover(
      snapshot: snapshot(
        verifiedAt: now.subtract(const Duration(days: 4)),
        periodEnd: now.add(const Duration(days: 20)),
      ),
      policy: policy,
      now: now,
    );

    expect(decision.action, SubscriptionRecoveryAction.refreshFromProvider);
    expect(decision.usedCachedRecord, isFalse);
    expect(decision.state.plan, CommercePlan.free);
  });

  test('expired cached boundary falls back and requests refresh', () {
    final decision = engine.recover(
      snapshot: snapshot(periodEnd: now.subtract(const Duration(seconds: 1))),
      policy: policy,
      now: now,
    );

    expect(decision.action, SubscriptionRecoveryAction.refreshFromProvider);
    expect(decision.usedCachedRecord, isTrue);
    expect(decision.state.plan, CommercePlan.free);
  });

  test('missing snapshot requests restore while retaining Free access', () {
    final decision = engine.recover(snapshot: null, policy: policy, now: now);

    expect(decision.action, SubscriptionRecoveryAction.restoreFromProvider);
    expect(decision.usedCachedRecord, isFalse);
    expect(decision.state.plan, CommercePlan.free);
  });
}
