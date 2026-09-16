part of 'connected_health_card.dart';

@visibleForTesting
ConnectedHealthSnapshot dashboardWatchSnapshot(
  ConnectedHealthSnapshot snapshot,
  FitnessDeviceSnapshot fitnessDevices,
) {
  final connected =
      fitnessDevices.status == FitnessDeviceConnectionStatus.connected &&
      fitnessDevices.connectedDeviceId?.trim().isNotEmpty == true;
  if (!connected) return snapshot;

  ConnectedHealthSignalView? latestHeartRate;
  for (final packet in fitnessDevices.measurements) {
    if (packet['kind'] != 'heart_rate' || packet['unit'] != 'bpm') continue;
    final value = packet['value'];
    final observedAt = DateTime.tryParse('${packet['observedAt'] ?? ''}');
    if (value is! num ||
        !value.toDouble().isFinite ||
        observedAt == null ||
        value < BleMeasurementPolicy.supported['heart_rate']!.minimum ||
        value > BleMeasurementPolicy.supported['heart_rate']!.maximum) {
      continue;
    }
    final candidate = ConnectedHealthSignalView(
      key: 'heartRate',
      value: value.toDouble(),
      unit: 'bpm',
      source: 'ble:${fitnessDevices.connectedDeviceId}',
      observedAt: observedAt.toUtc(),
      confidence: 1,
      attributes: const <String, Object?>{
        'transport': 'ble',
        'wearableKind': 'ble_fitness_sensor',
      },
    );
    if (latestHeartRate == null ||
        candidate.observedAt.isAfter(latestHeartRate.observedAt)) {
      latestHeartRate = candidate;
    }
  }
  const bleSource = 'Bluetooth fitness device';
  final baseUsable = liveHealthWatchCanShowMetrics(snapshot);
  final availableSources = <String>{
    if (baseUsable)
      ...snapshot.availableSources.where((source) => source.trim().isNotEmpty),
    bleSource,
  }.toList(growable: false);
  final baseLastSync = baseUsable ? snapshot.lastSyncAt : null;
  final latestSync = latestHeartRate == null
      ? baseLastSync
      : baseLastSync == null || latestHeartRate.observedAt.isAfter(baseLastSync)
      ? latestHeartRate.observedAt
      : baseLastSync;
  return ConnectedHealthSnapshot(
    status: latestHeartRate == null
        ? baseUsable
              ? snapshot.status
              : ConnectedHealthStatus.ready
        : ConnectedHealthStatus.synchronized,
    platformSource:
        baseUsable && snapshot.platformSource?.trim().isNotEmpty == true
        ? snapshot.platformSource
        : bleSource,
    availableSources: availableSources,
    signals: <ConnectedHealthSignalView>[
      if (baseUsable) ...snapshot.signals,
      ?latestHeartRate,
    ],
    importedCount: baseUsable ? snapshot.importedCount : 0,
    lastSyncAt: latestSync,
    failureCode: null,
    availabilityStatus: null,
    deviceVerified: true,
    stepHistory: baseUsable
        ? snapshot.stepHistory
        : const <ConnectedHealthSignalView>[],
  );
}
