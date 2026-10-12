import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/database/database_provider.dart';
import 'cloud_restore_providers.dart';
import '../services/aes_gcm_cloud_payload_cipher.dart';
import '../services/cloud_account_key_repository.dart';
import '../services/cloud_device_identity_repository.dart';
import '../services/cloud_restore_conflict_service.dart';
import '../services/cloud_restore_consent_repository.dart';
import '../services/cloud_restore_v2_engine.dart';

import '../services/supabase_cloud_restore_v2_transport.dart';

final cloudRestoreConflictServiceProvider =
    Provider<CloudRestoreConflictService>(
      (ref) => CloudRestoreConflictService(() async {
        final client = Supabase.instance.client;
        final consent = ref.read(cloudRestoreConsentRepositoryProvider);
        final state = await consent.read();
        if (state.availability != CloudRestoreConsentAvailability.available ||
            state.grantedScopes.isEmpty) {
          throw StateError('Restore consent required');
        }
        final lease = consent.captureLease(state);
        final owner = state.ownerId!;
        bool current() => state.grantedScopes.every(
          (scope) => consent.isCurrent(lease, scope),
        );
        final key = await CloudAccountKeyRepository(
          client: client,
        ).resolveExisting(owner);
        if (key == null || !current()) {
          throw StateError('Restore key unavailable');
        }
        final device = await CloudDeviceIdentityRepository().resolve(owner);
        if (!current()) throw StateError('Restore context changed');
        return CloudRestoreV2Engine(
          database: ref.read(databaseProvider),
          ownerId: owner,
          deviceId: device.deviceId,
          keyId: sha256.convert(key).toString(),
          allowedScopes: state.grantedScopes.map((scope) => scope.name).toSet(),
          cipher: AesGcmCloudPayloadCipher(key),
          ownerIsCurrent: current,
          transport: SupabaseCloudRestoreV2Transport(
            client,
            ownerId: owner,
            isCurrent: current,
          ),
        );
      }),
    );
