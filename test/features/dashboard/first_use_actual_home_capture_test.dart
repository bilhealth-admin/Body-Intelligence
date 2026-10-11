import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/visual_evidence_font.dart';
import 'first_use_reference_journey_test.dart'
    show journeyApp, journeyRouter, capture;

final class _UnavailableHealth implements ConnectedHealthGateway {
  @override
  Future<ConnectedHealthSnapshot> load() async =>
      const ConnectedHealthSnapshot.unavailable();
  @override
  Future<ConnectedHealthSnapshot> synchronize() => load();
  @override
  Future<ConnectedHealthSnapshot> requestPermissions() => load();
  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() => load();
  @override
  Future<ConnectedHealthSnapshot> revokePermissions() => load();
  @override
  Future<void> openSystemSettings() async {}
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final size in [const Size(390, 844), const Size(1032, 1376)]) {
    testWidgets(
      'actual approved Home ${size.width} keeps its layout under anchored First Use and after Skip',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final router = journeyRouter(actualHome: true);
        addTearDown(router.dispose);
        final scope =
            journeyApp(
                  db,
                  router,
                  'ar',
                  reduced: true,
                  referenceTheme: BilFlagshipTheme.light(isArabic: true),
                )
                as ProviderScope;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...scope.overrides,
              connectedHealthGatewayProvider.overrideWithValue(
                _UnavailableHealth(),
              ),
              dashboardClockProvider.overrideWithValue(
                () => DateTime(2026, 10, 11, 11, 30),
              ),
              liveHealthNowProvider.overrideWithValue(
                () => DateTime(2026, 10, 11, 11, 30),
              ),
              verifiedSubscriptionStateProvider.overrideWithValue(
                AsyncData(
                  SubscriptionState(
                    plan: CommercePlan.free,
                    entitlements: FreePlan.entitlements,
                    authority: EntitlementAuthority.verifiedServer,
                    lifecycle: SubscriptionLifecycle.inactive,
                    isPurchasable: true,
                    canRestorePurchases: true,
                  ),
                ),
              ),
            ],
            child: scope.child,
          ),
        );
        await tester.pumpAndSettle();
        await settleVisualAssetImages(tester);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('dashboard-food-guide-anchored')),
          findsOneWidget,
        );
        final bubble = tester.getRect(
          find.byKey(const Key('dashboard-food-guide-anchored')),
        );
        expect(bubble.left, greaterThanOrEqualTo(0));
        expect(bubble.right, lessThanOrEqualTo(size.width));
        final hero = find.byKey(const Key('premium-dashboard-benchmark'));
        expect(hero, findsOneWidget);
        final before = tester.getRect(hero);
        await capture(tester, '00-real-home-ar-${size.width.toInt()}-guide');
        WidgetController.hitTestWarningShouldBeFatal = true;
        await tester.tap(find.byKey(const Key('dashboard-guide-skip')));
        await tester.pumpAndSettle();
        WidgetController.hitTestWarningShouldBeFatal = false;
        expect(
          find.byKey(const Key('dashboard-food-guide-anchored')),
          findsNothing,
        );
        expect(tester.getRect(hero), before);
        await capture(tester, '00-real-home-ar-${size.width.toInt()}-skipped');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 20));
      },
    );
  }
}
