import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/environment/feature_flags.dart';
import 'package:body_intelligence_log/app/services/app_observability.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ad-hoc builds default to the development environment profile', () {
    expect(AppEnvironment.profile, EnvironmentProfile.development);
  });

  test('default cloud and AI are ready without remote overrides', () {
    expect(FeatureFlags.remoteOverridesAvailable, isFalse);
    expect(FeatureFlags.enabled(AppFeature.cloud), isTrue);
    expect(FeatureFlags.enabled(AppFeature.artificialIntelligence), isTrue);
  });

  test('omitted payment opt-in fails closed with ready dependencies', () {
    expect(
      AppEnvironment.isCommerceConfigurationReady(
        cloudConfigured: true,
        consumerProductsConfigured: true,
        legalLinksConfigured: true,
      ),
      isFalse,
    );
  });

  test('payment opt-in requires every commerce dependency', () {
    for (var missing = 0; missing < 4; missing++) {
      expect(
        AppEnvironment.isCommerceConfigurationReady(
          cloudConfigured: missing != 0,
          paymentsEnabled: missing != 1,
          consumerProductsConfigured: missing != 2,
          legalLinksConfigured: missing != 3,
        ),
        isFalse,
        reason: 'Readiness gate $missing must independently fail closed',
      );
    }
    expect(
      AppEnvironment.isCommerceConfigurationReady(
        cloudConfigured: true,
        paymentsEnabled: true,
        consumerProductsConfigured: true,
        legalLinksConfigured: true,
      ),
      isTrue,
    );
  });

  test(
    'compiled commerce flag respects explicit payment and legal readiness',
    () {
      // The full run deliberately opts into commerce with isolated legal URLs.
      // The same test also runs with no defines to prove the ad-hoc default.
      if (!AppEnvironment.cloudConfigured ||
          !AppEnvironment.paymentsEnabled ||
          !StoreCatalogConfiguration.legalLinksConfigured ||
          !StoreCatalogConfiguration.consumerProductsConfigured) {
        expect(FeatureFlags.enabled(AppFeature.commerce), isFalse);
      } else {
        expect(FeatureFlags.enabled(AppFeature.commerce), isTrue);
      }
    },
  );

  test('structured logger redacts health and identity attributes', () {
    final lines = <String>[];
    final logger = PrivacySafeLogger(sink: lines.add);
    logger.record(
      AppLogLevel.warning,
      'save_failed',
      attributes: {
        'weightKg': 80,
        'email': 'private@example.test',
        'authorizationHeader': 'Bearer must-not-appear',
        'purchaseReceipt': 'receipt-must-not-appear',
        'healthSummary': 'health-must-not-appear',
        'metadata': {
          'sessionId': 'nested-must-not-appear',
          'route': '/dashboard',
        },
        'screen': 'diary',
      },
    );
    expect(lines.single, contains('"weightKg":"[redacted]"'));
    expect(lines.single, contains('"email":"[redacted]"'));
    expect(lines.single, contains('"authorizationHeader":"[redacted]"'));
    expect(lines.single, contains('"purchaseReceipt":"[redacted]"'));
    expect(lines.single, contains('"healthSummary":"[redacted]"'));
    expect(lines.single, contains('"sessionId":"[redacted]"'));
    expect(lines.single, contains('"route":"/dashboard"'));
    expect(lines.single, contains('"screen":"diary"'));
    expect(lines.single, isNot(contains('private@example.test')));
    expect(lines.single, isNot(contains('must-not-appear')));
    expect(lines.single, isNot(contains('nested-must-not-appear')));
  });

  test('analytics and crash boundaries make no upload claim', () {
    expect(const DisabledProductAnalytics().uploadsData, isFalse);
    expect(
      LocalOnlyCrashReporter(PrivacySafeLogger(sink: (_) {})).uploadsData,
      isFalse,
    );
  });
}
