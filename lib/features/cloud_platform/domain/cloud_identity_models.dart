import 'dart:collection';

final class CloudDeviceRegistration {
  CloudDeviceRegistration({
    required this.deviceId,
    required this.ownerId,
    required this.displayName,
    required DateTime registeredAt,
    DateTime? revokedAt,
  }) : registeredAt = registeredAt.toUtc(),
       revokedAt = revokedAt?.toUtc(),
       assert(deviceId != ''),
       assert(ownerId != ''),
       assert(displayName != '');

  final String deviceId;
  final String ownerId;
  final String displayName;
  final DateTime registeredAt;
  final DateTime? revokedAt;

  bool get active => revokedAt == null;
}

final class CloudSession {
  CloudSession({
    required this.sessionId,
    required this.ownerId,
    required this.deviceId,
    required DateTime issuedAt,
    required DateTime expiresAt,
    DateTime? revokedAt,
  }) : issuedAt = issuedAt.toUtc(),
       expiresAt = expiresAt.toUtc(),
       revokedAt = revokedAt?.toUtc(),
       assert(sessionId != ''),
       assert(ownerId != ''),
       assert(deviceId != ''),
       assert(expiresAt.toUtc().isAfter(issuedAt.toUtc()));

  final String sessionId;
  final String ownerId;
  final String deviceId;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;

  bool isUsableAt(DateTime now) =>
      revokedAt == null && now.toUtc().isBefore(expiresAt);
}

final class CloudBackupManifest {
  CloudBackupManifest({
    required this.backupId,
    required this.ownerId,
    required DateTime createdAt,
    required this.schemaVersion,
    required this.recordCount,
    required this.checksum,
    required Iterable<String> includedEntityKinds,
  }) : createdAt = createdAt.toUtc(),
       includedEntityKinds = List.unmodifiable(includedEntityKinds),
       assert(backupId != ''),
       assert(ownerId != ''),
       assert(schemaVersion > 0),
       assert(recordCount >= 0),
       assert(checksum != '');

  final String backupId;
  final String ownerId;
  final DateTime createdAt;
  final int schemaVersion;
  final int recordCount;
  final String checksum;
  final List<String> includedEntityKinds;
}

final class CloudMonitoringSnapshot {
  CloudMonitoringSnapshot({
    required DateTime capturedAt,
    required this.pendingOperations,
    required this.retryingOperations,
    required this.conflictCount,
    required DateTime? lastSuccessfulSyncAt,
    required Map<String, int> counters,
  }) : capturedAt = capturedAt.toUtc(),
       lastSuccessfulSyncAt = lastSuccessfulSyncAt?.toUtc(),
       counters = UnmodifiableMapView(Map.of(counters)),
       assert(pendingOperations >= 0),
       assert(retryingOperations >= 0),
       assert(conflictCount >= 0);

  final DateTime capturedAt;
  final int pendingOperations;
  final int retryingOperations;
  final int conflictCount;
  final DateTime? lastSuccessfulSyncAt;
  final Map<String, int> counters;
}
