import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/environment/app_environment.dart';
import '../domain/ad_policy.dart';
import 'admob_configuration.dart';
import 'admob_ump_consent_gate.dart';
import 'contextual_ad_gateway.dart';

final class AdMobContextualAdGateway extends ChangeNotifier
    implements ContextualBannerGateway, ContextualAdPrivacyBoundary {
  AdMobContextualAdGateway({
    this.useTestUnits = !kReleaseMode,
    UmpConsentCoordinator? umpConsent,
    bool Function()? adultConfirmed,
    String? Function()? accountKey,
    this.configuredOverride,
    this.sdkOperationTimeout = const Duration(seconds: 45),
    this.bannerLoadTimeout = const Duration(seconds: 65),
  }) : _umpConsent = umpConsent ?? AdMobUmpConsentGate.instance,
       _adultConfirmed = adultConfirmed ?? _denyUnknownAge,
       _accountKey = accountKey ?? _unknownAccount {
    final consent = _umpConsent;
    if (consent case Listenable source) source.addListener(_consentChanged);
  }

  final bool useTestUnits;
  final UmpConsentCoordinator _umpConsent;
  final bool Function() _adultConfirmed;
  final String? Function() _accountKey;
  @visibleForTesting
  final bool? configuredOverride;
  @visibleForTesting
  final Duration sdkOperationTimeout;
  @visibleForTesting
  final Duration bannerLoadTimeout;
  Future<InitializationStatus>? _initialization;
  bool _disposed = false;

  @override
  bool get mayDisplayAd => !_disposed && _umpConsent.snapshot.canRequestAds;

  void _consentChanged() => notifyListeners();

  @override
  void dispose() {
    _disposed = true;
    final consent = _umpConsent;
    if (consent case Listenable source) source.removeListener(_consentChanged);
    super.dispose();
  }

  BilAdPlatform? get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.android => BilAdPlatform.android,
    TargetPlatform.iOS => BilAdPlatform.ios,
    _ => null,
  };

  @override
  bool get isConfigured {
    if (_disposed) return false;
    final override = configuredOverride;
    if (override != null) return override;
    final platform = _platform;
    if (platform == null ||
        !AppEnvironment.adsEnabled ||
        !AppEnvironment.adProviderReady) {
      return false;
    }
    return useTestUnits || BilAdMobConfiguration.productionConfigured(platform);
  }

  Future<void> _initialize() async {
    final operation = _initialization ??= _initializeWithoutPublisherId();
    try {
      await operation;
    } on Object {
      if (identical(_initialization, operation)) _initialization = null;
      rethrow;
    }
  }

  Future<InitializationStatus> _initializeWithoutPublisherId() async {
    // iOS enables publisher first-party ID by default. BIL's contextual-only
    // contract does not use it (this SDK call is a no-op on Android).
    await MobileAds.instance
        .setSameAppKeyEnabled(false)
        .timeout(sdkOperationTimeout);
    if (_disposed) throw StateError('The advertising gateway was disposed.');
    return MobileAds.instance.initialize().timeout(sdkOperationTimeout);
  }

  @override
  Future<ContextualAdResult> show(AdPlacement placement) async {
    // Banner ownership belongs to [SafeContextualBannerSlot]. Loading here
    // would drop the returned handle and leak the native ad.
    return ContextualAdResult.unavailable;
  }

  @override
  Future<ContextualBannerHandle?> loadBanner(AdPlacement placement) async {
    final platform = _platform;
    if (kIsWeb ||
        !isConfigured ||
        platform == null ||
        placement != AdPlacement.generalDiscovery) {
      return null;
    }
    final owner = _accountKey();
    bool stillEligible() =>
        !_disposed &&
        owner != null &&
        _accountKey() == owner &&
        _adultConfirmed();
    // Both platforms require the same live adult Free account and Google's
    // consent. Neither an iOS build nor a reviewer identity bypasses this gate.
    if (!stillEligible()) return null;
    final ump = await _umpConsent.verifyCanRequestAds();
    if (!ump.canRequestAds || !stillEligible()) return null;
    try {
      await _initialize();
    } on Object {
      return null;
    }
    if (!stillEligible() || !_umpConsent.snapshot.canRequestAds) return null;
    final completer = Completer<ContextualBannerHandle?>();
    late final BannerAd ad;
    ad = BannerAd(
      adUnitId: BilAdMobConfiguration.bannerId(
        platform: platform,
        useTestUnits: useTestUnits,
      ),
      size: AdSize.banner,
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (kDebugMode) {
            debugPrint('BIL test banner loaded for ${placement.name}.');
          }
          if (completer.isCompleted ||
              !stillEligible() ||
              !_umpConsent.snapshot.canRequestAds) {
            loaded.dispose();
            if (!completer.isCompleted) completer.complete(null);
          } else {
            completer.complete(_AdMobBannerHandle(ad));
          }
        },
        onAdFailedToLoad: (failed, error) {
          if (kDebugMode) {
            debugPrint(
              'BIL test banner failed for ${placement.name}: '
              '${error.code} ${error.domain} ${error.message}',
            );
          }
          failed.dispose();
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
    final operation = () async {
      try {
        await ad.load();
      } on Object {
        ad.dispose();
        if (!completer.isCompleted) completer.complete(null);
      }
      return completer.future;
    }();
    return operation.timeout(
      // The native Google Mobile Ads request timeout is 60 seconds. A shorter
      // wrapper timeout disposed valid cold-start/test-device requests before
      // the SDK could finish on slower Android devices and emulators.
      // Bound the platform-channel acknowledgement as well as the callback.
      bannerLoadTimeout,
      onTimeout: () {
        if (kDebugMode) {
          debugPrint('BIL test banner timed out for ${placement.name}.');
        }
        ad.dispose();
        // Complete the original future too: a late SDK callback must dispose
        // its native ad instead of handing an abandoned handle to nobody.
        if (!completer.isCompleted) completer.complete(null);
        return null;
      },
    );
  }
}

bool _denyUnknownAge() => false;
String? _unknownAccount() => null;

final class _AdMobBannerHandle implements ContextualBannerHandle {
  const _AdMobBannerHandle(this._ad);
  final BannerAd _ad;

  @override
  double get height => _ad.size.height.toDouble();

  @override
  Widget get widget => SizedBox(
    width: _ad.size.width.toDouble(),
    height: height,
    child: AdWidget(ad: _ad),
  );

  @override
  void dispose() => _ad.dispose();
}
