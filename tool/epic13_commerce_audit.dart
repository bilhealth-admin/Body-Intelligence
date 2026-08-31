import 'dart:io';

Never _fail(String message) {
  stderr.writeln('EPIC13_COMMERCE_AUDIT=FAIL');
  stderr.writeln(message);
  exit(1);
}

String read(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing required file: $path');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

void requireText(String source, String value, String message) {
  if (!source.contains(value)) _fail(message);
}

void requirePattern(RegExp pattern, String source, String message) {
  if (!pattern.hasMatch(source)) _fail(message);
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
  final storeEnvironment = read(
    'supabase/functions/verify-store-purchase/store_environment.ts',
  );
  final migration = read(
    'supabase/migrations/202608040004_bil_store_entitlement_truth.sql',
  );
  final atomicPersistenceMigration = read(
    'supabase/migrations/202608090001_bil_store_atomic_entitlement_persistence.sql',
  );
  final canonicalTiersMigration = read(
    'supabase/migrations/20260815225624_bil_canonical_consumer_tiers.sql',
  );
  final paywall = [
    'lib/features/commerce/presentation/bil_store_plans_page.dart',
    'lib/features/commerce/presentation/bil_dynamic_store_offers.dart',
  ].map(read).join('\n');
  final pubspec = read('pubspec.yaml');

  reject(
    RegExp(r"defaultValue:\s*'bil_(plus|pro|premium|coach)"),
    configuration,
    'Invented fallback product ID found.',
  );
  reject(
    RegExp(r"String\.fromEnvironment\(\s*'BIL_STORE_"),
    configuration,
    'Release product IDs must not depend on optional build defines.',
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
    environment,
    'StoreCatalogConfiguration.legalLinksConfigured',
    'Commerce must remain hidden until HTTPS terms and privacy links are configured.',
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
  requirePattern(
    RegExp(r'''header\.alg\s*!==\s*["']ES256["']'''),
    backend,
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
  requirePattern(
    RegExp(r'''body\.action\s*===\s*["']reconcile["']'''),
    backend,
    'Scheduled reconciliation action missing.',
  );
  requireText(
    backend,
    'bil_consume_rate_limit',
    'Verification rate limit missing.',
  );
  requireText(
    storeEnvironment,
    "normalized === 'sandbox' || normalized === 'production'",
    'Sandbox and production store environments must be validated strictly.',
  );
  requireText(
    backend,
    'googleSubscriptionEnvironment(data.testPurchase)',
    'Google environment must come from the authenticated Publisher response.',
  );
  requireText(
    backend,
    'verifiedStoreEnvironment(payload.environment)',
    'Apple environment must come from the verified transaction JWS.',
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
  requireText(
    atomicPersistenceMigration,
    'primary key (provider, product_id)',
    'Store product identity must be scoped by provider.',
  );
  requireText(
    atomicPersistenceMigration,
    'bil_persist_verified_store_purchase',
    'Atomic subscription and entitlement persistence is missing.',
  );
  requirePattern(
    RegExp(r'''admin\.rpc\(\s*["']bil_persist_verified_store_purchase["']'''),
    backend,
    'The verification backend must use atomic entitlement persistence.',
  );

  requireText(
    configuration,
    'CommercePlan.premiumAiCoach',
    'Premium AI Coach must be a canonical store tier.',
  );
  for (final productId in const [
    'bil_premium',
    'bil_premium_annual',
    'bil_premium_ai_coach',
    'bil_premium_ai_coach_annual',
    'bil_ai_boost',
  ]) {
    requireText(
      configuration,
      "'$productId'",
      'Immutable store binding is missing: $productId.',
    );
  }
  reject(
    RegExp(r'BIL_STORE_(?:PLUS|PRO|PREMIUM_PLUS)'),
    configuration,
    'A legacy consumer product binding remains sellable.',
  );
  requireText(
    canonicalTiersMigration,
    "when 'plus' then 'legacy_plus'",
    'Legacy Plus must remain isolated from Premium AI Coach.',
  );
  requireText(
    canonicalTiersMigration,
    "new.plan_id = 'premium_ai_coach'",
    'Verified Premium AI Coach purchases must drive the AI quota authority.',
  );
  requireText(
    canonicalTiersMigration,
    'bil_sync_ai_coach_store_subscription_trigger',
    'The verified subscription to AI Coach mirror trigger is missing.',
  );

  requireText(paywall, "'premium'", 'Premium consumer offer is missing.');
  requireText(
    paywall,
    "'premium_ai_coach'",
    'Premium AI Coach consumer offer is missing.',
  );
  reject(
    RegExp(r'CommercePlan\.(plus|pro)'),
    paywall,
    'A legacy Plus/Pro tier remains reachable from the active paywall.',
  );
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
