import '../../features/commerce/domain/store_catalog_configuration.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum EnvironmentProfile { development, testing, staging, production }

class AppEnvironment {
  const AppEnvironment._();

  static const bool useSupabase = bool.fromEnvironment(
    'BIL_USE_SUPABASE',
    defaultValue: true,
  );
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tgmanzhqulksykhslrzb.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_eMoUVfgwfU0RpQOwPJr-yw_ZgtStgld',
  );
  static const String serverUrl = String.fromEnvironment('BIL_SERVER_URL');

  /// Authenticated BIL Edge Function URL. Provider credentials must never be
  /// supplied to the mobile build; they belong in the server secret store.
  static const String mealVisionEndpoint = String.fromEnvironment(
    'BIL_MEAL_VISION_ENDPOINT',
  );
  static const bool paymentsEnabled = bool.fromEnvironment(
    'BIL_PAYMENTS_ENABLED',
    defaultValue: false,
  );
  static const bool emailOtpEnabled = bool.fromEnvironment(
    'BIL_EMAIL_OTP_ENABLED',
    defaultValue: false,
  );
  static const bool facebookLoginEnabled = bool.fromEnvironment(
    'BIL_FACEBOOK_LOGIN_ENABLED',
    defaultValue: false,
  );

  /// Keeps the Facebook entry point visible while Meta approval is pending,
  /// without allowing a public user to start an OAuth flow that cannot finish.
  ///
  /// Meta-review builds set this to true. Store builds leave it false until
  /// Business Verification and public access are approved.
  static const bool facebookLoginReady = bool.fromEnvironment(
    'BIL_FACEBOOK_LOGIN_READY',
    defaultValue: false,
  );
  static const bool pushEnabled = bool.fromEnvironment(
    'BIL_PUSH_ENABLED',
    defaultValue: false,
  );
  static const bool pushProviderReady = bool.fromEnvironment(
    'BIL_PUSH_PROVIDER_READY',
    defaultValue: false,
  );
  static const bool communityEnabled = bool.fromEnvironment(
    'BIL_COMMUNITY_ENABLED',
    defaultValue: true,
  );

  /// Advertising is opt-in at build configuration level and fails closed.
  ///
  /// BIL never ships fallback, demo, or test ad identifiers. Enabling this
  /// switch alone is insufficient: a reviewed provider adapter and both
  /// production placement identifiers must also be supplied.
  static const bool adsEnabled = bool.fromEnvironment(
    'BIL_ADS_ENABLED',
    defaultValue: false,
  );
  static const bool adProviderReady = bool.fromEnvironment(
    'BIL_AD_PROVIDER_READY',
    defaultValue: false,
  );
  static const String androidContextualAdUnitId = String.fromEnvironment(
    'BIL_ADMOB_ANDROID_BANNER_ID',
  );
  static const String iosContextualAdUnitId = String.fromEnvironment(
    'BIL_ADMOB_IOS_BANNER_ID',
  );
  static const String androidAdMobAppId = String.fromEnvironment(
    'BIL_ADMOB_ANDROID_APP_ID',
  );
  static const String iosAdMobAppId = String.fromEnvironment(
    'BIL_ADMOB_IOS_APP_ID',
  );
  static const String adMobPublisherId = String.fromEnvironment(
    'BIL_ADMOB_PUBLISHER_ID',
  );
  static const String _profileName = String.fromEnvironment(
    'BIL_ENVIRONMENT',
    defaultValue: 'production',
  );

  static EnvironmentProfile get profile => switch (_profileName) {
    'development' => EnvironmentProfile.development,
    'testing' => EnvironmentProfile.testing,
    'staging' => EnvironmentProfile.staging,
    _ => EnvironmentProfile.production,
  };

  static bool get isProduction => profile == EnvironmentProfile.production;

  static bool get cloudConfigured =>
      useSupabase && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get supabaseRuntimeReady {
    if (!cloudConfigured) return false;
    try {
      return Supabase.instance.isInitialized;
    } on AssertionError {
      return false;
    }
  }

  static bool get serverConfigured => serverUrl.startsWith('https://');
  static bool get mealVisionConfigured =>
      cloudConfigured && mealVisionEndpoint.startsWith('https://');
  // AI Coach is served by the authenticated Supabase Edge Function. A legacy
  // standalone BIL_SERVER_URL is optional and must not disable the coach.
  static bool get aiConfigured => cloudConfigured;
  static bool get commerceConfigured =>
      cloudConfigured &&
      paymentsEnabled &&
      StoreCatalogConfiguration.consumerProductsConfigured &&
      StoreCatalogConfiguration.legalLinksConfigured;
  static bool get communityConfigured => cloudConfigured && communityEnabled;
  static bool get pushConfigured =>
      communityConfigured && pushEnabled && pushProviderReady;

  static bool get adsConfigured =>
      adsEnabled &&
      adProviderReady &&
      androidAdMobAppId.startsWith('ca-app-pub-') &&
      iosAdMobAppId.startsWith('ca-app-pub-') &&
      adMobPublisherId.startsWith('pub-') &&
      androidContextualAdUnitId.isNotEmpty &&
      iosContextualAdUnitId.isNotEmpty;
}
