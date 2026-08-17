import 'dart:io';

import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/entitlement_resolver.dart';
import 'package:body_intelligence_log/features/commerce/domain/plan_policy.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_record.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('server entitlement truth', () {
    SubscriptionRecord record(SubscriptionLifecycle lifecycle) =>
        SubscriptionRecord(
          plan: CommercePlan.premium,
          lifecycle: lifecycle,
          authorityVerified: true,
          provider: SubscriptionProvider.google,
          startedAt: DateTime.utc(2026, 1),
          currentPeriodEndsAt: DateTime.utc(2026, 2),
          gracePeriodEndsAt: DateTime.utc(2026, 2, 3),
        );

    test('pending, hold, paused, refund and revocation never grant paid', () {
      const resolver = EntitlementResolver();
      for (final lifecycle in <SubscriptionLifecycle>[
        SubscriptionLifecycle.pending,
        SubscriptionLifecycle.billingRetry,
        SubscriptionLifecycle.accountHold,
        SubscriptionLifecycle.paused,
        SubscriptionLifecycle.suspended,
        SubscriptionLifecycle.deferred,
        SubscriptionLifecycle.expired,
        SubscriptionLifecycle.refunded,
        SubscriptionLifecycle.revoked,
      ]) {
        expect(
          resolver
              .resolve(
                record: record(lifecycle),
                now: DateTime.utc(2026, 1, 15),
              )
              .plan,
          CommercePlan.free,
          reason: '$lifecycle must fail closed',
        );
      }
    });

    test('active and dated grace access expire at their server boundary', () {
      const resolver = EntitlementResolver();
      expect(
        resolver
            .resolve(
              record: record(SubscriptionLifecycle.active),
              now: DateTime.utc(2026, 1, 15),
            )
            .plan,
        CommercePlan.premium,
      );
      expect(
        resolver
            .resolve(
              record: record(SubscriptionLifecycle.gracePeriod),
              now: DateTime.utc(2026, 2, 4),
            )
            .plan,
        CommercePlan.free,
      );
    });

    test('only canonical Premium tiers are consumer subscriptions', () {
      expect(
        PlanPolicyCatalog.policies[CommercePlan.plus]!.exposure,
        StoreExposure.hidden,
      );
      expect(
        PlanPolicyCatalog.policies[CommercePlan.pro]!.exposure,
        StoreExposure.hidden,
      );
      expect(
        PlanPolicyCatalog.policies[CommercePlan.premium]!.exposure,
        StoreExposure.consumerSubscription,
      );
      expect(
        PlanPolicyCatalog.policies[CommercePlan.premiumAiCoach]!.exposure,
        StoreExposure.consumerSubscription,
      );
      for (final plan in <CommercePlan>[
        CommercePlan.coach,
        CommercePlan.clinic,
        CommercePlan.enterprise,
      ]) {
        expect(
          PlanPolicyCatalog.policies[plan]!.exposure,
          StoreExposure.contractOnly,
        );
      }
    });

    test('Premium grants every free capability plus sync and intelligence', () {
      final free = PlanPolicyCatalog.policies[CommercePlan.free]!.entitlements;
      final premium =
          PlanPolicyCatalog.policies[CommercePlan.premium]!.entitlements;
      final coach =
          PlanPolicyCatalog.policies[CommercePlan.premiumAiCoach]!.entitlements;
      expect(premium, containsAll(free));
      expect(premium, contains(CommerceEntitlement.cloudSync));
      expect(premium, contains(CommerceEntitlement.advancedIntelligence));
      expect(coach, containsAll(premium));
    });

    test('missing owner configuration exposes no invented products', () {
      expect(StoreCatalogConfiguration.consumerProductsConfigured, isFalse);
      expect(StoreCatalogConfiguration.productIds, isEmpty);
    });
  });

  testWidgets('unconfigured paywall is honest and localized', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        supportedLocales: [Locale('fr')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: BilStorePlansPage(connectToDeviceStore: false),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('Gratuit'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Premium AI Coach'), findsOneWidget);
    expect(find.text('BIL AI Boost'), findsOneWidget);
    expect(find.text('Prix indisponible sur cet appareil'), findsNWidgets(3));
    // No price, discount, or unavailable tier is invented without live store
    // metadata and configured owner product identifiers.
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  test('server verification is replay-safe and store-authoritative', () {
    final migration = File(
      'supabase/migrations/202608040004_bil_store_entitlement_truth.sql',
    ).readAsStringSync();
    final backend = File(
      'supabase/functions/verify-store-purchase/store_backend.ts',
    ).readAsStringSync();
    final client = File(
      'lib/features/commerce/services/verified_store_purchase_service.dart',
    ).readAsStringSync();
    final canonicalMigration = File(
      'supabase/migrations/202608160001_bil_canonical_consumer_tiers.sql',
    ).readAsStringSync();

    expect(migration, contains('unique (provider, original_transaction_id)'));
    expect(migration, contains('bil_claim_store_notification'));
    expect(backend, contains('purchases/subscriptionsv2/tokens'));
    expect(backend, contains('signedPayload'));
    expect(backend, contains('apple_chain_untrusted'));
    expect(backend, contains('digestBytes(decodeBase64Bytes'));
    expect(backend, contains('purchases/voidedpurchases'));
    expect(backend, contains('appleServerStatusLifecycle'));
    expect(backend, contains('scheduled_reconciliation_failed'));
    expect(client, contains('purchase.status'));
    expect(
      client,
      contains('if (verified && purchase.pendingCompletePurchase)'),
    );
    expect(client, isNot(contains('SharedPreferences')));
    expect(canonicalMigration, contains("when 'pro' then 'premium'"));
    expect(canonicalMigration, contains("when 'plus' then 'legacy_plus'"));
    expect(
      canonicalMigration,
      contains("plan_id in ('premium', 'premium_ai_coach')"),
    );
    expect(canonicalMigration, contains('bil_ai_coach_subscriptions'));
    expect(canonicalMigration, contains("new.plan_id = 'premium_ai_coach'"));
  });
}
