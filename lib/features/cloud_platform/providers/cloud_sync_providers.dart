import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../domain/cloud_identity_models.dart';
import '../domain/cloud_platform_policy.dart';
import '../services/cloud_platform_composition_root.dart';
import '../services/cloud_platform_ports.dart';
import '../services/cloud_session_sync_coordinator.dart';

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
