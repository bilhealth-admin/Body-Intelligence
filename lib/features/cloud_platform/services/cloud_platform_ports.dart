import '../domain/cloud_identity_models.dart';
import '../domain/cloud_sync_models.dart';

abstract interface class CloudLocalStore {
  Future<List<CloudSyncOperation>> readPendingOperations({required int limit});
  Future<void> saveOperation(CloudSyncOperation operation);
  Future<void> acknowledgeOperations(Iterable<String> operationIds);
  Future<CloudRecordEnvelope?> readRecord(String stableKey);
  Future<void> applyRemoteRecord(CloudRecordEnvelope record);
  Future<String?> readCursor();
  Future<void> saveCursor(String? cursor);
  Future<int> pendingCount();
}

abstract interface class CloudTransport {
  Future<CloudSyncBatchResult> synchronize({
    required String ownerId,
    required String deviceId,
    required CloudSession session,
    required List<CloudSyncOperation> operations,
    required String? cursor,
  });
}

abstract interface class CloudPayloadCipher {
  bool get isAvailable;
  Map<String, Object?> encrypt(Map<String, Object?> cleartext);
  Map<String, Object?> decrypt(Map<String, Object?> ciphertext);
}

abstract interface class CloudConnectivity {
  bool get isOnline;
}

abstract interface class CloudClock {
  DateTime now();
}

final class SystemCloudClock implements CloudClock {
  const SystemCloudClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
