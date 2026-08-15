import 'dart:io';

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
          plan: CommercePlan.pro,
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
        CommercePlan.pro,
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

    test('only Plus and Pro are consumer store plans', () {
      expect(
        PlanPolicyCatalog.policies[CommercePlan.plus]!.exposure,
        StoreExposure.consumerSubscription,
      );
      expect(
        PlanPolicyCatalog.policies[CommercePlan.pro]!.exposure,
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
        home: BilStorePlansPage(),
      ),
    );
    await tester.pump();
    expect(find.text('Offres'), findsOneWidget);
    expect(find.text('Mensuel'), findsOneWidget);
    expect(find.textContaining('Prix indisponible'), findsAtLeastNWidgets(1));
    expect(find.textContaining('14%'), findsNothing);
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
  });
}
