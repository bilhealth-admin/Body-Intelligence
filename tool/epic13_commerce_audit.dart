import 'dart:io';

Never _fail(String message) {
  stderr.writeln('EPIC13_COMMERCE_AUDIT=FAIL');
  stderr.writeln(message);
  exit(1);
}

String read(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing required file: $path');
  return file.readAsStringSync();
}

void requireText(String source, String value, String message) {
  if (!source.contains(value)) _fail(message);
}

void reject(RegExp pattern, String source, String message) {
  if (pattern.hasMatch(source)) _fail(message);
}

void main() {
  final configuration = read(
    'lib/features/commerce/domain/store_catalog_configuration.dart',
  );
  final client = read(
    'lib/features/commerce/services/verified_store_purchase_service.dart',
  );
  final environment = read('lib/app/environment/app_environment.dart');
  final backend = read(
    'supabase/functions/verify-store-purchase/store_backend.ts',
  );
  final migration = read(
    'supabase/migrations/202608040004_bil_store_entitlement_truth.sql',
  );
  final paywall = read(
    'lib/features/commerce/presentation/bil_store_plans_page.dart',
  );
  final pubspec = read('pubspec.yaml');

  reject(
    RegExp(r"defaultValue:\s*'bil_(plus|pro|coach)"),
    configuration +
        read('lib/features/commerce/services/app_store_purchase_service.dart'),
    'Invented fallback product ID found.',
  );
  reject(
    RegExp(r'\b14\s*%|\bVAT\s*14|\b0\.14\b', caseSensitive: false),
    client + paywall,
    'Hard-coded tax found in the consumer commerce path.',
  );
  reject(
    RegExp(
      r'SharedPreferences|BIL_ENABLE_.*ENTITLE|debug.*entitle',
      caseSensitive: false,
    ),
    client,
    'Local or debug entitlement authority found.',
  );

  requireText(
    environment,
    'StoreCatalogConfiguration.consumerProductsConfigured',
    'Commerce must remain hidden until real products are configured.',
  );
  requireText(
    client,
    'purchase.status',
    'Purchase lifecycle handling missing.',
  );
  requireText(
    client,
    'purchase.pendingCompletePurchase',
    'Server-before-acknowledgement boundary missing.',
  );
  requireText(client, "'purchase_pending'", 'Pending state missing.');
  requireText(client, 'queryPastPurchases', 'Android recovery query missing.');
  requireText(client, 'restorePurchases', 'Explicit restore missing.');
  requireText(
    client,
    'obfuscatedProfileId',
    'Google obfuscated profile missing.',
  );
  requireText(
    client,
    'ChangeSubscriptionParam',
    'Google upgrade and downgrade replacement handling missing.',
  );
  requireText(
    client,
    'ReplacementMode.deferred',
    'Google downgrade-at-renewal handling missing.',
  );
  requireText(
    client,
    'applicationUserName: accountHash',
    'Obfuscated store account identifier missing.',
  );

  requireText(
    backend,
    'purchases/subscriptionsv2/tokens',
    'Google Developer API verification missing.',
  );
  requireText(
    backend,
    'GOOGLE_PUBSUB_AUDIENCE',
    'RTDN identity check missing.',
  );
  requireText(backend, 'signedPayload', 'Apple Notifications V2 missing.');
  requireText(
    backend,
    "header.alg !== 'ES256'",
    'Apple JWS algorithm check missing.',
  );
  requireText(
    backend,
    'apple_chain_untrusted',
    'Apple certificate pin missing.',
  );
  requireText(
    backend,
    'digestBytes(decodeBase64Bytes',
    'Apple certificate pin must hash raw DER bytes.',
  );
  requireText(
    backend,
    'inApps/v1/subscriptions',
    'App Store Server API missing.',
  );
  requireText(
    backend,
    'appleServerStatusLifecycle',
    'App Store lifecycle reconciliation missing.',
  );
  requireText(
    backend,
    'purchases/voidedpurchases',
    'Google refund/revocation reconciliation missing.',
  );
  requireText(
    backend,
    "body.action === 'reconcile'",
    'Scheduled reconciliation action missing.',
  );
  requireText(
    backend,
    'bil_consume_rate_limit',
    'Verification rate limit missing.',
  );

  requireText(
    migration,
    'unique (provider, original_transaction_id)',
    'Cross-account transaction uniqueness missing.',
  );
  requireText(
    migration,
    'bil_claim_store_notification',
    'Notification replay protection missing.',
  );
  requireText(migration, 'enable row level security', 'Commerce RLS missing.');
  requireText(
    migration,
    'grant select on public.bil_subscriptions to authenticated',
    'Owner-readable entitlement projection missing.',
  );

  requireText(paywall, 'CommercePlan.plus', 'Plus consumer plan missing.');
  requireText(paywall, 'CommercePlan.pro', 'Pro consumer plan missing.');
  requireText(
    pubspec,
    'path: tool/vendor_app_links',
    'The audited current Supabase app_links source is not locally pinned.',
  );
  final vendoredAppLinks = read('tool/vendor_app_links/pubspec.yaml');
  requireText(
    vendoredAppLinks,
    'version: 7.2.1',
    'The vendored app_links release must remain 7.2.1.',
  );
  reject(
    RegExp(r'com\.android\.tools\.build:gradle'),
    read('tool/vendor_app_links/android/build.gradle.kts'),
    'Vendored app_links must use the app AGP instead of embedding another AGP.',
  );
  requireText(
    read('android/settings.gradle.kts'),
    'id("com.android.application") version "9.2.1"',
    'The app AGP must match the app_links Android toolchain.',
  );
  requireText(
    read('android/settings.gradle.kts'),
    'id("org.jetbrains.kotlin.android") version "2.2.20" apply false',
    'Flutter plugin compatibility on AGP 9 requires the audited KGP bridge.',
  );
  final gradleProperties = read('android/gradle.properties');
  requireText(
    gradleProperties,
    'android.builtInKotlin=false',
    'Built-in Kotlin must remain disabled until Flutter 3.47+ and all plugins migrate.',
  );
  requireText(
    gradleProperties,
    'android.newDsl=false',
    'The AGP 9 legacy plugin bridge requires the legacy DSL compatibility flag.',
  );
  requireText(
    read('android/gradle/wrapper/gradle-wrapper.properties'),
    'gradle-9.4.1-all.zip',
    'AGP 9.2 requires Gradle 9.4.1.',
  );
  reject(
    RegExp(r'purchasePlan\(CommercePlan\.(coach|clinic|enterprise|elite)'),
    paywall,
    'Contract-only or hidden plan exposed to the consumer store.',
  );

  stdout.writeln('EPIC13_COMMERCE_AUDIT=PASS');
}
