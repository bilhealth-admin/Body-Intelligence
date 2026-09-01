import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/cloud_sync_models.dart';
import 'aes_gcm_cloud_payload_cipher.dart';
import 'cloud_account_key_repository.dart';
import 'startup_cloud_profile_restore_service.dart';

/// Supabase adapter for startup's profile-only, read-only recovery path.
///
/// It performs one owner-filtered SELECT and decrypts only with key material
/// already cached on this device. It cannot create a key, submit operations,
/// register a device, or mutate any remote row.
final class SupabaseStartupCloudProfileReader
    implements StartupCloudProfileReader {
  const SupabaseStartupCloudProfileReader({
    required this.client,
    required this.keyRepository,
  });

  final SupabaseClient client;
  final CloudAccountKeyRepository keyRepository;

  @override
  Future<CloudRecordEnvelope?> readLatestProfile(String ownerId) async {
    final owner = ownerId.trim();
    final user = client.auth.currentUser;
    if (owner.isEmpty || user == null || user.id != owner) return null;

    final key = await keyRepository.resolveExisting(owner);
    if (key == null) return null;
    final rows = await client
        .from('bil_cloud_records')
        .select(
          'owner_id,entity_kind,record_id,revision_device_id,'
          'revision_sequence,updated_at,deleted_at,schema_version,payload',
        )
        .eq('owner_id', owner)
        .eq('entity_kind', CloudEntityKind.profile.name)
        .isFilter('deleted_at', null)
        .order('updated_at', ascending: false)
        .limit(1);
    if (rows.isEmpty || client.auth.currentUser?.id != owner) return null;

    final row = Map<String, Object?>.from(rows.single);
    if (row['owner_id']?.toString() != owner ||
        row['entity_kind']?.toString() != CloudEntityKind.profile.name ||
        row['payload'] is! Map) {
      throw const FormatException('Invalid startup cloud profile envelope.');
    }
    final encryptedPayload = Map<String, Object?>.from(row['payload']! as Map);
    final payload = await AesGcmCloudPayloadCipher(
      key,
    ).decrypt(encryptedPayload);
    return CloudRecordEnvelope(
      entityKind: CloudEntityKind.profile,
      recordId: _requiredString(row, 'record_id'),
      ownerId: owner,
      revision: CloudRevision(
        deviceId: _requiredString(row, 'revision_device_id'),
        sequence: _requiredInt(row, 'revision_sequence'),
      ),
      updatedAt: DateTime.parse(_requiredString(row, 'updated_at')).toUtc(),
      deletedAt: null,
      schemaVersion: _requiredInt(row, 'schema_version'),
      payload: payload,
    );
  }

  static String _requiredString(Map<String, Object?> row, String key) {
    final value = row[key]?.toString().trim();
    if (value == null || value.isEmpty) {
      throw FormatException('Invalid startup cloud profile field: $key');
    }
    return value;
  }

  static int _requiredInt(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is! num || value.toInt() != value || value.toInt() < 0) {
      throw FormatException('Invalid startup cloud profile field: $key');
    }
    return value.toInt();
  }
}
