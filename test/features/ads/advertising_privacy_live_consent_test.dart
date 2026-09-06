import 'dart:async';

import 'package:body_intelligence_log/features/ads/advertising_privacy_page.dart';
import 'package:body_intelligence_log/features/ads/services/admob_ump_consent_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'privacy options appear when an in-flight startup refresh becomes ready',
    (tester) async {
      final update = Completer<void>();
      final platform = _DeferredUmpPlatform(update.future);
      final coordinator = AdMobUmpConsentGate(
        platform: platform,
        isApplicable: true,
      );
      final refresh = coordinator.refresh(force: true);
      expect(coordinator.snapshot.phase, UmpConsentPhase.updating);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AdvertisingPrivacyPage(umpConsentCoordinator: coordinator),
          ),
        ),
      );
      expect(
        find.byKey(const Key('advertising-google-privacy-options')),
        findsNothing,
      );

      update.complete();
      await refresh;
      await tester.pump();

      expect(
        find.byKey(const Key('advertising-google-privacy-options')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      coordinator.dispose();
    },
  );

  testWidgets('disposing the page detaches an in-flight consent listener', (
    tester,
  ) async {
    final update = Completer<void>();
    final platform = _DeferredUmpPlatform(update.future);
    final coordinator = AdMobUmpConsentGate(
      platform: platform,
      isApplicable: true,
    );
    final refresh = coordinator.refresh(force: true);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AdvertisingPrivacyPage(umpConsentCoordinator: coordinator),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    update.complete();
    await refresh;
    await tester.pump();

    expect(tester.takeException(), isNull);
    coordinator.dispose();
  });

  testWidgets('rebind ignores completion from the previous coordinator', (
    tester,
  ) async {
    const required = UmpConsentSnapshot(
      phase: UmpConsentPhase.ready,
      canRequestAds: true,
      privacyOptionsRequirement: UmpPrivacyOptionsRequirement.required,
    );
    const notRequired = UmpConsentSnapshot(
      phase: UmpConsentPhase.ready,
      canRequestAds: true,
      privacyOptionsRequirement: UmpPrivacyOptionsRequirement.notRequired,
    );
    final oldPrivacyResult = Completer<UmpConsentSnapshot>();
    final oldCoordinator = _ControllableCoordinator(
      required,
      privacyResult: oldPrivacyResult.future,
    );
    final currentCoordinator = _ControllableCoordinator(notRequired);

    Widget app(UmpConsentCoordinator coordinator) => ProviderScope(
      child: MaterialApp(
        home: AdvertisingPrivacyPage(umpConsentCoordinator: coordinator),
      ),
    );

    await tester.pumpWidget(app(oldCoordinator));
    final options = find.byKey(const Key('advertising-google-privacy-options'));
    expect(options, findsOneWidget);
    await tester.tap(options);
    await tester.pump();

    await tester.pumpWidget(app(currentCoordinator));
    expect(options, findsNothing);

    oldPrivacyResult.complete(required);
    await tester.pump();
    expect(options, findsNothing);

    currentCoordinator.publish(required);
    await tester.pump();
    expect(options, findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    oldCoordinator.dispose();
    currentCoordinator.dispose();
  });
}

final class _ControllableCoordinator extends ChangeNotifier
    implements UmpConsentCoordinator {
  _ControllableCoordinator(this._snapshot, {this.privacyResult});

  UmpConsentSnapshot _snapshot;
  final Future<UmpConsentSnapshot>? privacyResult;

  void publish(UmpConsentSnapshot snapshot) {
    _snapshot = snapshot;
    notifyListeners();
  }

  @override
  bool get isApplicable => true;

  @override
  UmpConsentSnapshot get snapshot => _snapshot;

  @override
  Future<UmpConsentSnapshot> refresh({bool force = false}) async => _snapshot;

  @override
  Future<UmpConsentSnapshot> showPrivacyOptions() =>
      privacyResult ?? Future.value(_snapshot);

  @override
  Future<UmpConsentSnapshot> verifyCanRequestAds() async => _snapshot;
}

final class _DeferredUmpPlatform implements UmpPlatformBridge {
  const _DeferredUmpPlatform(this.update);

  final Future<void> update;

  @override
  Future<bool> canRequestAds() async => true;

  @override
  Future<UmpPrivacyOptionsRequirement> getPrivacyOptionsRequirement() async =>
      UmpPrivacyOptionsRequirement.required;

  @override
  Future<void> loadAndShowConsentFormIfRequired() async {}

  @override
  Future<void> requestConsentInfoUpdate() => update;

  @override
  Future<void> showPrivacyOptionsForm() async {}
}
