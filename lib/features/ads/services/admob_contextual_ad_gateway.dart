import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/environment/app_environment.dart';
import '../domain/ad_policy.dart';
import 'admob_configuration.dart';
import 'contextual_ad_gateway.dart';

final class AdMobContextualAdGateway implements ContextualBannerGateway {
  AdMobContextualAdGateway({this.useTestUnits = !kReleaseMode});

  final bool useTestUnits;
  Future<InitializationStatus>? _initialization;

  BilAdPlatform? get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.android => BilAdPlatform.android,
    TargetPlatform.iOS => BilAdPlatform.ios,
    _ => null,
  };

  @override
  bool get isConfigured {
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
          if (!completer.isCompleted) {
            completer.complete(_AdMobBannerHandle(ad));
          }
        },
        onAdFailedToLoad: (failed, _) {
          failed.dispose();
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
    await ad.load();
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        ad.dispose();
        return null;
      },
    );
  }
}

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
