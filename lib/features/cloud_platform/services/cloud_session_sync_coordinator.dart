import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/cloud_identity_models.dart';
import '../domain/cloud_platform_policy.dart';
import '../domain/cloud_sync_models.dart';
import 'cloud_platform_composition_root.dart';
import 'supabase_cloud_authentication_provider.dart';

/// Session-bound producer -> durable outbox -> transport coordinator.
///
/// A coordinator belongs to exactly one account and one device.  Callers must
/// discard it on auth-state changes; every operation revalidates the current
/// Supabase user so a stale provider cannot leak data after account switching.
final class CloudSessionSyncCoordinator {
  const CloudSessionSyncCoordinator({
    required this.runtime,
    required this.client,
    required this.device,
    required this.consent,
  });

  final CloudPlatformRuntime runtime;
  final SupabaseClient client;
  final CloudDeviceRegistration device;
  final CloudPrivacyConsent consent;

  String get ownerId => consent.ownerId;

  Future<void> enqueue(CloudRecordEnvelope record) async {
    _requireCurrentOwner();
    if (record.ownerId != ownerId ||
        record.revision.deviceId != device.deviceId) {
      throw StateError(
        'Cross-account or cross-device cloud mutation rejected.',
      );
    }
    await runtime.sync.enqueue(record: record, consent: consent);
  }

  Future<CloudSyncReport> synchronize() async {
    _requireCurrentOwner();
    final supabaseSession = client.auth.currentSession;
    if (supabaseSession == null) {
      throw StateError('Authenticated cloud session unavailable.');
    }
    final session =
        SupabaseCloudAuthenticationProvider.cloudSessionFromSupabase(
          session: supabaseSession,
          deviceId: device.deviceId,
        );
    return runtime.sync.synchronize(
      consent: consent,
      device: device,
      session: session,
    );
  }

  Future<List<CloudRecordEnvelope>> readConsumedRecords() async {
    _requireCurrentOwner();
    return runtime.store.readAllRecords(ownerId);
  }

  void _requireCurrentOwner() {
    if (!device.active ||
        device.ownerId != ownerId ||
        client.auth.currentUser?.id != ownerId) {
      throw StateError('Cloud coordinator is not bound to the active account.');
    }
  }
}
