import 'dart:collection';

import 'cloud_sync_models.dart';

enum CloudAccountStatus {
  signedOut,
  active,
  suspended,
  pendingDeletion,
  deleted,
}

enum CloudDeliveryState { pending, retrying, deadLetter, delivered }

enum CloudRestoreStatus { verified, applied, rolledBack, rejected }

enum CloudAuditSeverity { info, warning, error }

final class CloudAccount {
  CloudAccount({
    required this.ownerId,
    required this.email,
    required this.status,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) : createdAt = createdAt.toUtc(),
       deletedAt = deletedAt?.toUtc(),
       assert(ownerId.isNotEmpty),
       assert(email.isNotEmpty);

  final String ownerId;
  final String email;
  final CloudAccountStatus status;
  final DateTime createdAt;
  final DateTime? deletedAt;
}

final class CloudIdempotencyReceipt {
  CloudIdempotencyReceipt({
    required this.key,
    required this.payloadDigest,
    required DateTime recordedAt,
  }) : recordedAt = recordedAt.toUtc(),
       assert(key.isNotEmpty),
       assert(payloadDigest.isNotEmpty);

  final String key;
  final String payloadDigest;
  final DateTime recordedAt;
}

final class CloudDeadLetter {
  CloudDeadLetter({
    required this.operationId,
    required this.reason,
    required this.attempts,
    required DateTime failedAt,
  }) : failedAt = failedAt.toUtc(),
       assert(operationId.isNotEmpty),
       assert(attempts > 0);

  final String operationId;
  final String reason;
  final int attempts;
  final DateTime failedAt;
}

final class CloudConflictRecord {
  CloudConflictRecord({
    required this.conflictId,
    required this.stableKey,
    required this.reason,
    required this.resolution,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc(),
       assert(conflictId.isNotEmpty),
       assert(stableKey.isNotEmpty);

  final String conflictId;
  final String stableKey;
  final String reason;
  final CloudConflictResolution resolution;
  final DateTime createdAt;
}

final class CloudBackupArtifact {
  CloudBackupArtifact({
    required this.backupId,
    required this.ownerId,
    required this.schemaVersion,
    required this.checksum,
    required Map<String, Object?> encryptedPayload,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc(),
       encryptedPayload = UnmodifiableMapView(
         Map<String, Object?>.of(encryptedPayload),
       ),
       assert(backupId.isNotEmpty),
       assert(ownerId.isNotEmpty),
       assert(schemaVersion > 0),
       assert(checksum.isNotEmpty);

  final String backupId;
  final String ownerId;
  final int schemaVersion;
  final String checksum;
  final DateTime createdAt;
  final Map<String, Object?> encryptedPayload;
}

final class CloudRestoreReport {
  CloudRestoreReport({
    required this.backupId,
    required this.status,
    required this.restoredRecords,
    required Iterable<String> diagnostics,
  }) : diagnostics = List.unmodifiable(diagnostics),
       assert(backupId.isNotEmpty),
       assert(restoredRecords >= 0);

  final String backupId;
  final CloudRestoreStatus status;
  final int restoredRecords;
  final List<String> diagnostics;
}

final class CloudExportArtifact {
  CloudExportArtifact({
    required this.ownerId,
    required this.format,
    required this.checksum,
    required Map<String, Object?> payload,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc(),
       payload = UnmodifiableMapView(Map<String, Object?>.of(payload));

  final String ownerId;
  final String format;
  final String checksum;
  final DateTime createdAt;
  final Map<String, Object?> payload;
}

final class CloudSchemaAgreement {
  const CloudSchemaAgreement({
    required this.localVersion,
    required this.remoteVersion,
    required this.negotiatedVersion,
    required this.compatible,
  });

  final int localVersion;
  final int remoteVersion;
  final int negotiatedVersion;
  final bool compatible;
}

final class CloudAuditEvent {
  CloudAuditEvent({
    required this.eventId,
    required this.category,
    required this.message,
    required this.severity,
    required DateTime occurredAt,
    required Map<String, Object?> redactedMetadata,
  }) : occurredAt = occurredAt.toUtc(),
       redactedMetadata = UnmodifiableMapView(Map.of(redactedMetadata));

  final String eventId;
  final String category;
  final String message;
  final CloudAuditSeverity severity;
  final DateTime occurredAt;
  final Map<String, Object?> redactedMetadata;
}

final class ProductCloudState {
  ProductCloudState({
    required this.availability,
    required this.accountStatus,
    required this.pendingOperations,
    required this.deadLetters,
    required this.conflicts,
    required this.trustedDevices,
    required DateTime? lastSuccessfulSyncAt,
    required Iterable<String> messages,
  }) : lastSuccessfulSyncAt = lastSuccessfulSyncAt?.toUtc(),
       messages = List.unmodifiable(messages);

  final CloudPlatformAvailability availability;
  final CloudAccountStatus accountStatus;
  final int pendingOperations;
  final int deadLetters;
  final int conflicts;
  final int trustedDevices;
  final DateTime? lastSuccessfulSyncAt;
  final List<String> messages;
}
