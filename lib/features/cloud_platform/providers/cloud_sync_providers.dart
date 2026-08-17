import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../data/database/database_provider.dart';
import '../domain/cloud_identity_models.dart';
import '../domain/cloud_platform_policy.dart';
import '../domain/cloud_sync_models.dart';
import '../services/aes_gcm_cloud_payload_cipher.dart';
import '../services/app_database_cloud_outbox_producer.dart';
import '../services/cloud_account_key_repository.dart';
import '../services/cloud_device_identity_repository.dart';
import '../services/cloud_platform_composition_root.dart';
import '../services/cloud_platform_ports.dart';
import '../services/cloud_runtime_access_gate.dart';
import '../services/cloud_runtime_preparation.dart';
import '../services/cloud_session_sync_coordinator.dart';
import '../services/cloud_transport_activation_lock.dart';
import '../services/local_data_account_boundary.dart';

/// Bootstrap input deliberately excludes credentials. Supabase owns its
/// ephemeral session and the payload cipher owns its key material.
final class CloudSyncBootstrap {
  const CloudSyncBootstrap({
    required this.databasePath,
    required this.device,
    required this.consent,
    required this.cipher,
    required this.connectivity,
  });

  final String databasePath;
  final CloudDeviceRegistration device;
  final CloudPrivacyConsent consent;
  final CloudPayloadCipher cipher;
  final CloudConnectivity connectivity;
}

/// Actual fail-closed composition provider for the durable Supabase ledger.
///
/// The provider is a family so account switching produces a distinct runtime;
/// consumers must invalidate the previous bootstrap when auth state changes.
final cloudSessionSyncCoordinatorProvider = FutureProvider.autoDispose
    .family<CloudSessionSyncCoordinator, CloudSyncBootstrap>((
      ref,
      bootstrap,
    ) async {
      if (!AppEnvironment.cloudConfigured) {
        throw StateError('BIL cloud is not configured.');
      }
      if (!bootstrap.cipher.isAvailable) {
        throw StateError('Encrypted cloud payload storage is unavailable.');
      }
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null ||
          user.id != bootstrap.device.ownerId ||
          user.id != bootstrap.consent.ownerId ||
          !bootstrap.device.active ||
          !bootstrap.consent.isActive) {
        throw StateError('Cloud bootstrap does not match the active account.');
      }
      final runtime = await CloudPlatformCompositionRoot.createSupabase(
        databasePath: bootstrap.databasePath,
        client: client,
        cipher: bootstrap.cipher,
        connectivity: bootstrap.connectivity,
      );
      ref.onDispose(() => runtime.store.close());
      return CloudSessionSyncCoordinator(
        runtime: runtime,
        client: client,
        device: bootstrap.device,
        consent: bootstrap.consent,
      );
    });

/// Device-local ownership guard evaluated before an authenticated account may
/// enter the health database. This provider deliberately does not start cloud
/// transport or upload anything.
final localDataAccountBoundaryProvider = Provider<LocalDataAccountBoundary>((
  ref,
) {
  return LocalDataAccountBoundary(ref.watch(databaseProvider));
});

/// Binds guest/local data to the first authenticated account and fails closed
/// if another account later attempts to enter the same non-empty local store.
final localDataAccountBindingProvider =
    FutureProvider.autoDispose<LocalDataAccountBinding?>((ref) async {
      if (!AppEnvironment.cloudConfigured || !Supabase.instance.isInitialized) {
        return null;
      }
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;
      return ref
          .watch(localDataAccountBoundaryProvider)
          .bindAuthenticatedOwner(user.id);
    });

/// Production preparation pass for encrypted cloud sync.
///
/// This is intentionally *not* a transport activation. It waits for guest ->
/// account binding, verifies server entitlement + explicit cloud consent,
/// resolves the account key from Vault/secure storage, and converts dirty local
/// rows into the durable encrypted outbox. The connectivity object is locked
/// offline in this phase, so no health record can leave the device yet.
final cloudRuntimePreparationProvider =
    FutureProvider.autoDispose<CloudRuntimePreparation>((ref) async {
      if (!AppEnvironment.cloudConfigured || !Supabase.instance.isInitialized) {
        return const CloudRuntimePreparation(
          disposition: CloudRuntimeAccessDisposition.unavailable,
        );
      }

      final client = Supabase.instance.client;
      final binding = await ref.watch(localDataAccountBindingProvider.future);
      if (binding?.requiresAccountResolution == true) {
        return CloudRuntimePreparation(
          disposition: CloudRuntimeAccessDisposition.localOwnerMismatch,
          ownerId: client.auth.currentUser?.id,
        );
      }

      final gate = CloudRuntimeAccessGate(
        client: client,
        accountBoundary: ref.watch(localDataAccountBoundaryProvider),
      );
      final access = await gate.evaluate();
      if (!access.isReady) {
        return CloudRuntimePreparation(
          disposition: access.disposition,
          ownerId: access.ownerId,
        );
      }

      final ownerId = access.ownerId;
      final grantedAt = access.consentGrantedAt;
      if (ownerId == null || grantedAt == null) {
        return CloudRuntimePreparation(
          disposition: CloudRuntimeAccessDisposition.unavailable,
          ownerId: ownerId,
        );
      }

      try {
        final key = await CloudAccountKeyRepository(
          client: client,
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
              CloudEntityKind.nutrition,
              CloudEntityKind.hydration,
            },
          ),
        );
        final coordinator = await ref.watch(
          cloudSessionSyncCoordinatorProvider(
            CloudSyncBootstrap(
              databasePath: ledgerPath,
              device: device,
              consent: consent,
              cipher: AesGcmCloudPayloadCipher(key),
              connectivity: const CloudTransportActivationLock(),
            ),
          ).future,
        );
        final report = await AppDatabaseCloudOutboxProducer(
          database: ref.watch(databaseProvider),
          accountBoundary: ref.watch(localDataAccountBoundaryProvider),
          sink: coordinator,
        ).produce();
        return CloudRuntimePreparation(
          disposition: CloudRuntimeAccessDisposition.ready,
          ownerId: ownerId,
          enqueued: report.enqueued,
          remainingDirty: report.remainingDirty,
        );
      } on Object {
        return CloudRuntimePreparation(
          disposition: CloudRuntimeAccessDisposition.unavailable,
          ownerId: ownerId,
        );
      }
    });
