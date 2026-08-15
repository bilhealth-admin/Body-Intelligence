import 'package:body_intelligence_log/app/environment/platform_readiness.dart';
import 'package:body_intelligence_log/app/environment/release_configuration_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local core is available while external services remain explicit', () {
    final local = PlatformReadinessMatrix.status(
      platform: BilRuntimePlatform.android,
      capability: PlatformCapability.localCore,
    );
    final cloud = PlatformReadinessMatrix.status(
      platform: BilRuntimePlatform.android,
      capability: PlatformCapability.cloudSync,
    );
    final commerce = PlatformReadinessMatrix.status(
      platform: BilRuntimePlatform.android,
      capability: PlatformCapability.commerce,
    );

    expect(local.readiness, CapabilityReadiness.available);
    expect(cloud.readiness, CapabilityReadiness.configurationRequired);
    expect(commerce.readiness, CapabilityReadiness.configurationRequired);
    expect(cloud.reason, isNotEmpty);
    expect(commerce.reason, isNotEmpty);
  });

  test('web does not claim native health or BLE', () {
    for (final capability in [
      PlatformCapability.nativeHealth,
      PlatformCapability.medicalBluetooth,
    ]) {
      final status = PlatformReadinessMatrix.status(
        platform: BilRuntimePlatform.web,
        capability: capability,
      );
      expect(status.readiness, CapabilityReadiness.unavailable);
      expect(status.isAvailable, isFalse);
    }
  });

  test('release validator rejects template identity and false activation', () {
    final issues = ReleaseConfigurationValidator.validate(
      const ReleaseConfiguration(
        production: true,
        applicationId: 'com.example.app',
        cloudEnabled: true,
        supabaseUrl: 'http://localhost',
        supabaseAnonKey: '',
        serverUrl: '',
        paymentsEnabled: true,
        storeConfigured: false,
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      containsAll(<String>[
        'invalid_application_id',
        'invalid_supabase_url',
        'missing_supabase_anon_key',
        'payments_without_server',
        'payments_without_store',
      ]),
    );
  });

  test('local-only development configuration is valid', () {
    final issues = ReleaseConfigurationValidator.validate(
      const ReleaseConfiguration(
        production: false,
        applicationId: 'com.bilhealth.bodyintelligencelog.dev',
        cloudEnabled: false,
        supabaseUrl: '',
        supabaseAnonKey: '',
        serverUrl: '',
        paymentsEnabled: false,
        storeConfigured: false,
      ),
    );

    expect(issues, isEmpty);
  });
}
