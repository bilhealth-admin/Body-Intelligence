import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/presentation/safe_free_ad_anchor.dart';
import 'package:body_intelligence_log/features/ads/presentation/safe_contextual_banner_slot.dart';
import 'package:body_intelligence_log/features/ads/providers/ad_providers.dart';
import 'package:body_intelligence_log/features/ads/services/contextual_ad_gateway.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

final _testSubscriptionProvider = StateProvider<SubscriptionState>(
  (_) => _subscription(CommercePlan.free),
);
final _testOwnerProvider = StateProvider<String?>((_) => 'free-a');

SubscriptionState _subscription(CommercePlan plan) => SubscriptionState(
  plan: plan,
  entitlements: const {},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: plan != CommercePlan.free,
);

void main() {
  testWidgets('banner collapses immediately for Premium and Premium AI Coach', (
    tester,
  ) async {
    final gateway = _RecordingBannerGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verifiedEntitlementOwnerProvider.overrideWith(
            (_) => Stream.value('test-owner'),
          ),
          verifiedSubscriptionStateProvider.overrideWith(
            (ref) async => ref.watch(_testSubscriptionProvider),
          ),
          contextualAdGatewayProvider.overrideWithValue(gateway),
          adOnlineProvider.overrideWith((_) => Stream.value(true)),
          adAgeEligibilityProvider.overrideWith((_) => AdAgeEligibility.adult),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('before'),
                SafeFreeAdAnchor(surface: SafeFreeAdSurface.progress),
                Text('after'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-contextual-banner')), findsOneWidget);
    expect(gateway.loadCalls, 1);
    expect(
      tester.getSize(find.byType(SafeFreeAdAnchor)).height,
      78,
      reason: '50dp banner plus 14dp safe separation on each side',
    );

    final scopeContext = tester.element(find.byType(SafeContextualBannerSlot));
    final container = ProviderScope.containerOf(scopeContext);
    container.read(_testSubscriptionProvider.notifier).state = _subscription(
      CommercePlan.premium,
    );
    await tester.pump();

    expect(find.byKey(const Key('fake-contextual-banner')), findsNothing);
    _expectCollapsedSlot(tester);
    expect(tester.getSize(find.byType(SafeFreeAdAnchor)).height, 0);
    expect(gateway.handles.single.disposed, isTrue);

    container.read(_testSubscriptionProvider.notifier).state = _subscription(
      CommercePlan.free,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake-contextual-banner')), findsOneWidget);
    expect(gateway.loadCalls, 2);
    expect(tester.getSize(find.byType(SafeFreeAdAnchor)).height, 78);

    container.read(_testSubscriptionProvider.notifier).state = _subscription(
      CommercePlan.premiumAiCoach,
    );
    await tester.pump();

    expect(find.byKey(const Key('fake-contextual-banner')), findsNothing);
    _expectCollapsedSlot(tester);
    expect(tester.getSize(find.byType(SafeFreeAdAnchor)).height, 0);
    expect(gateway.handles.last.disposed, isTrue);
    expect(gateway.loadCalls, 2);
    expect(gateway.placements, everyElement(AdPlacement.generalDiscovery));
  });

  testWidgets(
    'Guest and account switching never inherit a previous Free ad grant',
    (tester) async {
      final freeB = Completer<SubscriptionState>();
      final gateway = _RecordingBannerGateway();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            verifiedEntitlementOwnerProvider.overrideWith(
              (ref) => Stream.value(ref.watch(_testOwnerProvider)),
            ),
            verifiedSubscriptionStateProvider.overrideWith((ref) async {
              final owner = ref.watch(_testOwnerProvider);
              if (owner == 'free-a') return _subscription(CommercePlan.free);
              if (owner == 'free-b') return freeB.future;
              return SubscriptionState(
                plan: CommercePlan.free,
                entitlements: const {},
                authority: EntitlementAuthority.localDefault,
                isPurchasable: false,
                canRestorePurchases: false,
              );
            }),
            contextualAdGatewayProvider.overrideWithValue(gateway),
            adOnlineProvider.overrideWith((_) => Stream.value(true)),
            adAgeEligibilityProvider.overrideWith(
              (_) => AdAgeEligibility.adult,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SafeFreeAdAnchor(surface: SafeFreeAdSurface.dashboard),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-contextual-banner')), findsOneWidget);
      expect(gateway.loadCalls, 1);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SafeContextualBannerSlot)),
      );
      container.read(_testOwnerProvider.notifier).state = null;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-contextual-banner')), findsNothing);
      expect(gateway.handles.single.disposed, isTrue);
      expect(gateway.loadCalls, 1);

      container.read(_testOwnerProvider.notifier).state = 'free-b';
      await tester.pump();
      expect(find.byKey(const Key('fake-contextual-banner')), findsNothing);
      expect(gateway.loadCalls, 1);

      freeB.complete(_subscription(CommercePlan.free));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-contextual-banner')), findsOneWidget);
      expect(gateway.loadCalls, 2);
    },
  );

  test('native ad widgets exist only behind the safe ads boundary', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final directNativeAdFiles = dartFiles
        .where((file) {
          final source = file.readAsStringSync();
          return source.contains('AdWidget(') || source.contains('BannerAd(');
        })
        .map((file) => file.path.replaceAll('\\', '/'))
        .toSet();

    expect(directNativeAdFiles, {
      'lib/features/ads/services/admob_contextual_ad_gateway.dart',
    });
  });
}

void _expectCollapsedSlot(WidgetTester tester) {
  final shrink = tester.widget<SizedBox>(
    find
        .descendant(
          of: find.byType(SafeContextualBannerSlot),
          matching: find.byType(SizedBox),
        )
        .first,
  );
  expect(shrink.width, 0);
  expect(shrink.height, 0);
}

final class _RecordingBannerGateway implements ContextualBannerGateway {
  int loadCalls = 0;
  final List<_RecordingBannerHandle> handles = [];
  final List<AdPlacement> placements = [];

  @override
  bool get isConfigured => true;

  @override
  Future<ContextualBannerHandle?> loadBanner(AdPlacement placement) async {
    loadCalls++;
    placements.add(placement);
    final handle = _RecordingBannerHandle();
    handles.add(handle);
    return handle;
  }

  @override
  Future<ContextualAdResult> show(AdPlacement placement) async =>
      ContextualAdResult.unavailable;
}

final class _RecordingBannerHandle implements ContextualBannerHandle {
  bool disposed = false;

  @override
  double get height => 50;

  @override
  Widget get widget => const SizedBox(
    key: Key('fake-contextual-banner'),
    width: 320,
    height: 50,
  );

  @override
  void dispose() => disposed = true;
}
