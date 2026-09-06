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
      PlatformCapability.fitnessBluetooth,
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

  test('frozen Android production configuration passes every release gate', () {
    final issues = ReleaseConfigurationValidator.validate(
      ReleaseConfiguration(
        production: true,
        applicationId: 'com.bilhealth.bodyintelligencelog',
        cloudEnabled: true,
        supabaseUrl: 'https://project.supabase.co',
        supabaseAnonKey: 'public-anonymous-key',
        serverUrl: 'https://project.supabase.co/functions/v1/verify',
        paymentsEnabled: true,
        storeConfigured: true,
        platform: 'android',
        facebookRequired: true,
        facebookLoginEnabled: true,
        facebookLoginReady: true,
        pushEnabled: false,
        pushProviderReady: false,
        mobileIntegrityRequired: true,
        mobileIntegrityBackendReleaseId: 'reviewed-backend-release',
        playIntegrityProjectNumber: '1041595138122',
        sourceCommit: List.filled(40, 'a').join(),
        auditedSourceCommit: List.filled(40, 'a').join(),
        freezeManifestSha256: List.filled(64, 'b').join(),
        auditedFreezeManifestSha256: List.filled(64, 'b').join(),
        stagingManifestComplete: true,
        candidateFrozenOrAccepted: true,
        unresolvedReviewCount: 0,
        manifestReleaseVersion: '1.0.0',
        manifestReleaseBuildNumber: 8,
      ),
    );

    expect(issues, isEmpty);
  });

  test('frozen iOS hotfix configuration requires build 9', () {
    final issues = ReleaseConfigurationValidator.validate(
      ReleaseConfiguration(
        production: true,
        applicationId: 'com.bilhealth.bodyintelligencelog',
        cloudEnabled: true,
        supabaseUrl: 'https://project.supabase.co',
        supabaseAnonKey: 'public-anonymous-key',
        serverUrl: 'https://project.supabase.co/functions/v1/verify',
        paymentsEnabled: true,
        storeConfigured: true,
        platform: 'ios',
        facebookRequired: true,
        facebookLoginEnabled: true,
        facebookLoginReady: true,
        pushEnabled: false,
        pushProviderReady: false,
        mobileIntegrityRequired: true,
        mobileIntegrityBackendReleaseId: 'reviewed-backend-release',
        sourceCommit: List.filled(40, 'a').join(),
        auditedSourceCommit: List.filled(40, 'a').join(),
        freezeManifestSha256: List.filled(64, 'b').join(),
        auditedFreezeManifestSha256: List.filled(64, 'b').join(),
        stagingManifestComplete: true,
        candidateFrozenOrAccepted: true,
        unresolvedReviewCount: 0,
        manifestReleaseVersion: '1.0.0',
        manifestReleaseBuildNumber: 9,
      ),
    );

    expect(issues, isEmpty);
  });

  test('iOS rejects the crashing build 8 frozen manifest', () {
    final issues = ReleaseConfigurationValidator.validate(
      ReleaseConfiguration(
        production: true,
        applicationId: 'com.bilhealth.bodyintelligencelog',
        cloudEnabled: true,
        supabaseUrl: 'https://project.supabase.co',
        supabaseAnonKey: 'public-anonymous-key',
        serverUrl: 'https://project.supabase.co/functions/v1/verify',
        paymentsEnabled: true,
        storeConfigured: true,
        platform: 'ios',
        facebookRequired: true,
        facebookLoginEnabled: true,
        facebookLoginReady: true,
        pushEnabled: false,
        pushProviderReady: false,
        mobileIntegrityRequired: true,
        mobileIntegrityBackendReleaseId: 'reviewed-backend-release',
        sourceCommit: List.filled(40, 'a').join(),
        auditedSourceCommit: List.filled(40, 'a').join(),
        freezeManifestSha256: List.filled(64, 'b').join(),
        auditedFreezeManifestSha256: List.filled(64, 'b').join(),
        stagingManifestComplete: true,
        candidateFrozenOrAccepted: true,
        unresolvedReviewCount: 0,
        manifestReleaseVersion: '1.0.0',
        manifestReleaseBuildNumber: 8,
      ),
    );

    final releaseIssue = issues.singleWhere(
      (issue) => issue.code == 'wrong_frozen_release_version',
    );
    expect(releaseIssue.message, contains('build 9 for ios'));
  });

  test('production rejects mismatched feature integrity and freeze gates', () {
    final codes = ReleaseConfigurationValidator.validate(
      ReleaseConfiguration(
        production: true,
        applicationId: 'com.bilhealth.bodyintelligencelog',
        cloudEnabled: true,
        supabaseUrl: 'https://project.supabase.co',
        supabaseAnonKey: 'public-anonymous-key',
        serverUrl: 'https://project.supabase.co/functions/v1/verify',
        paymentsEnabled: true,
        storeConfigured: true,
        platform: 'android',
        facebookRequired: true,
        facebookLoginEnabled: true,
        facebookLoginReady: false,
        pushEnabled: true,
        pushProviderReady: false,
        mobileIntegrityRequired: false,
        mobileIntegrityBackendReleaseId: '',
        playIntegrityProjectNumber: 'invalid',
        sourceCommit: List.filled(40, 'a').join(),
        auditedSourceCommit: List.filled(40, 'c').join(),
        freezeManifestSha256: List.filled(64, 'b').join(),
        auditedFreezeManifestSha256: List.filled(64, 'd').join(),
        stagingManifestComplete: false,
        candidateFrozenOrAccepted: false,
        unresolvedReviewCount: 172,
        manifestReleaseVersion: '1.0.0',
        manifestReleaseBuildNumber: 7,
      ),
    ).map((issue) => issue.code);

    expect(
      codes,
      containsAll(<String>[
        'required_facebook_not_ready',
        'push_gate_mismatch',
        'mobile_integrity_not_required',
        'missing_mobile_integrity_backend_release',
        'invalid_play_integrity_project',
        'unaudited_source_commit',
        'unapproved_freeze_manifest',
        'incomplete_release_manifest',
        'release_candidate_not_accepted',
        'unresolved_release_review_items',
        'wrong_frozen_release_version',
      ]),
    );
  });
}
