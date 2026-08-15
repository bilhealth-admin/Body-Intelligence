import 'package:body_intelligence_log/app/analytics/bil_launch_event.dart';
import 'package:body_intelligence_log/app/analytics/consented_launch_analytics_sink.dart';
import 'package:body_intelligence_log/app/launch/bil_verified_links_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_metadata_readiness.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verified-link documents stay absent without owner signing values', () {
    expect(BilVerifiedLinksConfiguration.assetLinksJson(), isNull);
    expect(BilVerifiedLinksConfiguration.appleAppSiteAssociationJson(), isNull);
  });

  test(
    'analytics adapter requires consent and rejects unsafe events',
    () async {
      final delegate = _Sink();
      var consent = false;
      final sink = ConsentedLaunchAnalyticsSink(
        consentGranted: () => consent,
        delegate: delegate,
      );
      final event = BilLaunchEvent(
        name: BilLaunchEventName.paywallImpression,
        occurredAt: DateTime.utc(2026, 8, 12),
        properties: const {'locale': 'en'},
      );
      await sink.record(event);
      expect(delegate.events, isEmpty);
      consent = true;
      await sink.record(event);
      expect(delegate.events, [event]);
      await expectLater(
        sink.record(
          BilLaunchEvent(
            name: BilLaunchEventName.signupCompleted,
            occurredAt: DateTime.utc(2026, 8, 12),
            properties: const {'phone': 'redacted'},
          ),
        ),
        throwsStateError,
      );
    },
  );

  test('store metadata validates currency, term and trial coherently', () {
    const valid = BilStoreOfferMetadata(
      productId: 'owner_product',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Monthly',
      localizedPrice: 'EGP 99.00',
      currencyCode: 'EGP',
      priceMicros: 99000000,
      billingPeriodIso8601: 'P1M',
      trialEligible: true,
      trialPeriodIso8601: 'P7D',
    );
    expect(BilStoreMetadataReadiness.issues(valid), isEmpty);
    expect(
      BilStoreMetadataReadiness.issues(
        const BilStoreOfferMetadata(
          productId: 'bad',
          kind: BilStoreProductKind.premiumSubscription,
          localizedTitle: 'Bad',
          localizedPrice: '1',
          currencyCode: 'egp',
          priceMicros: 1,
          trialEligible: true,
        ),
      ),
      containsAll([
        'invalid_currency_code',
        'unsupported_subscription_period',
        'trial_period_missing',
      ]),
    );
  });

  test('consumable metadata cannot masquerade as a subscription', () {
    const boostWithPeriod = BilStoreOfferMetadata(
      productId: 'bil_ai_boost',
      kind: BilStoreProductKind.aiBoostConsumable,
      localizedTitle: 'BIL AI Boost',
      localizedPrice: 'Store price',
      currencyCode: 'USD',
      priceMicros: 1,
      billingPeriodIso8601: 'P1M',
    );
    expect(
      BilStoreMetadataReadiness.issues(boostWithPeriod),
      contains('consumable_has_billing_period'),
    );
  });
}

final class _Sink implements BilLaunchAnalyticsSink {
  final events = <BilLaunchEvent>[];
  @override
  Future<void> record(BilLaunchEvent event) async => events.add(event);
}
