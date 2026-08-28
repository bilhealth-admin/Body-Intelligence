import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/environment/feature_flags.dart';
import 'package:body_intelligence_log/app/services/app_observability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production is the safe default environment profile', () {
    expect(AppEnvironment.profile, EnvironmentProfile.production);
  });

  test(
    'production cloud and AI are ready while paid commerce fails closed',
    () {
      expect(FeatureFlags.remoteOverridesAvailable, isFalse);
      expect(FeatureFlags.enabled(AppFeature.cloud), isTrue);
      expect(FeatureFlags.enabled(AppFeature.artificialIntelligence), isTrue);
      expect(FeatureFlags.enabled(AppFeature.commerce), isFalse);
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
        'screen': 'diary',
      },
    );
    expect(lines.single, contains('"weightKg":"[redacted]"'));
    expect(lines.single, contains('"email":"[redacted]"'));
    expect(lines.single, contains('"screen":"diary"'));
    expect(lines.single, isNot(contains('private@example.test')));
  });

  test('analytics and crash boundaries make no upload claim', () {
    expect(const DisabledProductAnalytics().uploadsData, isFalse);
    expect(
      LocalOnlyCrashReporter(PrivacySafeLogger(sink: (_) {})).uploadsData,
      isFalse,
    );
  });
}
