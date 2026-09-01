import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual live sync is explicit, gated, selective and not startup-driven', () {
    final settings = File(
      'lib/features/settings/sharing_privacy_settings_page.dart',
    ).readAsStringSync();
    final providers = File(
      'lib/features/cloud_platform/providers/cloud_sync_providers.dart',
    ).readAsStringSync();
    final statusProvider = File(
      'lib/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart',
    ).readAsStringSync();
    final startup = File(
      'lib/features/startup/startup_page.dart',
    ).readAsStringSync();
    final startupReader = File(
      'lib/features/cloud_platform/services/supabase_startup_cloud_profile_reader.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/cloud_platform/services/cloud_manual_sync_service.dart',
    ).readAsStringSync();

    expect(settings, contains('encrypted-cloud-sync-now'));
    expect(settings, contains('cloudManualSyncStatusProvider'));
    expect(settings, contains('.runOnce()'));

    expect(providers, contains('cloudManualSyncServiceProvider'));
    expect(
      providers,
      contains('connectivity: const CloudTransportActivationLock()'),
    );
    expect(startup, isNot(contains('cloudManualSyncServiceProvider')));
    expect(startup, isNot(contains('runOnce()')));
    expect(startup, contains('startupCloudProfileRestoreServiceProvider'));
    expect(startupReader, contains(".from('bil_cloud_records')"));
    expect(startupReader, contains(".eq('owner_id', owner)"));
    expect(
      startupReader,
      contains(".eq('entity_kind', CloudEntityKind.profile.name)"),
    );
    expect(startupReader, contains('resolveExisting(owner)'));
    expect(startupReader, contains('bil_get_existing_cloud_key'));
    for (final remoteMutation in const <String>[
      '.insert(',
      '.upsert(',
      '.update(',
      '.delete(',
      'bil_sync_records',
      'readCached(owner)',
      'bil_get_or_create_cloud_key',
    ]) {
      expect(startupReader, isNot(contains(remoteMutation)));
    }
    expect(statusProvider, contains('result.completedAt?.toUtc()'));
    expect(statusProvider, contains('cloudLastSuccessfulSyncPreferenceKey'));
    expect(statusProvider, isNot(contains('DateTime.now()')));

    final gate = service.indexOf('CloudRuntimeAccessGate(');
    final connectivity = service.indexOf(
      'SystemCloudConnectivitySnapshot.current()',
    );
    final producer = service.indexOf('AppDatabaseCloudOutboxProducer(');
    final synchronize = service.indexOf('coordinator.synchronize()');
    final applier = service.indexOf('AppDatabaseCloudInboxApplier(');

    expect(gate, greaterThanOrEqualTo(0));
    expect(connectivity, greaterThan(gate));
    expect(producer, greaterThan(connectivity));
    expect(synchronize, greaterThan(producer));
    expect(applier, greaterThan(synchronize));

    expect(service, contains('CloudEntityKind.profile'));
    expect(service, contains('CloudEntityKind.weight'));
    expect(service, contains('CloudEntityKind.hydration'));
    expect(service, isNot(contains('CloudEntityKind.nutrition')));
    expect(service, contains('runtime?.store.close()'));
  });
}
