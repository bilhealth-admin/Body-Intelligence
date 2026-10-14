import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 3D-A exposes explicit consent without activating transport', () {
    final settings = File(
      'lib/features/settings/sharing_privacy_settings_page.dart',
    ).readAsStringSync();
    final consentTile = File(
      'lib/features/settings/sharing_privacy_cloud_sync_tile.dart',
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
    final settingsAndTile = '$settings\n$consentTile';

    expect(settingsAndTile, contains('encrypted-cloud-sync-consent'));
    expect(settingsAndTile, contains('cloudSyncConsentStateProvider'));
    expect(settingsAndTile, contains('.setGranted(granted)'));
    expect(settingsAndTile, contains('cloudRuntimePreparationProvider'));
    expect(settingsAndTile, contains('CloudSyncConsentCopy.settingsTitle'));
    expect(settingsAndTile, contains('CloudSyncConsentCopy.settingsSubtitle'));
    expect(
      settingsAndTile,
      contains('CloudSyncConsentSummary(showDeletionControl: true)'),
    );
    expect(settingsAndTile, contains('CloudSyncConsentCopy.primaryAction'));
    expect(settingsAndTile, contains('CloudSyncConsentCopy.localAction'));
    expect(
      settingsAndTile,
      isNot(contains("_privacyText(context, 'Turn on')")),
    );
    expect(
      settingsAndTile,
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
