import 'dart:convert';
import 'dart:io';

Never _fail(String message) {
  stderr.writeln('EPIC16_RELEASE_AUDIT_FAIL=$message');
  exit(1);
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing required file: $path');
  return file.readAsStringSync();
}

Map<String, Object?> _json(String path) =>
    jsonDecode(_read(path)) as Map<String, Object?>;

void _require(bool condition, String message) {
  if (!condition) _fail(message);
}

void main() {
  final external = _json(
    'docs/release/BIL_EPIC16_EXTERNAL_ACCOUNT_STATUS.json',
  );
  final rc = _json('docs/release/BIL_EPIC16_IDENTIFIER_AND_RC_STATUS.json');
  final platform = _json('docs/release/BIL_EPIC15_PLATFORM_METADATA.json');
  final store = _json('docs/release/BIL_EPIC15_STORE_METADATA.json');
  final pubspec = _read('pubspec.yaml');
  final android = _read('android/app/build.gradle.kts');
  final ios = _read('ios/Runner.xcodeproj/project.pbxproj');
  final environment = _read('lib/app/environment/app_environment.dart');
  final adPolicy = _read('lib/features/ads/domain/ad_policy.dart');
  final adGateway = _read(
    'lib/features/ads/services/contextual_ad_gateway.dart',
  );
  final adMobGateway = _read(
    'lib/features/ads/services/admob_contextual_ad_gateway.dart',
  );
  final adProviders = _read('lib/features/ads/providers/ad_providers.dart');
  final adConsent = _read(
    'lib/features/ads/repositories/ad_consent_repository.dart',
  );
  final adPrivacyPage = _read('lib/features/ads/advertising_privacy_page.dart');
  final router = _read('lib/app/router/app_router.dart');
  final settings = [
    'lib/features/settings/settings_page.dart',
    'lib/features/settings/settings_page_actions.dart',
  ].map(_read).join('\n');
  final publicPages = _read('docs/release/BIL_EPIC15_PUBLIC_PAGES.md');

  _require(
    external['application'] == 'Body Intelligence Log (BIL)',
    'Application identity differs from owner-confirmed value',
  );
  _require(
    external['public_developer_name'] == 'BIL Health',
    'Public developer name differs from owner-confirmed value',
  );
  _require(
    external['administrative_email'] == 'bilhealth.app@gmail.com',
    'Administrative email is not pinned',
  );
  final domain = external['domain']! as Map<String, Object?>;
  _require(domain['value'] == 'bilhealth.com', 'Owned domain is not pinned');
  _require(
    '${domain['public_pages']}'.startsWith('OWNER_CONFIRMED_PUBLISHED_'),
    'Owner-confirmed public-page publication status is missing',
  );

  const identifier = 'com.bilhealth.bodyintelligencelog';
  _require(
    rc['android_application_id'] == identifier &&
        rc['ios_bundle_identifier'] == identifier,
    'RC identifier register is inconsistent',
  );
  _require(
    android.contains('applicationId = "$identifier"') &&
        android.contains('namespace = "$identifier"'),
    'Android identifier differs from the register',
  );
  _require(
    ios.contains('PRODUCT_BUNDLE_IDENTIFIER = $identifier;'),
    'iOS identifier differs from the register',
  );
  final identity = store['app_identity']! as Map<String, Object?>;
  _require(
    identity['android_package'] == identifier &&
        identity['apple_bundle_id'] == identifier,
    'Store metadata identifiers are inconsistent',
  );
  _require(
    '${rc['identity_rebranding_decision']}'.startsWith(
      'OWNER_APPROVED_COM_BILHEALTH_BODYINTELLIGENCELOG_',
    ),
    'Owner-approved production identifier decision is missing',
  );

  _require(
    pubspec.contains('version: 1.0.0+1'),
    'Unexpected release version/build number',
  );
  _require(
    pubspec.contains('google_mobile_ads:') &&
        adMobGateway.contains('AdRequest(nonPersonalizedAds: true)') &&
        adMobGateway.contains('productionConfigured(platform)'),
    'Reviewed fail-closed AdMob integration is incomplete',
  );
  for (final token in const [
    "defaultValue: false",
    "BIL_ADS_ENABLED",
    "BIL_AD_PROVIDER_READY",
    "BIL_ADMOB_ANDROID_BANNER_ID",
    "BIL_ADMOB_IOS_BANNER_ID",
  ]) {
    _require(
      environment.contains(token),
      'Missing fail-closed ad token: $token',
    );
  }
  for (final token in const [
    'paidSubscription',
    'consentMissing',
    'sensitiveContext',
    'providerUnavailable',
    'offline',
    'contextualOnly',
  ]) {
    _require(adPolicy.contains(token), 'Ad policy is missing $token');
  }
  _require(
    adGateway.contains('DisabledContextualAdGateway') &&
        adGateway.contains('ContextualAdResult.unavailable'),
    'Default advertising gateway does not fail closed',
  );
  _require(
    adProviders.contains('adOnlineProvider') &&
        adProviders.contains('value ?? false'),
    'Advertising connectivity must fail closed until asserted',
  );
  _require(
    adConsent.contains('contextual_consent.v1') &&
        adConsent.contains('declined') &&
        adConsent.contains('clear()'),
    'Advertising consent persistence or revocation is incomplete',
  );
  for (final locale in const ["'ar'", "'en'", "'fr'", "'es'", "'tr'"]) {
    _require(
      adPrivacyPage.contains(locale),
      'Advertising privacy copy is missing production locale $locale',
    );
  }
  _require(
    adPrivacyPage.contains('advertising-provider-unavailable') &&
        adPrivacyPage.contains('LocalAdConsentRepository'),
    'Advertising consent is not a truthful user-facing persisted flow',
  );
  _require(
    router.contains("path: '/advertising-privacy'") &&
        settings.contains("'/advertising-privacy'") &&
        settings.contains(
          "key: const Key('settings-advertising-privacy-entry')",
        ),
    'Advertising privacy is not reachable from Settings when enabled',
  );
  _require(
    settings.contains('Choose where to save your private export.') &&
        !settings.contains('Copy JSON export to clipboard'),
    'Local export copy does not match the private OS save/share flow',
  );
  final forbiddenAdMarkers = RegExp(
    r'ca-app-pub-3940256099942544|testAdUnit|sampleAdUnit|demoAdUnit',
    caseSensitive: false,
  );
  _require(
    !forbiddenAdMarkers.hasMatch(
      '$pubspec\n$environment\n$adPolicy\n$adGateway',
    ),
    'Fake, sample, or test ad identifier found',
  );

  final google = platform['google_play']! as Map<String, Object?>;
  final apple = platform['apple_app_store']! as Map<String, Object?>;
  _require(
    '${google['ads_declaration']}'.contains(
      'CONTEXTUAL_NON_PERSONALIZED_FREE_TIER_ONLY',
    ),
    'Google advertising declaration is stale',
  );
  final appPrivacy = apple['app_privacy']! as Map<String, Object?>;
  _require(
    appPrivacy['tracking'] == false && appPrivacy['data_sale'] == false,
    'Apple privacy declaration must remain non-tracking and no-sale',
  );
  _require(
    publicPages.contains('bilhealth.app@gmail.com') &&
        publicPages.contains('support@bilhealth.com') &&
        publicPages.contains('privacy@bilhealth.com') &&
        publicPages.contains('inbound forwarding') &&
        publicPages.contains('outbound sending'),
    'Public-page source does not distinguish inbound forwarding from outbound sending',
  );
  _require(
    publicPages.contains('BIL does not apply a fixed global VAT rate'),
    'Subscription tax language is not honest',
  );

  stdout.writeln('EPIC16_RELEASE_AUDIT=PASS');
  stdout.writeln('ANDROID_IDENTIFIER=$identifier');
  stdout.writeln('IOS_IDENTIFIER=$identifier');
  stdout.writeln(
    'IDENTIFIER_CHANGE=OWNER_APPROVED_COM_BILHEALTH_BODYINTELLIGENCELOG',
  );
  stdout.writeln('ADS_DEFAULT=FAIL_CLOSED');
  stdout.writeln('PUBLICATION=OWNER_CONFIRMED_PUBLISHED');
}
