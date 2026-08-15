import '../domain/cloud_platform_policy.dart';
import '../persistence/sqlite_cloud_platform_store.dart';
import 'cloud_backup_restore_engine.dart';
import 'cloud_durable_ports.dart';
import 'cloud_identity_runtime.dart';
import 'cloud_observability_runtime.dart';
import 'cloud_platform_ports.dart';
import 'cloud_privacy_lifecycle_engine.dart';
import 'durable_offline_first_cloud_platform.dart';
import 'supabase_cloud_authentication_provider.dart';
import 'supabase_cloud_transport.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class CloudPlatformRuntime {
  const CloudPlatformRuntime({
    required this.store,
    required this.sync,
    required this.identity,
    required this.backupRestore,
    required this.privacy,
    required this.observability,
  });
  final SqliteCloudPlatformStore store;
  final DurableOfflineFirstCloudPlatform sync;
  final CloudIdentityRuntime identity;
  final CloudBackupRestoreEngine backupRestore;
  final CloudPrivacyLifecycleEngine privacy;
  final CloudObservabilityRuntime observability;
}

final class CloudPlatformCompositionRoot {
  const CloudPlatformCompositionRoot._();

  static Future<CloudPlatformRuntime> create({
    required String databasePath,
    required CloudTransport transport,
    required CloudPayloadCipher cipher,
    required CloudConnectivity connectivity,
    required CloudAuthenticationProvider authentication,
    CloudClock clock = const SystemCloudClock(),
    CloudPlatformPolicy policy = const CloudPlatformPolicy(),
    CloudFailureInjector failureInjector = const NoopCloudFailureInjector(),
  }) async {
    final store = SqliteCloudPlatformStore.open(databasePath);
    await store.initialize();
    return CloudPlatformRuntime(
      store: store,
      sync: DurableOfflineFirstCloudPlatform(
        store: store,
        transport: transport,
        cipher: cipher,
        connectivity: connectivity,
        clock: clock,
        policy: policy,
        failureInjector: failureInjector,
      ),
      identity: CloudIdentityRuntime(store: store, auth: authentication),
      backupRestore: CloudBackupRestoreEngine(store: store, cipher: cipher),
      privacy: CloudPrivacyLifecycleEngine(store: store, auth: authentication),
      observability: CloudObservabilityRuntime(store: store),
    );
  }

  static Future<CloudPlatformRuntime> createSupabase({
    required String databasePath,
    required SupabaseClient client,
    required CloudPayloadCipher cipher,
    required CloudConnectivity connectivity,
    CloudClock clock = const SystemCloudClock(),
    CloudPlatformPolicy policy = const CloudPlatformPolicy(),
  }) => create(
    databasePath: databasePath,
    transport: SupabaseCloudTransport(client),
    cipher: cipher,
    connectivity: connectivity,
    authentication: SupabaseCloudAuthenticationProvider(client),
    clock: clock,
    policy: policy,
  );
}
