import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/environment/app_environment.dart';
import '../domain/ad_policy.dart';
import 'admob_configuration.dart';
import 'admob_ump_consent_gate.dart';
import 'contextual_ad_gateway.dart';

final class AdMobContextualAdGateway implements ContextualBannerGateway {
  AdMobContextualAdGateway({
    this.useTestUnits = !kReleaseMode,
    UmpConsentCoordinator? umpConsent,
    bool Function()? adultConfirmed,
    this.configuredOverride,
  }) : _umpConsent = umpConsent ?? AdMobUmpConsentGate.instance,
       _adultConfirmed = adultConfirmed ?? _denyUnknownAge;

  final bool useTestUnits;
  final UmpConsentCoordinator _umpConsent;
  final bool Function() _adultConfirmed;
  @visibleForTesting
  final bool? configuredOverride;
  Future<InitializationStatus>? _initialization;

  BilAdPlatform? get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.android => BilAdPlatform.android,
    TargetPlatform.iOS => BilAdPlatform.ios,
    _ => null,
  };

  @override
  bool get isConfigured {
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
    _initialization ??= MobileAds.instance.initialize();
    await _initialization;
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
    if (!isConfigured || platform == null) return null;
    if (platform == BilAdPlatform.android) {
      // The production UMP bridge sends TFUA=false because BIL serves ads only
      // to a registered Free account that passed the existing 18+ product
      // gate. Keep that complete audience assertion at the final provider
      // boundary as well as the presentation policy.
      if (!_adultConfirmed()) return null;
      final ump = await _umpConsent.verifyCanRequestAds();
      if (!ump.canRequestAds) return null;
    }
    await _initialize();
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
          if (!completer.isCompleted) {
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
    await ad.load();
    return completer.future.timeout(
      // The native Google Mobile Ads request timeout is 60 seconds. A shorter
      // wrapper timeout disposed valid cold-start/test-device requests before
      // the SDK could finish on slower Android devices and emulators.
      const Duration(seconds: 65),
      onTimeout: () {
        if (kDebugMode) {
          debugPrint('BIL test banner timed out for ${placement.name}.');
        }
        ad.dispose();
        return null;
      },
    );
  }
}

bool _denyUnknownAge() => false;

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
