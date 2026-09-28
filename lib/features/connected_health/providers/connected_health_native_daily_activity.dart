part of 'connected_health_provider.dart';

Future<ConnectedHealthSnapshot> _loadNativeDailyActivity(
  NativeConnectedHealthGateway gateway,
) async {
  final cached = await gateway.load();
  final source = gateway._source;
  final bridge = gateway._bridge;
  if (source == null ||
      gateway._capability?.available != true ||
      bridge is! NativeHealthDailyTotalsBridge) {
    return cached;
  }
  final consent = await gateway._flows.store.get(
    'connected_health_consent',
    source,
  );
  if (consent?['readRequested'] != true) return cached;
  try {
    final now = DateTime.now();
    final activity = nativeDailyActivitySignals(
      await (bridge as NativeHealthDailyTotalsBridge)
          .readDailyTotals(asOf: now)
          .timeout(const Duration(seconds: 8)),
      now,
    );
    const keys = {'steps', 'distance', 'activeEnergy'};
    // A daily aggregate read is an optimization, not an authoritative
    // deletion signal. HealthKit/Health Connect can briefly return an empty
    // or partial result while its store is refreshing. Keep the last
    // confirmed value for every metric that was not returned this time.
    final freshSignals = gateway._selectRepresentativeSignals(activity);
    final freshKeys = freshSignals.map((signal) => signal.key).toSet();
    final signals = <ConnectedHealthSignalView>[
      ...cached.signals.where(
        (signal) =>
            !keys.contains(signal.key) || !freshKeys.contains(signal.key),
      ),
      ...freshSignals.map(ConnectedHealthSignalView.fromSignal),
    ];
    final steps = activity.where((signal) => signal.key == 'steps').toList();
    final stepHistory = steps.isEmpty
        ? cached.stepHistory
        : steps.map(ConnectedHealthSignalView.fromSignal).toList();
    final activeEnergy = activity
        .where((signal) => signal.key == 'activeEnergy')
        .map(ConnectedHealthSignalView.fromSignal)
        .toList();
    final signalHistory = activeEnergy.isEmpty
        ? cached.signalHistory
        : <ConnectedHealthSignalView>[
            ...cached.signalHistory.where(
              (signal) => signal.key != 'activeEnergy',
            ),
            ...activeEnergy,
          ];
    final stored = await gateway._flows.store.get(
      'connected_health_ui',
      'snapshot',
    );
    final storedSignals = [
      for (final raw in stored?['signals'] as List<Object?>? ?? const [])
        if (raw is Map) raw,
    ];
    await gateway._flows.store.put('connected_health_ui', 'snapshot', {
      ...?stored,
      'lastSyncAt': now.toUtc().toIso8601String(),
      'importedCount': cached.importedCount,
      'signals': [
        for (final raw in storedSignals)
          if (!keys.contains(raw['key']) || !freshKeys.contains(raw['key']))
            raw,
        ...freshSignals.map((signal) => signal.toMap()),
      ],
      'stepHistory': steps.isEmpty
          ? (stored?['stepHistory'] as List<Object?>? ?? const <Object?>[])
          : steps.map((signal) => signal.toMap()).toList(),
      'signalHistory': activeEnergy.isEmpty
          ? (stored?['signalHistory'] as List<Object?>? ?? const <Object?>[])
          : [
              for (final raw
                  in stored?['signalHistory'] as List<Object?>? ?? const [])
                if (raw is Map && raw['key'] != 'activeEnergy') raw,
              ...activity
                  .where((signal) => signal.key == 'activeEnergy')
                  .map((signal) => signal.toMap()),
            ],
    });
    return cached.copyWith(
      status: signals.isEmpty && gateway._isIos
          ? ConnectedHealthStatus.authorizationRequested
          : ConnectedHealthStatus.synchronized,
      signals: signals,
      stepHistory: stepHistory,
      signalHistory: signalHistory,
      deviceVerified:
          cached.deviceVerified ||
          activity.any(gateway._isEvidenceFromNativeBridge),
      lastSyncAt: now,
      clearFailure: true,
    );
  } on Object {
    return cached.copyWith(
      status: ConnectedHealthStatus.degraded,
      failureCode: 'daily_activity_refresh_failed_cache_preserved',
    );
  }
}
