import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/cloud_identity_models.dart';
import '../domain/cloud_sync_models.dart';
import 'cloud_platform_ports.dart';

/// Authenticated transport for the durable BIL cloud ledger.
///
/// The matching RPC validates `auth.uid()` server-side.  This class also
/// rejects a mismatched local session before any request leaves the device.
final class SupabaseCloudTransport implements CloudTransport {
  const SupabaseCloudTransport(this.client);

  final SupabaseClient client;

  @override
  Future<CloudSyncBatchResult> synchronize({
    required String ownerId,
    required String deviceId,
    required CloudSession session,
    required List<CloudSyncOperation> operations,
    required String? cursor,
  }) async {
    final user = client.auth.currentUser;
    if (user == null || user.id != ownerId || session.ownerId != ownerId) {
      throw StateError('Authenticated cloud owner does not match sync owner.');
    }
    if (session.deviceId != deviceId) {
      throw StateError(
        'Authenticated cloud device does not match sync device.',
      );
    }
    if (operations.any(
      (operation) =>
          operation.record.ownerId != ownerId ||
          operation.record.revision.deviceId != deviceId,
    )) {
      throw StateError('Cross-account or cross-device sync batch rejected.');
    }

    final response = await client.rpc(
      'bil_sync_records',
      params: <String, Object?>{
        'p_device_id': deviceId,
        'p_cursor': int.tryParse(cursor ?? '') ?? 0,
        'p_operations': operations.map(_operationJson).toList(growable: false),
      },
    );
    if (response is! Map) {
      throw const FormatException('Invalid BIL cloud sync response.');
    }
    final body = Map<String, Object?>.from(response);
    final acknowledged = (body['acknowledged'] as List? ?? const <Object?>[])
        .map((value) => value.toString())
        .toList(growable: false);
    final records = (body['records'] as List? ?? const <Object?>[])
        .map(
          (value) => _recordFromJson(Map<String, Object?>.from(value as Map)),
        )
        .toList(growable: false);
    final submitted = operations.map((value) => value.operationId).toSet();
    if (!acknowledged.every(submitted.contains)) {
      throw const FormatException('Invalid BIL cloud acknowledgement.');
    }
    if (!records.every((record) => record.ownerId == ownerId)) {
      throw const FormatException('Cross-account BIL cloud response.');
    }
    final serverCursor = (body['cursor'] ?? cursor)?.toString();
    if (serverCursor != null && int.tryParse(serverCursor) == null) {
      throw const FormatException('Invalid BIL cloud cursor.');
    }
    return CloudSyncBatchResult(
      acknowledgedOperationIds: acknowledged,
      remoteRecords: records,
      serverCursor: serverCursor,
    );
  }

  static Map<String, Object?> _operationJson(CloudSyncOperation operation) => {
    'operation_id': operation.operationId,
    'mutation': operation.mutation.name,
    'record': _recordJson(operation.record),
  };

  static Map<String, Object?> _recordJson(CloudRecordEnvelope record) => {
    'entity_kind': record.entityKind.name,
    'record_id': record.recordId,
    'revision_device_id': record.revision.deviceId,
    'revision_sequence': record.revision.sequence,
    'updated_at': record.updatedAt.toIso8601String(),
    'deleted_at': record.deletedAt?.toUtc().toIso8601String(),
    'schema_version': record.schemaVersion,
    'payload': record.payload,
  };

  static CloudRecordEnvelope _recordFromJson(Map<String, Object?> json) {
    final kindName = json['entity_kind']?.toString();
    final kind = CloudEntityKind.values.where(
      (value) => value.name == kindName,
    );
    if (kind.isEmpty) {
      throw FormatException('Unknown BIL cloud entity kind: $kindName');
    }
    final payload = json['payload'];
    if (payload is! Map) {
      throw const FormatException('Invalid BIL cloud record payload.');
    }
    return CloudRecordEnvelope(
      entityKind: kind.single,
      recordId: json['record_id']!.toString(),
      ownerId: json['owner_id']!.toString(),
      revision: CloudRevision(
        deviceId: json['revision_device_id']!.toString(),
        sequence: (json['revision_sequence'] as num).toInt(),
      ),
      updatedAt: DateTime.parse(json['updated_at']!.toString()),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at']!.toString()),
      schemaVersion: (json['schema_version'] as num).toInt(),
      payload: Map<String, Object?>.from(payload),
    );
  }
}
