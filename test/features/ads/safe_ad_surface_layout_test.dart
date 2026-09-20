import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/presentation/safe_free_ad_anchor.dart';
import 'package:body_intelligence_log/features/ads/providers/ad_providers.dart';
import 'package:body_intelligence_log/features/ads/services/contextual_ad_gateway.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('390x844 Wellness keeps a loaded banner below carousel dots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verifiedEntitlementOwnerProvider.overrideWith(
            (_) => Stream.value('test-owner'),
          ),
          verifiedSubscriptionStateProvider.overrideWith(
            (_) async => SubscriptionState(
              plan: CommercePlan.free,
              entitlements: const {},
              authority: EntitlementAuthority.verifiedServer,
              isPurchasable: false,
              canRestorePurchases: false,
            ),
          ),
          contextualAdGatewayProvider.overrideWithValue(
            const _LayoutBannerGateway(),
          ),
          adOnlineProvider.overrideWith((_) => Stream.value(true)),
          adAgeEligibilityProvider.overrideWith((_) => AdAgeEligibility.adult),
        ],
        child: const MaterialApp(home: WellnessLibraryPage()),
      ),
    );
    await tester.pumpAndSettle();

    final indicator = find.byKey(
      const Key('wellness-discovery-page-indicator'),
    );
    final anchor = find.byKey(const Key('wellness-discovery-free-ad-slot'));
    expect(indicator, findsOneWidget);
    expect(anchor, findsOneWidget);
    expect(
      tester.getBottomLeft(indicator).dy,
      lessThan(tester.getTopLeft(anchor).dy),
    );
    expect(tester.getSize(find.byType(SafeFreeAdAnchor)).height, 78);
    expect(find.byKey(const Key('layout-banner')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _LayoutBannerGateway implements ContextualBannerGateway {
  const _LayoutBannerGateway();

  @override
  bool get isConfigured => true;

  @override
  Future<ContextualBannerHandle?> loadBanner(AdPlacement placement) async {
    expect(placement, AdPlacement.generalDiscovery);
    return const _LayoutBannerHandle();
  }

  @override
  Future<ContextualAdResult> show(AdPlacement placement) async =>
      ContextualAdResult.unavailable;
}

final class _LayoutBannerHandle implements ContextualBannerHandle {
  const _LayoutBannerHandle();

  @override
  double get height => 50;

  @override
  Widget get widget =>
      const SizedBox(key: Key('layout-banner'), width: 320, height: 50);

  @override
  void dispose() {}
}
