import 'package:body_intelligence_log/app/analytics/bil_launch_deep_link.dart';
import 'package:body_intelligence_log/app/analytics/bil_launch_event.dart';
import 'package:body_intelligence_log/app/analytics/bil_incoming_link_controller.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/domain/storefront_context.dart';
import 'package:body_intelligence_log/features/commerce/services/subscription_lifecycle_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deep links accept only BIL hosts/routes and safe campaign fields', () {
    final link = BilLaunchDeepLink.parse(
      Uri.parse(
        'https://bilhealth.com/plans?utm_source=google&utm_campaign=launch&email=x',
      ),
    );
    expect(link?.route, '/plans');
    expect(link?.attribution, {
      'utm_source': 'google',
      'utm_campaign': 'launch',
    });
    expect(
      BilLaunchDeepLink.parse(Uri.parse('https://evil.test/plans')),
      isNull,
    );
    expect(BilLaunchDeepLink.parse(Uri.parse('bil://unknown')), isNull);
    expect(
      BilLaunchDeepLink.parse(Uri.parse('bil://connected-health'))?.route,
      '/connected-health',
    );
    expect(BilLaunchDeepLink.parse(Uri.parse('bil://goals'))?.route, '/goals');
    expect(
      BilLaunchDeepLink.parse(
        Uri.parse('bil://analytics/nutrition?tab=macros&token=secret'),
      )?.route,
      '/analytics/nutrition?tab=macros',
    );
  });

  test(
    'incoming-link hook navigates and emits privacy-safe attribution',
    () async {
      final sink = _Sink();
      String? route;
      final controller = BilIncomingLinkController(
        analytics: sink,
        navigate: (value) => route = value,
        clock: () => DateTime.utc(2026, 8, 12),
      );
      expect(
        await controller.handle(
          Uri.parse('bil://plans?utm_source=partner&utm_campaign=summer'),
        ),
        isTrue,
      );
      expect(route, '/plans');
      expect(sink.events.map((event) => event.name), [
        BilLaunchEventName.deepLinkOpened,
        BilLaunchEventName.campaignAttributionCaptured,
      ]);
      expect(sink.events.every((event) => event.privacySafe), isTrue);
      expect(
        await controller.handle(Uri.parse('https://evil.test/plans')),
        false,
      );
      expect(await controller.handle(Uri.parse('bil://goals')), isTrue);
      expect(route, '/goals');
    },
  );

  test('locale/country/units normalize without inferring currency', () {
    final context = BilStorefrontContext.normalize(
      languageTag: 'pt_BR',
      countryCode: 'br',
      unitsPreference: 'imperial',
    );
    expect(context.languageTag, 'pt-BR');
    expect(context.countryCode, 'BR');
    expect(context.measurementSystem, BilMeasurementSystem.imperial);
    expect(
      BilStorefrontContext.normalize(
        languageTag: '../bad',
        countryCode: 'unknown',
        unitsPreference: 'metric',
      ).languageTag,
      'en',
    );
  });

  test(
    'restore records success only after verified entitlement refresh',
    () async {
      final gateway = _Gateway();
      final sink = _Sink();
      final coordinator = SubscriptionLifecycleCoordinator(
        catalog: gateway,
        analytics: sink,
        hasVerifiedEntitlement: () async => true,
        clock: () => DateTime.utc(2026, 8, 12),
      );
      expect(await coordinator.restoreAndRefresh(), isTrue);
      expect(gateway.restoreCalls, 1);
      expect(sink.events.map((event) => event.name), [
        BilLaunchEventName.subscriptionStatusRefreshed,
        BilLaunchEventName.purchasesRestored,
      ]);
      expect(sink.events.every((event) => event.privacySafe), isTrue);
    },
  );

  test('failed entitlement refresh never records purchases restored', () async {
    final gateway = _Gateway();
    final sink = _Sink();
    final coordinator = SubscriptionLifecycleCoordinator(
      catalog: gateway,
      analytics: sink,
      hasVerifiedEntitlement: () async => false,
      clock: () => DateTime.utc(2026, 8, 12),
    );
    expect(await coordinator.restoreAndRefresh(), isFalse);
    expect(sink.events.map((event) => event.name), [
      BilLaunchEventName.subscriptionStatusRefreshed,
    ]);
  });
}

final class _Gateway implements BilStoreCatalogGateway {
  int restoreCalls = 0;
  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(
    Set<String> productIds,
  ) async => const [];
  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {}
  @override
  Future<void> restorePurchases() async => restoreCalls++;
  @override
  Future<void> openManageSubscriptions() async {}
}

final class _Sink implements BilLaunchAnalyticsSink {
  final events = <BilLaunchEvent>[];
  @override
  Future<void> record(BilLaunchEvent event) async => events.add(event);
}
