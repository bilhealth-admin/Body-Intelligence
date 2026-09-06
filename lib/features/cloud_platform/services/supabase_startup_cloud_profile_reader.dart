import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/cloud_sync_models.dart';
import 'aes_gcm_cloud_payload_cipher.dart';
import 'cloud_account_key_repository.dart';
import 'startup_cloud_profile_restore_service.dart';

typedef StartupCloudPayloadDecryptor =
    Future<Map<String, Object?>> Function(Map<String, Object?> payload);

/// Supabase adapter for startup's selective, read-only recovery path.
///
/// It resolves only an existing account key (from secure local storage or the
/// read-only Vault recovery RPC), performs owner- and type-filtered SELECTs, and
/// then decrypts profile, weight and hydration. It cannot create a key, submit
/// operations, register a device, or mutate any remote row.
final class SupabaseStartupCloudProfileReader
    implements StartupCloudProfileReader {
  const SupabaseStartupCloudProfileReader({
    required this.client,
    required this.keyRepository,
  });

  final SupabaseClient client;
  final CloudAccountKeyRepository keyRepository;

  @override
  Future<List<CloudRecordEnvelope>> readRestoreRecords(String ownerId) async {
    final owner = ownerId.trim();
    final user = client.auth.currentUser;
    if (owner.isEmpty || user == null || user.id != owner) {
      return const <CloudRecordEnvelope>[];
    }

    final key = await keyRepository.resolveExisting(owner);
    if (key == null || client.auth.currentUser?.id != owner) {
      return const <CloudRecordEnvelope>[];
    }

    const pageSize = 500;
    final rows = <Map<String, Object?>>[];
    for (var offset = 0; ; offset += pageSize) {
      final response = await client
          .from('bil_cloud_records')
          .select(
            'owner_id,entity_kind,record_id,revision_device_id,'
            'revision_sequence,updated_at,deleted_at,schema_version,payload',
          )
          .eq('owner_id', owner)
          .inFilter(
            'entity_kind',
            startupCloudRestoreEntityKinds
                .map((kind) => kind.name)
                .toList(growable: false),
          )
          .isFilter('deleted_at', null)
          .order('entity_kind')
          .order('record_id')
          .range(offset, offset + pageSize - 1);
      if (client.auth.currentUser?.id != owner) {
        return const <CloudRecordEnvelope>[];
      }
      final page = response
          .map((row) => Map<String, Object?>.from(row))
          .toList(growable: false);
      rows.addAll(page);
      if (page.length < pageSize) break;
    }

    final cipher = AesGcmCloudPayloadCipher(key);
    final records = await decodeStartupCloudRestoreRows(
      rows: rows,
      ownerId: owner,
      decryptPayload: cipher.decrypt,
    );
    return client.auth.currentUser?.id == owner
        ? records
        : const <CloudRecordEnvelope>[];
  }
}

@visibleForTesting
Future<List<CloudRecordEnvelope>> decodeStartupCloudRestoreRows({
  required Iterable<Map<String, Object?>> rows,
  required String ownerId,
  required StartupCloudPayloadDecryptor decryptPayload,
}) async {
  final owner = ownerId.trim();
  if (owner.isEmpty) {
    throw ArgumentError.value(ownerId, 'ownerId', 'Must not be empty');
  }

  CloudRecordEnvelope? latestProfile;
  final progress = <CloudRecordEnvelope>[];
  for (final row in rows) {
    final kind = switch (_requiredString(row, 'entity_kind')) {
      'profile' => CloudEntityKind.profile,
      'weight' => CloudEntityKind.weight,
      'hydration' => CloudEntityKind.hydration,
      _ => throw const FormatException(
        'Unsupported startup cloud restore entity.',
      ),
    };
    if (row['owner_id']?.toString() != owner ||
        row['deleted_at'] != null ||
        row['payload'] is! Map) {
      throw const FormatException('Invalid startup cloud restore envelope.');
    }
    final encryptedPayload = Map<String, Object?>.from(row['payload']! as Map);
    final record = CloudRecordEnvelope(
      entityKind: kind,
      recordId: _requiredString(row, 'record_id'),
      ownerId: owner,
      revision: CloudRevision(
        deviceId: _requiredString(row, 'revision_device_id'),
        sequence: _requiredInt(row, 'revision_sequence'),
      ),
      updatedAt: DateTime.parse(_requiredString(row, 'updated_at')).toUtc(),
      deletedAt: null,
      schemaVersion: _requiredInt(row, 'schema_version'),
      payload: await decryptPayload(encryptedPayload),
    );
    if (kind == CloudEntityKind.profile) {
      if (latestProfile == null ||
          record.updatedAt.isAfter(latestProfile.updatedAt)) {
        latestProfile = record;
      }
    } else {
      progress.add(record);
    }
  }

  progress.sort((left, right) {
    final kindOrder = left.entityKind.index.compareTo(right.entityKind.index);
    return kindOrder != 0 ? kindOrder : left.recordId.compareTo(right.recordId);
  });
  return List<CloudRecordEnvelope>.unmodifiable([?latestProfile, ...progress]);
}

String _requiredString(Map<String, Object?> row, String key) {
  final value = row[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Invalid startup cloud restore field: $key');
  }
  return value;
}

int _requiredInt(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is! num || value.toInt() != value || value.toInt() < 0) {
    throw FormatException('Invalid startup cloud restore field: $key');
  }
  return value.toInt();
}
