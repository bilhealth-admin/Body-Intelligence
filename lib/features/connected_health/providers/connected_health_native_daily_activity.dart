part of 'connected_health_provider.dart';

Future<ConnectedHealthSnapshot> _loadNativeDailyActivity(
  NativeConnectedHealthGateway gateway, {
  bool cachedPreflightOnly = false,
  void Function(ConnectedHealthSnapshot snapshot)? onVerifiedSnapshot,
}) async {
  // Capture before availability/permission/consent awaits: cancellation during
  // preflight must not be mistaken for the starting generation of a new read.
  final generation = gateway._foregroundReadGeneration;
  bool current() =>
      gateway._store.isOwnerCurrent &&
      generation == gateway._foregroundReadGeneration;
  if (!gateway._store.isOwnerCurrent) {
    return const ConnectedHealthSnapshot.unavailable();
  }
  final cached = cachedPreflightOnly && gateway._isIos
      ? await gateway.loadCachedSnapshot()
      : await gateway.load();
  ConnectedHealthSnapshot abandoned() => gateway._store.isOwnerCurrent
      ? cached
      : const ConnectedHealthSnapshot.unavailable();
  if (!current()) return abandoned();
  final source = gateway._source;
  final bridge = gateway._bridge;
  if (source == null ||
      gateway._capability?.available != true ||
      bridge is! NativeHealthDailyTotalsBridge) {
    return cached;
  }
  final consent = await gateway._store.get('connected_health_consent', source);
  if (!current()) return abandoned();
  if (consent?['readRequested'] != true) return cached;
  try {
    final now = gateway._foregroundNow();
    var failed = false;
    Future<List<NativeHealthRecord>> activityRead() async {
      try {
        return await (bridge as NativeHealthDailyTotalsBridge)
            .readDailyTotals(asOf: now)
            .timeout(const Duration(seconds: 8));
      } on Object {
        failed = true;
        return const [];
      }
    }

    Future<List<NativeHealthRecord>> latestRead() async {
      if (!gateway._isIos || bridge is! NativeHealthLatestSignalsBridge) {
        return const [];
      }
      final latest = bridge as NativeHealthLatestSignalsBridge;
      try {
        return await latest
            .readLatestSignals(asOf: now)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () async {
                await latest.cancelLatestSignals().timeout(
                  const Duration(seconds: 1),
                );
                throw TimeoutException('Recent HealthKit reading timed out.');
              },
            );
      } on Object {
        failed = true;
        return const [];
      }
    }

    // Neither snapshot waits for the historical importer or changes its anchor.
    final reads = await Future.wait([activityRead(), latestRead()]);
    if (!current()) return abandoned();
    final activity = nativeDailyActivitySignals(reads[0], now);
    final tombstones = await gateway._loadTombstones();
    final sleepWindowStart = _connectedNoonAtOrBefore(
      now.subtract(const Duration(hours: 72)),
    );
    DateTime? reportedSleepWindowStart;
    var sleepCoverageValid = true;
    for (final row in reads[1].where((r) => r.type == HealthDataType.sleep)) {
      final reported = DateTime.tryParse(
        row.attributes['latestSleepWindowStart']?.toString() ?? '',
      );
      if (reported == null ||
          reported.isAfter(now) ||
          (reportedSleepWindowStart != null &&
              !reportedSleepWindowStart.isAtSameMomentAs(reported))) {
        sleepCoverageValid = false;
        failed = true;
      } else {
        reportedSleepWindowStart = reported;
      }
    }
    final latestRaw = <GlobalHealthSignal>[];
    for (final row in reads[1]) {
      if (row.providerId != bridge.id ||
          row.deleted ||
          row.sourceId.trim().isEmpty ||
          !row.confidence.isFinite ||
          row.confidence <= 0 ||
          row.observedAt.isAfter(now)) {
        continue;
      }
      final isSleep = row.type == HealthDataType.sleep;
      if (!isSleep &&
          row.type != HealthDataType.heartRate &&
          row.type != HealthDataType.restingHeartRate) {
        continue;
      }
      if (!isSleep &&
          now.difference(row.observedAt) > const Duration(minutes: 30)) {
        continue;
      }
      if (isSleep) {
        if (!sleepCoverageValid || reportedSleepWindowStart == null) continue;
        final end = DateTime.tryParse(
          row.attributes['endedAt']?.toString() ?? '',
        );
        if (!const {
              'asleepUnspecified',
              'core',
              'deep',
              'rem',
            }.contains(row.attributes['sleepStage']) ||
            end == null ||
            !end.isAfter(row.observedAt) ||
            end.isAfter(now)) {
          continue;
        }
        // A source/night is authoritative only when its entire noon bucket
        // was queried. Include a stage that straddles the lower bound; reject
        // a truncated boundary night instead of replacing a complete cache.
        final nightStart = _connectedSleepNightStart(end);
        if (nightStart.isBefore(sleepWindowStart) ||
            nightStart.isBefore(reportedSleepWindowStart)) {
          continue;
        }
      }
      final signal = gateway._appleHealthIntegration.normalizeRecord(row);
      if (signal != null &&
          !await gateway._isTombstoned(signal, tombstones: tombstones)) {
        latestRaw.add(signal);
      }
    }
    if (!current()) return abandoned();
    final latestSignals = aggregateConnectedSleepSignals(latestRaw);
    final keys = {
      'steps',
      'distance',
      'activeEnergy',
      ...latestSignals.map((s) => s.key),
    };
    // A daily aggregate read is an optimization, not an authoritative
    // deletion signal. HealthKit/Health Connect can briefly return an empty
    // or partial result while its store is refreshing. Keep the last
    // confirmed value for every metric that was not returned this time.
    final freshSignals = gateway._selectRepresentativeSignals([
      ...activity,
      ...latestSignals,
    ]);
    final retained = await gateway._retainedProjection(
      'signals',
      tombstones: tombstones,
    );
    for (var i = 0; i < freshSignals.length; i++) {
      final fresh = freshSignals[i];
      // OS daily totals replace the retained activity projection, including
      // revisions with an unchanged timestamp. Conflict reuse belongs only
      // to the separately queried recent heart/sleep measurements.
      if (!const {
        'heartRate',
        'restingHeartRate',
        'sleep',
      }.contains(fresh.key)) {
        continue;
      }
      for (final old in retained.where((s) => s.key == fresh.key)) {
        // A complete recent sleep snapshot replaces an earlier partial stage
        // projection of that same source/night. A partial import can start
        // later because it has not reached the night's earlier stages yet.
        if (fresh.key == 'sleep' &&
            _connectedSleepNightKey(fresh) != null &&
            _connectedSleepNightKey(old) == _connectedSleepNightKey(fresh)) {
          continue;
        }
        freshSignals[i] = HealthSignalConflictResolver.prefer(
          old,
          freshSignals[i],
        );
      }
    }
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
    final freshNights = latestSignals
        .map(_connectedSleepNightKey)
        .whereType<String>()
        .toSet();
    final retainedHistory = await gateway._retainedProjection('signalHistory');
    final energyHistory = projectConnectedDailyHistory(
      ConnectedDailyHistoryInput(
        // A latest heart measurement is not a complete day's sample mean.
        // Keep existing HR history until the anchored importer reconciles it.
        samples: latestSignals.where((s) => s.key == 'sleep').toList(),
        nativeTotals: activity,
        retained: retainedHistory
            .where((s) => !freshNights.contains(_connectedSleepNightKey(s)))
            .toList(),
        asOf: now,
      ),
    );
    final signalHistory = energyHistory
        .map(ConnectedHealthSignalView.fromSignal)
        .toList(growable: false);
    final stored = await gateway._store.get('connected_health_ui', 'snapshot');
    final storedSignals = [
      for (final raw in stored?['signals'] as List<Object?>? ?? const [])
        if (raw is Map) raw,
    ];
    if (!current()) return abandoned();
    final latestConsent = await gateway._store.get(
      'connected_health_consent',
      source,
    );
    if (latestConsent?['readRequested'] != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    // Retain native identities for the later full reconciliation, without
    // advancing health_anchor or pretending this is a historical import.
    for (final (index, signal) in latestRaw.indexed) {
      if (!current()) return abandoned();
      if (index % 8 == 0) await Future<void>.delayed(Duration.zero);
      if (!current()) return abandoned();
      if (await gateway._store.get('health_signals', signal.identity) == null) {
        await gateway._store.put(
          'health_signals',
          signal.identity,
          signal.toMap(),
        );
      }
    }
    if (!current()) return abandoned();
    await gateway._store.put('connected_health_ui', 'snapshot', {
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
      'signalHistory': energyHistory.map((signal) => signal.toMap()).toList(),
    });
    final snapshot = cached.copyWith(
      status: failed
          ? ConnectedHealthStatus.degraded
          : signals.isEmpty && gateway._isIos
          ? ConnectedHealthStatus.authorizationRequested
          : ConnectedHealthStatus.synchronized,
      signals: signals,
      stepHistory: stepHistory,
      signalHistory: signalHistory,
      deviceVerified:
          cached.deviceVerified ||
          activity.any(gateway._isEvidenceFromNativeBridge) ||
          latestSignals.any(gateway._isEvidenceFromNativeBridge),
      lastSyncAt: now,
      failureCode: failed
          ? 'daily_activity_refresh_failed_cache_preserved'
          : null,
      clearFailure: !failed,
    );
    if (!current()) return abandoned();
    if (freshSignals.isNotEmpty) onVerifiedSnapshot?.call(snapshot);
    return snapshot;
  } on Object {
    if (!gateway._store.isOwnerCurrent) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    return cached.copyWith(
      status: ConnectedHealthStatus.degraded,
      failureCode: 'daily_activity_refresh_failed_cache_preserved',
    );
  }
}
