import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/presentation/safe_free_ad_anchor.dart';
import 'package:body_intelligence_log/features/ads/providers/ad_providers.dart';
import 'package:body_intelligence_log/features/ads/services/contextual_ad_gateway.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _BackgroundMountTestBinding();
  for (final initial in [
    AppLifecycleState.paused,
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.detached,
  ]) {
    testWidgets('slot mounted while $initial waits for resumed', (
      tester,
    ) async {
      final gateway = _Gateway();
      tester.binding.handleAppLifecycleStateChanged(initial);
      addTearDown(() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            verifiedEntitlementOwnerProvider.overrideWith(
              (_) => Stream.value('eligible-free-owner'),
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
            contextualAdGatewayProvider.overrideWithValue(gateway),
            adOnlineProvider.overrideWith((_) => Stream.value(true)),
            adAgeEligibilityProvider.overrideWith(
              (_) => AdAgeEligibility.adult,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SafeFreeAdAnchor(surface: SafeFreeAdSurface.more),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(gateway.loads, 0);
      expect(find.byKey(const Key('lifecycle-test-banner')), findsNothing);
      expect(tester.getSize(find.byType(SafeFreeAdAnchor)).height, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(gateway.loads, 1);
      expect(find.byKey(const Key('lifecycle-test-banner')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

// Deliberately permit test-driven construction even when real background
// scheduling would suspend frames, so the slot's own foreground boundary is
// exercised instead of passing because no widget was mounted at all.
final class _BackgroundMountTestBinding
    extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get framesEnabled => true;
}

final class _Gateway implements ContextualBannerGateway {
  int loads = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<ContextualBannerHandle?> loadBanner(AdPlacement placement) async {
    loads++;
    return _Handle();
  }

  @override
  Future<ContextualAdResult> show(AdPlacement placement) async =>
      ContextualAdResult.unavailable;
}

final class _Handle implements ContextualBannerHandle {
  @override
  double get height => 50;

  @override
  Widget get widget =>
      const SizedBox(key: Key('lifecycle-test-banner'), width: 320, height: 50);

  @override
  void dispose() {}
}
