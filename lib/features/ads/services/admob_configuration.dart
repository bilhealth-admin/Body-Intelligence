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
    return isProductionConfiguration(
      publisherId: publisherId,
      appId: appId,
      bannerId: unit,
    );
  }

  /// Accepts only one exact, non-placeholder AdMob publisher identity.
  ///
  /// Prefix-only checks can mistake a zero-filled placeholder, Google's sample
  /// account, or an ad unit belonging to another publisher for production
  /// configuration. Keep that state fail-closed before any SDK request.
  static bool isProductionConfiguration({
    required String publisherId,
    required String appId,
    required String bannerId,
  }) {
    final publisher = _productionPublisherNumber(publisherId);
    final appMatch = RegExp(
      r'^ca-app-pub-(\d{16})~\d{10}$',
    ).firstMatch(appId.trim());
    final bannerMatch = RegExp(
      r'^ca-app-pub-(\d{16})/\d{10}$',
    ).firstMatch(bannerId.trim());
    if (publisher == null || appMatch == null || bannerMatch == null) {
      return false;
    }

    return appMatch.group(1) == publisher && bannerMatch.group(1) == publisher;
  }

  static bool isProductionPublisherId(String value) =>
      _productionPublisherNumber(value) != null;

  static String? _productionPublisherNumber(String value) {
    final match = RegExp(r'^pub-(\d{16})$').firstMatch(value.trim());
    final publisher = match?.group(1);
    if (publisher == null ||
        publisher == '0000000000000000' ||
        publisher == '3940256099942544') {
      return null;
    }
    return publisher;
  }

  /// Exact record to publish only after the owner provides a verified ID.
  /// Returns null while incomplete so app-ads.txt cannot fabricate ownership.
  static String? appAdsRecord() {
    final publisher = publisherId.trim();
    if (!isProductionPublisherId(publisher)) return null;
    return 'google.com, $publisher, DIRECT, f08c47fec0942fa0';
  }
}
