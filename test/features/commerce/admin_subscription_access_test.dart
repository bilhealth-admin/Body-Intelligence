import 'package:body_intelligence_log/features/commerce/domain/admin_subscription_access.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/entitlement_resolver.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_record.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets(
    'a mounted Coach gate observes grants and revocation without a Premium lookup',
    (tester) async {
      var remaining = 0, subscriptionLoads = 0;
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerProvider.overrideWith(
            (_) => Stream.value('owner'),
          ),
          verifiedEntitlementLoaderProvider.overrideWithValue(() async {
            subscriptionLoads++;
            return FreePlan.createState();
          }),
          aiCoachUsageStatusLoaderProvider.overrideWithValue(
            () async => {
              'credits': {'total_remaining': remaining},
            },
          ),
        ],
      );
      final listener = container.listen(aiCoachCreditAccessProvider, (_, _) {});
      await tester.pump();
      await tester.pump();
      expect(await container.read(aiCoachCreditAccessProvider.future), isFalse);
      remaining = 2500;
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(await container.read(aiCoachCreditAccessProvider.future), isTrue);
      remaining = 0;
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(await container.read(aiCoachCreditAccessProvider.future), isFalse);
      expect(subscriptionLoads, 0);
      listener.close();
      await tester.pump();
      container.dispose();
    },
  );
  testWidgets(
    'observed rights and credit access refresh together, without background overlap',
    (tester) async {
      var rightsLoads = 0, creditLoads = 0;
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerProvider.overrideWith(
            (_) => Stream.value('owner'),
          ),
          verifiedEntitlementLoaderProvider.overrideWithValue(() async {
            rightsLoads++;
            return FreePlan.createState();
          }),
          aiCoachUsageStatusLoaderProvider.overrideWithValue(() async {
            creditLoads++;
            return {
              'credits': {'total_remaining': 10},
            };
          }),
        ],
      );
      final rights = container.listen(
        verifiedSubscriptionStateProvider,
        (_, _) {},
      );
      final credits = container.listen(aiCoachCreditAccessProvider, (_, _) {});
      await tester.pump();
      await tester.pump();
      final initialRights = rightsLoads, initialCredits = creditLoads;
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(rightsLoads, greaterThan(initialRights));
      expect(creditLoads, greaterThan(initialCredits));
      rights.close();
      credits.close();
      await tester.pump();
      final stopped = rightsLoads;
      await tester.pump(const Duration(minutes: 1));
      expect(rightsLoads, stopped);
      container.dispose();
    },
  );
  final now = DateTime.utc(2026, 9, 10, 1);
  final grant = <String, Object?>{
    'owner_id': 'owner',
    'plan_id': 'premium_ai_coach',
    'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
    'expires_at': null,
    'access_until': now.add(const Duration(minutes: 5)).toIso8601String(),
  };
  SubscriptionState resolve(Object? input, [SubscriptionState? store]) =>
      composeAdminSubscriptionAccess(
        store: store ?? FreePlan.createState(),
        grant: input,
        ownerId: 'owner',
        now: now,
      );
  SubscriptionState paid(SubscriptionProvider provider, CommercePlan plan) =>
      const EntitlementResolver().resolve(
        record: SubscriptionRecord(
          plan: plan,
          lifecycle: SubscriptionLifecycle.active,
          authorityVerified: true,
          provider: provider,
          currentPeriodEndsAt: now.add(const Duration(days: 30)),
        ),
        now: now,
      );

  test('gift unlocks the selected plan with no fake store provider', () {
    final result = resolve(grant);
    expect(result.plan, CommercePlan.premiumAiCoach);
    expect(result.provider, isNull);
    expect(result.authority, EntitlementAuthority.verifiedServer);
    expect(result.canRestorePurchases, isFalse);
    expect(
      resolve({...grant, 'plan_id': 'premium'}).plan,
      CommercePlan.premium,
    );
  });
  test(
    'missing, malformed, expired, other-owner or overlong leases cannot unlock access',
    () {
      for (final row in [
        null,
        {},
        false,
        {...grant, 'owner_id': 'another'},
        {...grant, 'plan_id': 'enterprise'},
        {...grant, 'access_until': now.toIso8601String()},
        {
          ...grant,
          'access_until': now.add(const Duration(days: 1)).toIso8601String(),
        },
        {...grant, 'expires_at': 'invalid'},
        {...grant, 'expires_at': now.toIso8601String()},
        {
          ...grant,
          'created_at': now.add(const Duration(days: 1)).toIso8601String(),
        },
      ]) {
        expect(resolve(row).plan, CommercePlan.free, reason: '$row');
      }
    },
  );
  for (final provider in [
    SubscriptionProvider.apple,
    SubscriptionProvider.google,
  ]) {
    test('grant or revocation never overwrites $provider paid AI access', () {
      final store = paid(provider, CommercePlan.premiumAiCoach);
      expect(resolve(grant, store), same(store));
      expect(resolve({...grant, 'plan_id': 'premium'}, store), same(store));
      expect(resolve(null, store), same(store));
    });
    test(
      'AI gift layers over $provider Premium and revocation falls back to its unchanged receipt',
      () {
        final store = paid(provider, CommercePlan.premium);
        final composed = resolve(grant, store);
        expect(composed.plan, CommercePlan.premiumAiCoach);
        expect(composed.provider, isNull);
        expect(composed.canRestorePurchases, isTrue);
        expect(store.plan, CommercePlan.premium);
        expect(resolve(null, store), same(store));
      },
    );
  }
  test(
    'AI route still depends on actual credits, not an admin Premium label',
    () {
      expect(
        aiCoachAccessFromUsageStatus({
          'plan': 'ai_coach',
          'credits': {'total_remaining': 0},
        }),
        isFalse,
      );
      expect(
        aiCoachAccessFromUsageStatus({
          'plan': 'free',
          'credits': {'total_remaining': 2485},
        }),
        isTrue,
      );
    },
  );
}
