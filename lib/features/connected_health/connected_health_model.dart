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
    this.attributes = const <String, Object?>{},
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
        attributes: Map<String, Object?>.unmodifiable(signal.attributes),
      );

  final String key;
  final double value;
  final String unit;
  final String source;
  final DateTime observedAt;
  final double confidence;
  final Map<String, Object?> attributes;
}

bool connectedHealthSignalHasWearableProvenance(
  ConnectedHealthSignalView signal,
) {
  final explicitKind = signal.attributes['wearableKind']
      ?.toString()
      .trim()
      .toLowerCase();
  if (explicitKind == 'apple_watch' ||
      explicitKind == 'wear_os_watch' ||
      explicitKind == 'watch' ||
      explicitKind == 'ble_fitness_sensor') {
    return true;
  }
  // Backward-compatible evidence for records imported before native bridges
  // started attaching an explicit wearable kind.
  final source = signal.source.trim().toLowerCase();
  return source.contains('watch') || source.contains('wearable');
}

bool connectedHealthSnapshotHasWearableEvidence(
  ConnectedHealthSnapshot snapshot,
) =>
    snapshot.signals.any(connectedHealthSignalHasWearableProvenance) ||
    snapshot.stepHistory.any(connectedHealthSignalHasWearableProvenance);

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
    this.isBusy = false,
    this.stepHistory = const <ConnectedHealthSignalView>[],
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
      deviceVerified = false,
      isBusy = false,
      stepHistory = const <ConnectedHealthSignalView>[];

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

  /// Keeps the last usable snapshot rendered while a native operation is in
  /// flight. This prevents permission/sync actions from replacing the whole
  /// page with a blank loading state and makes the action's progress explicit.
  final bool isBusy;

  /// Daily step totals imported from the connected source. [signals] remains
  /// the latest representative snapshot for the live card; this separate
  /// history is what powers the dashboard trend.
  final List<ConnectedHealthSignalView> stepHistory;

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
    bool? isBusy,
    List<ConnectedHealthSignalView>? stepHistory,
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
    isBusy: isBusy ?? this.isBusy,
    stepHistory: stepHistory ?? this.stepHistory,
  );
}

/// Returns one value for each of the last 30 local calendar days.
///
/// The dashboard chart consumes these totals as bars; it is not a Cartesian
/// line chart. Missing days are represented by zero so the time axis remains
/// honest and stable.
List<double> connectedHealthStepTrendValues(
  ConnectedHealthSnapshot? snapshot,
  DateTime now,
) {
  final totals = connectedHealthDailyStepTotals(snapshot, now);
  final local = now.toLocal();
  return List<double>.generate(
    30,
    (index) =>
        totals[DateTime(local.year, local.month, local.day - 29 + index)] ?? 0,
    growable: false,
  );
}

/// Missing data is absent, not zero. Only chart bars may fill a missing day
/// with zero; the Today value must come from an actual record for today.
Map<DateTime, double> connectedHealthDailyStepTotals(
  ConnectedHealthSnapshot? snapshot,
  DateTime now,
) {
  if (snapshot == null ||
      const {
        ConnectedHealthStatus.unavailable,
        ConnectedHealthStatus.permissionRequired,
        ConnectedHealthStatus.permissionDenied,
        ConnectedHealthStatus.authorizationRequested,
      }.contains(snapshot.status)) {
    return const {};
  }
  final source = snapshot.stepHistory.isNotEmpty
      ? snapshot.stepHistory
      : snapshot.signals;
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final first = DateTime(local.year, local.month, local.day - 29);
  final totals = <DateTime, double>{};
  for (final signal in source) {
    if (signal.key != 'steps' || signal.unit != 'count') continue;
    if (!signal.value.isFinite || signal.value < 0) continue;
    final observed = signal.observedAt.toLocal();
    final day = DateTime(observed.year, observed.month, observed.day);
    if (day.isBefore(first) || day.isAfter(today)) continue;
    totals.update(
      day,
      (current) => current + signal.value,
      ifAbsent: () => signal.value,
    );
  }
  // Older snapshots may have history ending yesterday but a current daily
  // total in signals. Fill only missing days; never count the same native
  // total twice when it appears in both projections.
  if (snapshot.stepHistory.isNotEmpty) {
    for (final signal in snapshot.signals) {
      if (signal.key != 'steps' ||
          signal.unit != 'count' ||
          !signal.value.isFinite ||
          signal.value < 0) {
        continue;
      }
      final observed = signal.observedAt.toLocal();
      final day = DateTime(observed.year, observed.month, observed.day);
      if (day.isBefore(first) || day.isAfter(today)) continue;
      totals.putIfAbsent(day, () => signal.value);
    }
  }
  return Map.unmodifiable(totals);
}
