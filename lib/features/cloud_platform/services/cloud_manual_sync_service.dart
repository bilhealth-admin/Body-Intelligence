import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../../../app/services/health_storage_directory_native.dart';
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
import 'cloud_restore_consent_local_store.dart';
import 'cloud_restore_consent_repository.dart';
import 'cloud_restore_v2_engine.dart';
import 'supabase_cloud_restore_v2_transport.dart';
import 'cloud_session_sync_coordinator.dart';
import 'local_data_account_boundary.dart';
import 'system_cloud_connectivity.dart';

enum CloudManualSyncDisposition {
  completed,
  partial,
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
    this.unsupported = 0,
    this.reason,
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
  final int unsupported;
  final String? reason;

  factory CloudManualSyncResult.fromReports({
    required String ownerId,
    required CloudOutboxProductionReport produce,
    required CloudSyncReport sync,
    required CloudInboxApplyReport apply,
    CloudRestoreV2Report? restore,
  }) {
    // Transport completion does not prove that local relational restoration
    // finished. Keep unsupported records/conflicts visible as partial work.
    final complete =
        sync.availability == CloudPlatformAvailability.ready &&
        sync.failureCode == null &&
        sync.pending == 0 &&
        produce.eligibleRemaining == 0 &&
        sync.conflicts == 0 &&
        apply.unsupported == 0 &&
        apply.conflicts == 0 &&
        (restore?.completed ?? true);
    return CloudManualSyncResult(
      disposition: complete
          ? CloudManualSyncDisposition.completed
          : CloudManualSyncDisposition.partial,
      completedAt: complete
          ? (restore?.completedAt ?? sync.completedAt).toUtc()
          : null,
      ownerId: ownerId,
      enqueued: produce.enqueued,
      pushed: sync.pushed + (restore?.pushed ?? 0),
      pulled: sync.pulled + (restore?.pulled ?? 0),
      applied: apply.applied + apply.acknowledged + (restore?.applied ?? 0),
      conflicts: sync.conflicts + apply.conflicts + (restore?.conflicts ?? 0),
      pending:
          sync.pending + produce.eligibleRemaining + (restore?.pending ?? 0),
      unsupported: apply.unsupported,
      reason:
          sync.failureCode ??
          restore?.reason ??
          ((sync.conflicts + apply.conflicts + (restore?.conflicts ?? 0)) > 0
              ? 'conflict_review_required'
              : apply.unsupported > 0
              ? 'record_unsupported'
              : !complete
              ? 'pending_local_changes'
              : null),
    );
  }

  bool get completed => disposition == CloudManualSyncDisposition.completed;
}

/// Explicit one-shot encrypted cloud synchronization.
///
/// This service is intentionally not used by startup. It can run only after
/// the account capability, explicit cloud-sync consent, local-owner boundary,
/// account key, authenticated Supabase session and real connectivity all pass.
/// Optional nutrition/goals use the independently negotiated V2 contract;
/// the original selective policy and consent are never silently expanded.
final class CloudManualSyncService {
  CloudManualSyncService({
    required this._client,
    required this._database,
    required this._accountBoundary,
    this._restoreConsent,
  });

  final SupabaseClient _client;
  final AppDatabase _database;
  final LocalDataAccountBoundary _accountBoundary;
  final CloudRestoreConsentRepository? _restoreConsent;
  Future<CloudManualSyncResult>? _inFlight;

  static const int _maximumPagesPerRun = 20;

  Future<CloudManualSyncResult> runOnce() =>
      _inFlight ??= _runScoped().whenComplete(() => _inFlight = null);

  Future<CloudManualSyncResult> _runScoped() async {
    final owner = _client.auth.currentUser?.id;
    var contextChanged = false;
    final auth = _client.auth.onAuthStateChange.listen((event) {
      if (event.session?.user.id != owner) contextChanged = true;
    });
    try {
      return await _runOnce(
        () =>
            !contextChanged &&
            owner != null &&
            _client.auth.currentUser?.id == owner,
      );
    } finally {
      await auth.cancel();
    }
  }

  Future<CloudManualSyncResult> _runOnce(bool Function() isCurrent) async {
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
    var stage = 'account_key';
    try {
      final key = await CloudAccountKeyRepository(
        client: _client,
      ).resolve(ownerId);
      stage = 'device_identity';
      final device = await CloudDeviceIdentityRepository().resolve(ownerId);
      if (!isCurrent()) throw StateError('Cloud session changed');
      stage = 'local_storage';
      final supportDirectory = await getProtectedApplicationSupportDirectory();
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

      stage = 'ledger_open';
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

      stage = 'outbox_production';
      final produce = await AppDatabaseCloudOutboxProducer(
        database: _database,
        accountBoundary: _accountBoundary,
        sink: coordinator,
      ).produce();
      stage = 'page_drain';
      final sync = await drainCloudSyncPages(
        coordinator.synchronize,
        maximumPages: _maximumPagesPerRun,
      );
      if (sync.availability != CloudPlatformAvailability.ready &&
          sync.availability != CloudPlatformAvailability.paused) {
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
          reason: sync.failureCode,
        );
      }
      stage = 'inbox_apply';
      final consumed = await coordinator.readConsumedRecords();
      if (!isCurrent()) throw StateError('Cloud session changed');
      final apply =
          await AppDatabaseCloudInboxApplier(
            database: _database,
            accountBoundary: _accountBoundary,
          ).apply(
            ownerId: ownerId,
            localDeviceId: device.deviceId,
            records: consumed,
          );

      stage = 'restore_v2';
      final consentRepository =
          _restoreConsent ??
          CloudRestoreConsentRepository(
            client: _client,
            localStore: AppDatabaseCloudRestoreConsentLocalStore(_database),
          );
      CloudRestoreV2Report restore;
      try {
        final state = await consentRepository.read();
        if (!isCurrent()) throw StateError('Cloud session changed');
        if (state.availability != CloudRestoreConsentAvailability.available) {
          restore = CloudRestoreV2Report(
            reason: 'server_or_consent_unavailable',
          );
        } else {
          final lease = consentRepository.captureLease(state);
          final scopes = state.grantedScopes;
          restore = await CloudRestoreV2Engine(
            database: _database,
            ownerId: ownerId,
            deviceId: device.deviceId,
            keyId: sha256.convert(key).toString(),
            allowedScopes: scopes.map((scope) => scope.name).toSet(),
            cipher: AesGcmCloudPayloadCipher(key),
            transport: SupabaseCloudRestoreV2Transport(
              _client,
              ownerId: ownerId,
              isCurrent: () =>
                  isCurrent() &&
                  scopes.every(
                    (scope) => consentRepository.isCurrent(lease, scope),
                  ),
            ),
            ownerIsCurrent: () =>
                isCurrent() &&
                scopes.every(
                  (scope) => consentRepository.isCurrent(lease, scope),
                ),
          ).run(scopes.map((scope) => scope.name).toSet());
        }
      } finally {
        if (_restoreConsent == null) consentRepository.dispose();
      }

      return CloudManualSyncResult.fromReports(
        ownerId: ownerId,
        produce: produce,
        sync: sync,
        apply: apply,
        restore: restore,
      );
    } on Object {
      return CloudManualSyncResult(
        disposition: CloudManualSyncDisposition.unavailable,
        ownerId: ownerId,
        reason: 'cloud_sync_${stage}_failed',
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

/// Drains a bounded number of cursor-backed pages while yielding between
/// pages. Every page is durably stored by the platform before this helper is
/// called again, so interruption never discards the saved cursor.
Future<CloudSyncReport> drainCloudSyncPages(
  Future<CloudSyncReport> Function() synchronizePage, {
  int maximumPages = 20,
}) async {
  if (maximumPages <= 0) {
    throw ArgumentError.value(maximumPages, 'maximumPages', 'Must be positive');
  }
  CloudSyncReport? latest;
  DateTime? startedAt;
  var pushed = 0;
  var pulled = 0;
  var conflicts = 0;
  for (var page = 0; page < maximumPages; page++) {
    final report = await synchronizePage();
    startedAt ??= report.startedAt;
    latest = report;
    pushed += report.pushed;
    pulled += report.pulled;
    conflicts += report.conflicts;
    if (!report.canContinue) break;
    await Future<void>.delayed(Duration.zero);
  }
  final report = latest!;
  return CloudSyncReport(
    startedAt: startedAt!,
    completedAt: report.completedAt,
    pushed: pushed,
    pulled: pulled,
    conflicts: conflicts,
    pending: report.pending,
    availability: report.availability,
    diagnostics: report.diagnostics,
    hasMore: report.hasMore,
    cursorAdvanced: report.cursorAdvanced,
    failureCode: report.failureCode,
  );
}
