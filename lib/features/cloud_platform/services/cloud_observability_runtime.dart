import '../domain/cloud_operational_models.dart';
import '../domain/cloud_sync_models.dart';
import 'cloud_durable_ports.dart';

final class CloudObservabilityRuntime {
  const CloudObservabilityRuntime({required this.store});
  final DurableCloudStore store;

  Future<void> record({
    required String id,
    required String category,
    required String message,
    CloudAuditSeverity severity = CloudAuditSeverity.info,
    Map<String, Object?> metadata = const {},
  }) => store.appendAudit(
    CloudAuditEvent(
      eventId: id,
      category: category,
      message: message,
      severity: severity,
      occurredAt: DateTime.now().toUtc(),
      redactedMetadata: _redact(metadata),
    ),
  );

  Future<ProductCloudState> productState({
    required String ownerId,
    required CloudPlatformAvailability availability,
    DateTime? lastSync,
  }) async {
    final account = await store.readAccount(ownerId);
    final devices = await store.readDevices(ownerId);
    return ProductCloudState(
      availability: availability,
      accountStatus: account?.status ?? CloudAccountStatus.signedOut,
      pendingOperations: await store.pendingCount(),
      deadLetters: await store.deadLetterCount(),
      conflicts: await store.conflictCount(),
      trustedDevices: devices.where((d) => d.active).length,
      lastSuccessfulSyncAt: lastSync,
      messages: const [],
    );
  }

  static Map<String, Object?> _redact(Map<String, Object?> source) {
    final redacted = <String, Object?>{};
    for (final entry in source.entries) {
      final key = entry.key.toLowerCase();
      redacted[entry.key] =
          key.contains('token') ||
              key.contains('email') ||
              key.contains('secret')
          ? '[REDACTED]'
          : entry.value;
    }
    return redacted;
  }
}
