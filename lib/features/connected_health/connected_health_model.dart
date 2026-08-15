import '../global_platform/core/global_platform_core.dart';

enum ConnectedHealthStatus {
  unavailable,
  updateRequired,
  permissionRequired,
  permissionDenied,
  authorizationRequested,
  ready,
  syncing,
  synchronized,
  degraded,
}

final class ConnectedHealthSignalView {
  const ConnectedHealthSignalView({
    required this.key,
    required this.value,
    required this.unit,
    required this.source,
    required this.observedAt,
    required this.confidence,
  });

  factory ConnectedHealthSignalView.fromSignal(GlobalHealthSignal signal) =>
      ConnectedHealthSignalView(
        key: signal.key,
        value: signal.canonicalValue,
        unit: signal.canonicalUnit,
        source: signal.provenance.deviceId?.isNotEmpty == true
            ? signal.provenance.deviceId!
            : signal.provenance.sourceId,
        observedAt: signal.provenance.observedAt,
        confidence: signal.provenance.confidence,
      );

  final String key;
  final double value;
  final String unit;
  final String source;
  final DateTime observedAt;
  final double confidence;
}

final class ConnectedHealthSnapshot {
  const ConnectedHealthSnapshot({
    required this.status,
    required this.platformSource,
    required this.availableSources,
    required this.signals,
    required this.importedCount,
    required this.lastSyncAt,
    required this.failureCode,
    this.availabilityStatus,
    this.deviceVerified = false,
  });

  const ConnectedHealthSnapshot.unavailable()
    : status = ConnectedHealthStatus.unavailable,
      platformSource = null,
      availableSources = const <String>[],
      signals = const <ConnectedHealthSignalView>[],
      importedCount = 0,
      lastSyncAt = null,
      failureCode = null,
      availabilityStatus = null,
      deviceVerified = false;

  final ConnectedHealthStatus status;
  final String? platformSource;
  final List<String> availableSources;
  final List<ConnectedHealthSignalView> signals;
  final int importedCount;
  final DateTime? lastSyncAt;
  final String? failureCode;
  final String? availabilityStatus;

  /// True only after a real native source answered successfully. A mock or
  /// simulator must never set this flag.
  final bool deviceVerified;

  ConnectedHealthSnapshot copyWith({
    ConnectedHealthStatus? status,
    String? platformSource,
    List<String>? availableSources,
    List<ConnectedHealthSignalView>? signals,
    int? importedCount,
    DateTime? lastSyncAt,
    String? failureCode,
    bool clearFailure = false,
    String? availabilityStatus,
    bool? deviceVerified,
  }) => ConnectedHealthSnapshot(
    status: status ?? this.status,
    platformSource: platformSource ?? this.platformSource,
    availableSources: availableSources ?? this.availableSources,
    signals: signals ?? this.signals,
    importedCount: importedCount ?? this.importedCount,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    failureCode: clearFailure ? null : failureCode ?? this.failureCode,
    availabilityStatus: availabilityStatus ?? this.availabilityStatus,
    deviceVerified: deviceVerified ?? this.deviceVerified,
  );
}
