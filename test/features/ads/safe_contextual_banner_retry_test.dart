import 'dart:async';

import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
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

final _ownerStateProvider = StateProvider<String?>((_) => 'free-a');
final _planStateProvider = StateProvider<CommercePlan>(
  (_) => CommercePlan.free,
);
final _onlineStateProvider = StateProvider<bool>((_) => true);
final _gatewayStateProvider = StateProvider<ContextualAdGateway>(
  (_) => const DisabledContextualAdGateway(),
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('null loads retry after 30s and 60s, then stop', (tester) async {
    final gateway = _FakeBannerGateway(
      loads: [_nullLoad, _nullLoad, _nullLoad, _unexpectedLoad],
    );
    await _mount(tester, gateway);

    expect(gateway.loadCalls, 1);
    await tester.pump(const Duration(seconds: 29));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 1);

    await tester.pump(const Duration(seconds: 1));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 2);

    await tester.pump(const Duration(seconds: 59));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 2);

    await tester.pump(const Duration(seconds: 1));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 3);

    await tester.pump(const Duration(minutes: 5));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 3);
    await _unmount(tester);
  });

  testWidgets('a successful retry remains visible without timer refresh', (
    tester,
  ) async {
    final handle = _FakeBannerHandle('retry-success');
    final gateway = _FakeBannerGateway(
      loads: [_nullLoad, () async => handle, _unexpectedLoad],
    );
    await _mount(tester, gateway);

    await tester.pump(const Duration(seconds: 30));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 2);
    expect(find.byKey(handle.key), findsOneWidget);

    await tester.pump(const Duration(minutes: 5));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 2);
    expect(find.byKey(handle.key), findsOneWidget);
    expect(handle.disposed, isFalse);
    await _unmount(tester);
  });

  testWidgets('a thrown load follows the same bounded retry path', (
    tester,
  ) async {
    final handle = _FakeBannerHandle('exception-retry-success');
    final gateway = _FakeBannerGateway(
      loads: [_throwingLoad, () async => handle],
    );
    await _mount(tester, gateway);

    expect(gateway.loadCalls, 1);
    expect(find.byKey(handle.key), findsNothing);
    await tester.pump(const Duration(seconds: 29));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 1);

    await tester.pump(const Duration(seconds: 1));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 2);
    expect(find.byKey(handle.key), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('offline cancels retry but reconnect cannot bypass cooldown', (
    tester,
  ) async {
    final handle = _FakeBannerHandle('online-again');
    final gateway = _FakeBannerGateway(loads: [_nullLoad, () async => handle]);
    final container = await _mount(tester, gateway);

    await tester.pump(const Duration(seconds: 5));
    container.read(_onlineStateProvider.notifier).state = false;
    await _pumpFrames(tester);
    await tester.pump(const Duration(seconds: 5));
    container.read(_onlineStateProvider.notifier).state = true;
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 1);

    await tester.pump(const Duration(seconds: 19));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 1);
    await tester.pump(const Duration(seconds: 1));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 2);
    expect(find.byKey(handle.key), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('paid cancels retry but same-owner Free waits for cooldown', (
    tester,
  ) async {
    final handle = _FakeBannerHandle('free-again');
    final gateway = _FakeBannerGateway(loads: [_nullLoad, () async => handle]);
    final container = await _mount(tester, gateway);

    await tester.pump(const Duration(seconds: 5));
    container.read(_planStateProvider.notifier).state = CommercePlan.premium;
    await _pumpFrames(tester);
    await tester.pump(const Duration(seconds: 5));
    container.read(_planStateProvider.notifier).state = CommercePlan.free;
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 1);

    await tester.pump(const Duration(seconds: 19));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 1);
    await tester.pump(const Duration(seconds: 1));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 2);
    expect(find.byKey(handle.key), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('privacy withdrawal cancels stale load; a later grant restarts', (
    tester,
  ) async {
    final pending = Completer<ContextualBannerHandle?>();
    final stale = _FakeBannerHandle('withdrawn-stale');
    final recovered = _FakeBannerHandle('privacy-regranted');
    final gateway = _FakeBannerGateway(
      loads: [() => pending.future, () async => recovered],
    );
    await _mount(tester, gateway);

    expect(gateway.loadCalls, 1);
    await tester.pump(const Duration(seconds: 5));
    gateway.setPrivacy(false);
    await _pumpFrames(tester);
    pending.complete(stale);
    await _pumpFrames(tester);
    expect(stale.disposed, isTrue);
    expect(gateway.loadCalls, 1);

    await tester.pump(const Duration(seconds: 25));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 1);
    gateway.setPrivacy(true);
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 2);
    expect(find.byKey(recovered.key), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('pause cancels retry; resume after cooldown permits one load', (
    tester,
  ) async {
    final handle = _FakeBannerHandle('resumed');
    final gateway = _FakeBannerGateway(loads: [_nullLoad, () async => handle]);
    await _mount(tester, gateway);

    await tester.pump(const Duration(seconds: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _pumpFrames(tester);
    await tester.pump(const Duration(seconds: 25));
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 2);
    expect(find.byKey(handle.key), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('new owners reset cooldown and reject a prior late handle', (
    tester,
  ) async {
    final pending = Completer<ContextualBannerHandle?>();
    final stale = _FakeBannerHandle('owner-b-stale');
    final current = _FakeBannerHandle('owner-c-current');
    final gateway = _FakeBannerGateway(
      loads: [_nullLoad, () => pending.future, () async => current],
    );
    final container = await _mount(tester, gateway);

    expect(gateway.loadCalls, 1);
    await tester.pump(const Duration(seconds: 5));
    container.read(_ownerStateProvider.notifier).state = 'free-b';
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 2);
    expect(find.byKey(current.key), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    container.read(_ownerStateProvider.notifier).state = 'free-c';
    await _pumpFrames(tester);
    expect(gateway.loadCalls, 3);
    expect(find.byKey(current.key), findsOneWidget);

    pending.complete(stale);
    await _pumpFrames(tester);
    expect(stale.disposed, isTrue);
    expect(current.disposed, isFalse);
    expect(find.byKey(current.key), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('gateway replacement and disposal cancel every pending retry', (
    tester,
  ) async {
    final first = _FakeBannerGateway(loads: [_nullLoad, _unexpectedLoad]);
    final replacement = _FakeBannerGateway(loads: [_unexpectedLoad]);
    final container = await _mount(tester, first);

    await tester.pump(const Duration(seconds: 5));
    container.read(_gatewayStateProvider.notifier).state = replacement;
    await _pumpFrames(tester);
    expect(first.loadCalls, 1);
    expect(replacement.loadCalls, 0);

    await tester.pump(const Duration(seconds: 5));
    await _unmount(tester);
    await tester.pump(const Duration(minutes: 2));
    expect(first.loadCalls, 1);
    expect(replacement.loadCalls, 0);
  });

  testWidgets('initial closed UMP refresh does not cancel the first load', (
    tester,
  ) async {
    final pending = Completer<ContextualBannerHandle?>();
    final handle = _FakeBannerHandle('initial-ump-complete');
    final gateway = _FakeBannerGateway(
      mayDisplayAd: false,
      loads: [() => pending.future],
    );
    await _mount(tester, gateway);

    expect(gateway.loadCalls, 1);
    gateway.setPrivacy(false);
    await _pumpFrames(tester);
    gateway.setPrivacy(true);
    await _pumpFrames(tester);
    pending.complete(handle);
    await _pumpFrames(tester);

    expect(gateway.loadCalls, 1);
    expect(handle.disposed, isFalse);
    expect(find.byKey(handle.key), findsOneWidget);
    await _unmount(tester);
  });
}

Future<ContextualBannerHandle?> _nullLoad() async => null;

Future<ContextualBannerHandle?> _throwingLoad() =>
    Future<ContextualBannerHandle?>.error(
      StateError('transient network error'),
    );

Future<ContextualBannerHandle?> _unexpectedLoad() =>
    Future<ContextualBannerHandle?>.error(
      StateError('retry budget or visible-handle guard was exceeded'),
    );

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _FakeBannerGateway gateway,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        _ownerStateProvider.overrideWith((_) => 'free-a'),
        _planStateProvider.overrideWith((_) => CommercePlan.free),
        _onlineStateProvider.overrideWith((_) => true),
        _gatewayStateProvider.overrideWith((_) => gateway),
        verifiedEntitlementOwnerProvider.overrideWith(
          (ref) => Stream.value(ref.watch(_ownerStateProvider)),
        ),
        verifiedSubscriptionStateProvider.overrideWith((ref) async {
          ref.watch(_ownerStateProvider);
          return _subscription(ref.watch(_planStateProvider));
        }),
        contextualAdGatewayProvider.overrideWith(
          (ref) => ref.watch(_gatewayStateProvider),
        ),
        adOnlineProvider.overrideWith(
          (ref) => Stream.value(ref.watch(_onlineStateProvider)),
        ),
        adAgeEligibilityProvider.overrideWith((_) => AdAgeEligibility.adult),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SafeContextualBannerSlot(
            placement: AdPlacement.generalDiscovery,
            now: () => tester.binding.clock.now(),
          ),
        ),
      ),
    ),
  );
  await _pumpFrames(tester);
  return ProviderScope.containerOf(
    tester.element(find.byType(SafeContextualBannerSlot)),
  );
}

Future<void> _pumpFrames(WidgetTester tester, [int count = 5]) async {
  for (var index = 0; index < count; index++) {
    await tester.pump();
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

SubscriptionState _subscription(CommercePlan plan) => SubscriptionState(
  plan: plan,
  entitlements: const {},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: plan != CommercePlan.free,
);

typedef _LoadStep = Future<ContextualBannerHandle?> Function();

final class _FakeBannerGateway extends ChangeNotifier
    implements ContextualBannerGateway, ContextualAdPrivacyBoundary {
  _FakeBannerGateway({required List<_LoadStep> loads, this.mayDisplayAd = true})
    : _loads = List<_LoadStep>.of(loads);

  final List<_LoadStep> _loads;
  int loadCalls = 0;

  @override
  bool mayDisplayAd;

  void setPrivacy(bool value) {
    mayDisplayAd = value;
    notifyListeners();
  }

  @override
  bool get isConfigured => true;

  @override
  Future<ContextualBannerHandle?> loadBanner(AdPlacement placement) {
    loadCalls += 1;
    if (_loads.isEmpty) return _unexpectedLoad();
    return _loads.removeAt(0)();
  }

  @override
  Future<ContextualAdResult> show(AdPlacement placement) async =>
      ContextualAdResult.unavailable;
}

final class _FakeBannerHandle implements ContextualBannerHandle {
  _FakeBannerHandle(String id) : key = Key('fake-retry-banner-$id');

  final Key key;
  bool disposed = false;

  @override
  double get height => 50;

  @override
  Widget get widget => SizedBox(key: key, width: 320, height: 50);

  @override
  void dispose() => disposed = true;
}
