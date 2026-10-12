import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../data/database/database_provider.dart';
import '../services/cloud_restore_consent_local_store.dart';
import '../services/cloud_restore_consent_repository.dart';
import 'cloud_sync_providers.dart';

final cloudRestoreConsentRepositoryProvider =
    Provider<CloudRestoreConsentRepository>((ref) {
      final repository = CloudRestoreConsentRepository(
        client: Supabase.instance.client,
        localStore: AppDatabaseCloudRestoreConsentLocalStore(
          ref.watch(databaseProvider),
        ),
      );
      ref.listen(cloudSyncConsentStateProvider, (previous, next) {
        if (next.value?.granted != true) repository.invalidate();
      });
      ref.onDispose(repository.dispose);
      return repository;
    });

final cloudRestoreConsentStateProvider =
    FutureProvider.autoDispose<CloudRestoreConsentState>((ref) async {
      if (!AppEnvironment.supabaseRuntimeReady) {
        return const CloudRestoreConsentState(
          availability: CloudRestoreConsentAvailability.unavailable,
        );
      }
      final owner = ref.watch(cloudAuthOwnerIdProvider);
      final base = ref.watch(cloudSyncConsentStateProvider);
      if (owner.isLoading || base.isLoading) {
        return const CloudRestoreConsentState(
          availability: CloudRestoreConsentAvailability.unavailable,
        );
      }
      if (owner.value == null) {
        return const CloudRestoreConsentState(
          availability: CloudRestoreConsentAvailability.signedOut,
        );
      }
      return ref.watch(cloudRestoreConsentRepositoryProvider).read();
    });
