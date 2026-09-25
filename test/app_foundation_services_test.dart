import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/environment/feature_flags.dart';
import 'package:body_intelligence_log/app/services/app_observability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ad-hoc builds default to the development environment profile', () {
    expect(AppEnvironment.profile, EnvironmentProfile.development);
  });

  test('default cloud and AI are ready while paid commerce fails closed', () {
    expect(FeatureFlags.remoteOverridesAvailable, isFalse);
    expect(FeatureFlags.enabled(AppFeature.cloud), isTrue);
    expect(FeatureFlags.enabled(AppFeature.artificialIntelligence), isTrue);
    expect(FeatureFlags.enabled(AppFeature.commerce), isFalse);
  });

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
