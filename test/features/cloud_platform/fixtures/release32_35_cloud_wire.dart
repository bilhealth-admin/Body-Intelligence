// Exact wire/parser methods from release source 3f0085e6e6686f2e87e9cf14789e9e578ea64159.
// Captured from git show, not recreated from memory.
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';

class Release32CloudWire {
  static Map<String, Object?> encode(CloudSyncOperation value) =>
      _operationJson(value);
  static CloudRecordEnvelope decode(Map<String, Object?> value) =>
      _recordFromJson(value);
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
