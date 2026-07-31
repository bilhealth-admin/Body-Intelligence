import '../domain/cloud_identity_models.dart';
import '../domain/cloud_operational_models.dart';
import '../domain/cloud_sync_models.dart';

abstract interface class DurableCloudStore {
  Future<void> initialize();
  Future<void> close();

  Future<void> upsertAccount(CloudAccount account);
  Future<CloudAccount?> readAccount(String ownerId);
  Future<void> upsertDevice(CloudDeviceRegistration device);
  Future<List<CloudDeviceRegistration>> readDevices(String ownerId);
  Future<void> revokeDevice(String deviceId, DateTime revokedAt);

  Future<void> saveOperation(
    CloudSyncOperation operation, {
    DateTime? nextAttemptAt,
  });
  Future<List<CloudSyncOperation>> readReadyOperations({
    required DateTime now,
    required int limit,
  });
  Future<void> acknowledgeOperations(Iterable<String> ids);
  Future<void> markRetry(CloudSyncOperation operation, DateTime nextAttemptAt);
  Future<void> moveToDeadLetter(CloudDeadLetter deadLetter);
  Future<List<CloudDeadLetter>> readDeadLetters();

  Future<void> saveInboxRecord(CloudRecordEnvelope record);
  Future<CloudRecordEnvelope?> readInboxRecord(String stableKey);
  Future<List<CloudRecordEnvelope>> readAllRecords(String ownerId);
  Future<void> saveTombstone(CloudRecordEnvelope record);
  Future<List<CloudRecordEnvelope>> readTombstones(String ownerId);
  Future<void> saveConflict(CloudConflictRecord conflict);
  Future<List<CloudConflictRecord>> readConflicts();
  Future<String?> readCursor(String ownerId, String deviceId);
  Future<void> saveCursor(String ownerId, String deviceId, String? cursor);

  Future<bool> hasIdempotencyKey(String key);
  Future<void> saveIdempotencyReceipt(CloudIdempotencyReceipt receipt);
  Future<void> saveBackup(CloudBackupArtifact backup);
  Future<CloudBackupArtifact?> readBackup(String backupId);
  Future<void> replaceOwnerRecords(
    String ownerId,
    Iterable<CloudRecordEnvelope> records,
  );
  Future<void> deleteOwnerData(String ownerId);

  Future<void> appendAudit(CloudAuditEvent event);
  Future<List<CloudAuditEvent>> readAudit({int limit = 100});

  Future<int> pendingCount();
  Future<int> deadLetterCount();
  Future<int> conflictCount();
}

abstract interface class CloudAuthenticationProvider {
  Future<CloudAccount> signUp({required String email, required String secret});
  Future<CloudSession> signIn({
    required String email,
    required String secret,
    required String deviceId,
  });
  Future<void> signOut(String sessionId);
  Future<void> disableAccount(String ownerId);
  Future<void> deleteAccount(String ownerId);
}

abstract interface class CloudFailureInjector {
  void checkpoint(String name);
}

final class NoopCloudFailureInjector implements CloudFailureInjector {
  const NoopCloudFailureInjector();
  @override
  void checkpoint(String name) {}
}
