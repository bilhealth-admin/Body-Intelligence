import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 3D-A exposes explicit consent without activating transport', () {
    final settings = File(
      'lib/features/settings/sharing_privacy_settings_page.dart',
    ).readAsStringSync();
    final providers = File(
      'lib/features/cloud_platform/providers/cloud_sync_providers.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/cloud_platform/services/cloud_sync_consent_repository.dart',
    ).readAsStringSync();
    final connectivity = File(
      'lib/features/cloud_platform/services/system_cloud_connectivity.dart',
    ).readAsStringSync();

    expect(settings, contains('encrypted-cloud-sync-consent'));
    expect(settings, contains('cloudSyncConsentStateProvider'));
    expect(settings, contains('.setGranted(granted)'));
    expect(settings, contains('cloudRuntimePreparationProvider'));
    expect(settings, contains('CloudSyncConsentCopy.settingsTitle'));
    expect(settings, contains('CloudSyncConsentCopy.settingsSubtitle'));
    expect(
      settings,
      contains('CloudSyncConsentSummary(showDeletionControl: true)'),
    );
    expect(settings, contains('CloudSyncConsentCopy.primaryAction'));
    expect(settings, contains('CloudSyncConsentCopy.localAction'));
    expect(settings, isNot(contains("_privacyText(context, 'Turn on')")));
    expect(
      settings,
      isNot(contains('CloudSyncConsentAvailability.premiumRequired')),
    );

    expect(
      providers,
      contains('connectivity: const CloudTransportActivationLock()'),
    );
    expect(
      providers,
      isNot(contains('SystemCloudConnectivitySnapshot.current')),
    );
    expect(repository, contains("'bil_record_consent'"));
    expect(
      repository,
      isNot(contains('Premium entitlement is required for cloud sync')),
    );
    expect(repository, isNot(contains('.synchronize(')));
    expect(connectivity, contains('checkConnectivity()'));
  });
}
