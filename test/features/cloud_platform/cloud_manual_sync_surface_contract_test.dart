import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'manual live sync is explicit, gated, selective and not startup-driven',
    () {
      final settings = File(
        'lib/features/settings/sharing_privacy_settings_page.dart',
      ).readAsStringSync();
      final providers = File(
        'lib/features/cloud_platform/providers/cloud_sync_providers.dart',
      ).readAsStringSync();
      final startup = File(
        'lib/features/startup/startup_page.dart',
      ).readAsStringSync();
      final service = File(
        'lib/features/cloud_platform/services/cloud_manual_sync_service.dart',
      ).readAsStringSync();

      expect(settings, contains('encrypted-cloud-sync-now'));
      expect(settings, contains('cloudManualSyncServiceProvider'));
      expect(settings, contains('.runOnce()'));

      expect(providers, contains('cloudManualSyncServiceProvider'));
      expect(
        providers,
        contains('connectivity: const CloudTransportActivationLock()'),
      );
      expect(startup, isNot(contains('cloudManualSyncServiceProvider')));
      expect(startup, isNot(contains('runOnce()')));

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
    },
  );
}
