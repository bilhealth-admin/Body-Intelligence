import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/database/app_database.dart';
import '../domain/cloud_platform_policy.dart';
import '../domain/cloud_sync_models.dart';
import 'aes_gcm_cloud_payload_cipher.dart';
import 'app_database_cloud_inbox_applier.dart';
import 'app_database_cloud_outbox_producer.dart';
import 'cloud_account_key_repository.dart';
import 'cloud_device_identity_repository.dart';
import 'cloud_platform_composition_root.dart';
import 'cloud_runtime_access_gate.dart';
import 'cloud_session_sync_coordinator.dart';
import 'local_data_account_boundary.dart';
import 'system_cloud_connectivity.dart';

enum CloudManualSyncDisposition {
  completed,
  offline,
  notAuthenticated,
  localOwnerMismatch,
  entitlementMissing,
  consentMissing,
  unavailable,
}

final class CloudManualSyncResult {
  const CloudManualSyncResult({
    required this.disposition,
    this.completedAt,
    this.ownerId,
    this.enqueued = 0,
    this.pushed = 0,
    this.pulled = 0,
    this.applied = 0,
    this.conflicts = 0,
    this.pending = 0,
  }) : assert(
         disposition == CloudManualSyncDisposition.completed
             ? completedAt != null
             : completedAt == null,
         'Only a completed sync may expose its authoritative completion time.',
       );

  final CloudManualSyncDisposition disposition;

  /// Authoritative completion instant from [CloudSyncReport]. It is null for
  /// every failed, blocked, offline, or unavailable attempt.
  final DateTime? completedAt;
  final String? ownerId;
  final int enqueued;
  final int pushed;
  final int pulled;
  final int applied;
  final int conflicts;
  final int pending;

  bool get completed => disposition == CloudManualSyncDisposition.completed;
}

/// Explicit one-shot encrypted cloud synchronization.
///
/// This service is intentionally not used by startup. It can run only after
/// the account capability, explicit cloud-sync consent, local-owner boundary,
/// account key, authenticated Supabase session and real connectivity all pass.
/// Nutrition remains excluded from the selective policy until its relational
/// merge is closed separately.
final class CloudManualSyncService {
  CloudManualSyncService({
    required this._client,
    required this._database,
    required this._accountBoundary,
  });

  final SupabaseClient _client;
  final AppDatabase _database;
  final LocalDataAccountBoundary _accountBoundary;

  Future<CloudManualSyncResult> runOnce() async {
    final access = await CloudRuntimeAccessGate(
      client: _client,
      accountBoundary: _accountBoundary,
    ).evaluate();
    if (!access.isReady) {
      return CloudManualSyncResult(
        disposition: _mapAccess(access.disposition),
        ownerId: access.ownerId,
      );
    }

    final ownerId = access.ownerId;
    final grantedAt = access.consentGrantedAt;
    if (ownerId == null || grantedAt == null) {
      return CloudManualSyncResult(
        disposition: CloudManualSyncDisposition.unavailable,
        ownerId: ownerId,
      );
    }

    final connectivity = await SystemCloudConnectivitySnapshot.current();
    if (!connectivity.isOnline) {
      return CloudManualSyncResult(
        disposition: CloudManualSyncDisposition.offline,
        ownerId: ownerId,
      );
    }

    final session = _client.auth.currentSession;
    if (session == null || _client.auth.currentUser?.id != ownerId) {
      return CloudManualSyncResult(
        disposition: CloudManualSyncDisposition.notAuthenticated,
        ownerId: ownerId,
      );
    }

    CloudPlatformRuntime? runtime;
    try {
      final key = await CloudAccountKeyRepository(
        client: _client,
      ).resolve(ownerId);
      final device = await CloudDeviceIdentityRepository().resolve(ownerId);
      final supportDirectory = await getApplicationSupportDirectory();
      final ledgerPath = p.join(
        supportDirectory.path,
        'bil_cloud_ledger_v1.sqlite',
      );
      final consent = CloudPrivacyConsent(
        ownerId: ownerId,
        grantedAt: grantedAt,
        policy: CloudSelectiveSyncPolicy(
          enabledKinds: const <CloudEntityKind>{
            CloudEntityKind.profile,
            CloudEntityKind.weight,
            CloudEntityKind.hydration,
          },
        ),
      );

      runtime = await CloudPlatformCompositionRoot.createSupabase(
        databasePath: ledgerPath,
        client: _client,
        cipher: AesGcmCloudPayloadCipher(key),
        connectivity: connectivity,
      );
      final coordinator = CloudSessionSyncCoordinator(
        runtime: runtime,
        client: _client,
        device: device,
        consent: consent,
      );

      final produce = await AppDatabaseCloudOutboxProducer(
        database: _database,
        accountBoundary: _accountBoundary,
        sink: coordinator,
      ).produce();
      final sync = await coordinator.synchronize();
      if (sync.availability != CloudPlatformAvailability.ready) {
        return CloudManualSyncResult(
          disposition: sync.availability == CloudPlatformAvailability.localOnly
              ? CloudManualSyncDisposition.offline
              : CloudManualSyncDisposition.unavailable,
          ownerId: ownerId,
          enqueued: produce.enqueued,
          pushed: sync.pushed,
          pulled: sync.pulled,
          conflicts: sync.conflicts,
          pending: sync.pending,
        );
      }
      final consumed = await coordinator.readConsumedRecords();
      final apply =
          await AppDatabaseCloudInboxApplier(
            database: _database,
            accountBoundary: _accountBoundary,
          ).apply(
            ownerId: ownerId,
            localDeviceId: device.deviceId,
            records: consumed,
          );

      return CloudManualSyncResult(
        disposition: CloudManualSyncDisposition.completed,
        completedAt: sync.completedAt.toUtc(),
        ownerId: ownerId,
        enqueued: produce.enqueued,
        pushed: sync.pushed,
        pulled: sync.pulled,
        applied: apply.applied + apply.acknowledged,
        conflicts: sync.conflicts + apply.conflicts,
        pending: sync.pending,
      );
    } on Object {
      return CloudManualSyncResult(
        disposition: CloudManualSyncDisposition.unavailable,
        ownerId: ownerId,
      );
    } finally {
      await runtime?.store.close();
    }
  }

  static CloudManualSyncDisposition _mapAccess(
    CloudRuntimeAccessDisposition disposition,
  ) => switch (disposition) {
    CloudRuntimeAccessDisposition.ready => CloudManualSyncDisposition.completed,
    CloudRuntimeAccessDisposition.notAuthenticated =>
      CloudManualSyncDisposition.notAuthenticated,
    CloudRuntimeAccessDisposition.localOwnerMismatch =>
      CloudManualSyncDisposition.localOwnerMismatch,
    CloudRuntimeAccessDisposition.entitlementMissing =>
      CloudManualSyncDisposition.entitlementMissing,
    CloudRuntimeAccessDisposition.consentMissing =>
      CloudManualSyncDisposition.consentMissing,
    CloudRuntimeAccessDisposition.unavailable =>
      CloudManualSyncDisposition.unavailable,
  };
}
