enum BilAdPlatform { android, ios }

class BilAdMobConfiguration {
  const BilAdMobConfiguration._();

  static const androidTestBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const iosTestBanner = 'ca-app-pub-3940256099942544/2934735716';

  static const androidProductionBanner = String.fromEnvironment(
    'BIL_ADMOB_ANDROID_BANNER_ID',
  );
  static const iosProductionBanner = String.fromEnvironment(
    'BIL_ADMOB_IOS_BANNER_ID',
  );
  static const publisherId = String.fromEnvironment('BIL_ADMOB_PUBLISHER_ID');
  static const androidAppId = String.fromEnvironment(
    'BIL_ADMOB_ANDROID_APP_ID',
  );
  static const iosAppId = String.fromEnvironment('BIL_ADMOB_IOS_APP_ID');

  static String bannerId({
    required BilAdPlatform platform,
    required bool useTestUnits,
  }) {
    if (useTestUnits) {
      return platform == BilAdPlatform.android
          ? androidTestBanner
          : iosTestBanner;
    }
    return platform == BilAdPlatform.android
        ? androidProductionBanner
        : iosProductionBanner;
  }

  static bool productionConfigured(BilAdPlatform platform) {
    final unit = bannerId(platform: platform, useTestUnits: false).trim();
    final appId = platform == BilAdPlatform.android
        ? androidAppId.trim()
        : iosAppId.trim();
    return publisherId.trim().startsWith('pub-') &&
        appId.startsWith('ca-app-pub-') &&
        unit.startsWith('ca-app-pub-') &&
        !appId.contains('3940256099942544') &&
        !unit.contains('3940256099942544');
  }

  /// Exact record to publish only after the owner provides a verified ID.
  /// Returns null while incomplete so app-ads.txt cannot fabricate ownership.
  static String? appAdsRecord() {
    final publisher = publisherId.trim();
    if (!RegExp(r'^pub-\d+$').hasMatch(publisher)) return null;
    return 'google.com, $publisher, DIRECT, f08c47fec0942fa0';
  }
}
