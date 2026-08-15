import '../../features/ads/services/admob_configuration.dart';
import '../../features/commerce/domain/store_catalog_configuration.dart';
import 'bil_verified_links_configuration.dart';

final class BilGlobalLaunchReadiness {
  const BilGlobalLaunchReadiness({
    required this.androidVerifiedLinks,
    required this.iosVerifiedLinks,
    required this.androidAds,
    required this.iosAds,
    required this.storeProducts,
    required this.analyticsProvider,
  });

  final bool androidVerifiedLinks;
  final bool iosVerifiedLinks;
  final bool androidAds;
  final bool iosAds;
  final bool storeProducts;
  final bool analyticsProvider;

  static const analyticsProviderName = String.fromEnvironment(
    'BIL_ANALYTICS_PROVIDER',
  );

  factory BilGlobalLaunchReadiness.current() => BilGlobalLaunchReadiness(
    androidVerifiedLinks:
        BilVerifiedLinksConfiguration.assetLinksJson() != null,
    iosVerifiedLinks:
        BilVerifiedLinksConfiguration.appleAppSiteAssociationJson() != null,
    androidAds: BilAdMobConfiguration.productionConfigured(
      BilAdPlatform.android,
    ),
    iosAds: BilAdMobConfiguration.productionConfigured(BilAdPlatform.ios),
    storeProducts: StoreCatalogConfiguration.consumerProductsConfigured,
    analyticsProvider: analyticsProviderName.trim().isNotEmpty,
  );

  bool get productionReady =>
      androidVerifiedLinks &&
      iosVerifiedLinks &&
      androidAds &&
      iosAds &&
      storeProducts &&
      analyticsProvider;

  List<String> get blockers => [
    if (!androidVerifiedLinks) 'android_verified_links',
    if (!iosVerifiedLinks) 'ios_verified_links',
    if (!androidAds) 'android_admob',
    if (!iosAds) 'ios_admob',
    if (!storeProducts) 'store_products',
    if (!analyticsProvider) 'analytics_provider',
  ];
}
