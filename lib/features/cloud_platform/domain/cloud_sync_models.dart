import 'dart:collection';

enum CloudEntityKind {
  profile,
  goal,
  weight,
  measurement,
  nutrition,
  hydration,
  sleep,
  activity,
  decisionMemory,
  intelligenceOutput,
  coach,
  community,
  file,
  settings,
}

enum CloudMutationKind { upsert, delete }

enum CloudSyncDisposition { pending, inFlight, acknowledged, retry, blocked }

enum CloudConflictResolution { localWins, remoteWins, merged, manualReview }

enum CloudPlatformAvailability { localOnly, ready, paused, revoked }

final class CloudRevision {
  CloudRevision({required this.deviceId, required this.sequence})
    : assert(deviceId != ''),
      assert(sequence >= 0);

  final String deviceId;
  final int sequence;

  String get token => '$deviceId:$sequence';
}

final class CloudRecordEnvelope {
  CloudRecordEnvelope({
    required this.entityKind,
    required this.recordId,
    required this.ownerId,
    required this.revision,
    required DateTime updatedAt,
    required Map<String, Object?> payload,
    this.deletedAt,
    this.schemaVersion = 1,
  }) : updatedAt = updatedAt.toUtc(),
       payload = UnmodifiableMapView(Map<String, Object?>.from(payload)),
       assert(recordId != ''),
       assert(ownerId != ''),
       assert(schemaVersion > 0),
       assert(
         deletedAt == null || !deletedAt.toUtc().isAfter(updatedAt.toUtc()),
       );

  final CloudEntityKind entityKind;
  final String recordId;
  final String ownerId;
  final CloudRevision revision;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int schemaVersion;
  final Map<String, Object?> payload;

  bool get isTombstone => deletedAt != null;

  String get stableKey => '${entityKind.name}:$recordId';
}

final class CloudSyncOperation {
  CloudSyncOperation({
    required this.operationId,
    required this.mutation,
    required this.record,
    required DateTime createdAt,
    this.attempt = 0,
    this.disposition = CloudSyncDisposition.pending,
    this.lastError,
  }) : createdAt = createdAt.toUtc(),
       assert(operationId != ''),
       assert(attempt >= 0);

  final String operationId;
  final CloudMutationKind mutation;
  final CloudRecordEnvelope record;
  final DateTime createdAt;
  final int attempt;
  final CloudSyncDisposition disposition;
  final String? lastError;

  CloudSyncOperation copyWith({
    int? attempt,
    CloudSyncDisposition? disposition,
    String? lastError,
  }) => CloudSyncOperation(
    operationId: operationId,
    mutation: mutation,
    record: record,
    createdAt: createdAt,
    attempt: attempt ?? this.attempt,
    disposition: disposition ?? this.disposition,
    lastError: lastError,
  );
}

final class CloudConflict {
  const CloudConflict({
    required this.local,
    required this.remote,
    required this.resolution,
    required this.reason,
    this.merged,
  });

  final CloudRecordEnvelope local;
  final CloudRecordEnvelope remote;
  final CloudConflictResolution resolution;
  final String reason;
  final CloudRecordEnvelope? merged;
}

final class CloudSyncBatchResult {
  CloudSyncBatchResult({
    required Iterable<String> acknowledgedOperationIds,
    required Iterable<CloudRecordEnvelope> remoteRecords,
    required this.serverCursor,
  }) : acknowledgedOperationIds = List.unmodifiable(acknowledgedOperationIds),
       remoteRecords = List.unmodifiable(remoteRecords);

  final List<String> acknowledgedOperationIds;
  final List<CloudRecordEnvelope> remoteRecords;
  final String? serverCursor;
}

final class CloudSyncReport {
  CloudSyncReport({
    required this.startedAt,
    required this.completedAt,
    required this.pushed,
    required this.pulled,
    required this.conflicts,
    required this.pending,
    required this.availability,
    required Iterable<String> diagnostics,
  }) : diagnostics = List.unmodifiable(diagnostics);

  final DateTime startedAt;
  final DateTime completedAt;
  final int pushed;
  final int pulled;
  final int conflicts;
  final int pending;
  final CloudPlatformAvailability availability;
  final List<String> diagnostics;

  bool get completed => availability == CloudPlatformAvailability.ready;
}
