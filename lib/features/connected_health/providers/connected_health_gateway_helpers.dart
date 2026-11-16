part of 'connected_health_provider.dart';

abstract interface class ConnectedHealthGateway {
  Future<ConnectedHealthSnapshot> load();
  Future<ConnectedHealthSnapshot> synchronize();
  Future<ConnectedHealthSnapshot> requestPermissions();
  Future<ConnectedHealthSnapshot> requestWeightWritePermission();
  Future<ConnectedHealthSnapshot> revokePermissions();
  Future<void> openSystemSettings();
}

/// Bounded activity totals and recent iOS heart/sleep measurements. No
/// permission prompts, historical import, anchor reset, or remote transfer.
abstract interface class ConnectedHealthDailyActivityGateway {
  Future<ConnectedHealthSnapshot> loadDailyActivity();
}

/// Optional iOS progress: verified recent readings, not a completed backfill.
abstract interface class ConnectedHealthForegroundSyncGateway {
  Future<ConnectedHealthSnapshot> synchronizeWithForeground(
    void Function(ConnectedHealthSnapshot snapshot) onForeground,
  );
}

/// Local, consented native evidence only; never waits for OS status or reads.
abstract interface class ConnectedHealthCachedSnapshotGateway {
  Future<ConnectedHealthSnapshot> loadCachedSnapshot();
}

/// An initial native sheet is permitted after the user's setup completes.
/// No repeat sheet, settings redirect, or silent grant is inferred here.
abstract interface class ConnectedHealthStartupPermissionGateway {
  Future<ConnectedHealthSnapshot?> requestStartupPermissions();
}

/// Implemented only by gateways that can stop an active native read.  The
/// iOS controller uses this after a foreground deadline or app backgrounding;
/// Android and Bluetooth flows are intentionally not affected.
abstract interface class ConnectedHealthCancellableSyncGateway {
  Future<void> cancelSynchronization();
}

extension _NativeConnectedHealthGatewayHelpers on NativeConnectedHealthGateway {
  Future<ConnectedHealthSnapshot> _loadSnapshot({
    required bool cachedOnly,
  }) async {
    if (!_store.isOwnerCurrent) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    final source = _source;
    final capability = _capability;
    if (source == null || capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }

    try {
      final availability =
          !cachedOnly && _bridge is NativeHealthCapabilityBridge
          ? await (_bridge as NativeHealthCapabilityBridge)
                .availability()
                .timeout(const Duration(seconds: 8))
          : const <String, Object?>{'available': true};
      if (availability['available'] != true) {
        final status = availability['status']?.toString();
        return ConnectedHealthSnapshot(
          status: status == '2'
              ? ConnectedHealthStatus.updateRequired
              : ConnectedHealthStatus.unavailable,
          platformSource: source,
          availableSources: const <String>[],
          signals: const <ConnectedHealthSignalView>[],
          importedCount: 0,
          lastSyncAt: null,
          failureCode: 'native_health_unavailable',
          availabilityStatus: status,
        );
      }
      final permissions = cachedOnly
          ? const <String, bool>{}
          : await _bridge.permissions().timeout(const Duration(seconds: 8));
      final consentState = await _store.get('connected_health_consent', source);
      if (cachedOnly && consentState?['readRequested'] != true) {
        return const ConnectedHealthSnapshot.unavailable();
      }
      final stored = await _store.get('connected_health_ui', 'snapshot');
      final tombstones = await _loadTombstones();
      final signals = <ConnectedHealthSignalView>[];
      final stepHistory = <ConnectedHealthSignalView>[];
      final retainedSignalMaps = <Map<String, Object?>>[];
      final retainedStepHistoryMaps = <Map<String, Object?>>[];
      final retainedSignalHistoryMaps = <Map<String, Object?>>[];
      var hasVerifiedNativeEvidence = false;
      var removedOutOfScopeSignal = false;
      final readTypes = connectedHealthReadTypesForPlatform(
        defaultTargetPlatform,
      ).map((type) => type.name).toSet();
      for (final raw in stored?['signals'] as List<Object?>? ?? const []) {
        final signal = GlobalHealthSignal.fromMap(
          Map<String, Object?>.from(raw! as Map),
        );
        // Old preview/foreign-provider cache rows are not HealthKit evidence.
        // Ignore them for this source without deleting the underlying history.
        if (!_isEvidenceFromNativeBridge(signal)) continue;
        if (signal.deleted ||
            !readTypes.contains(signal.key) ||
            await _isTombstoned(signal, tombstones: tombstones)) {
          removedOutOfScopeSignal = true;
          continue;
        }
        retainedSignalMaps.add(signal.toMap());
        signals.add(ConnectedHealthSignalView.fromSignal(signal));
        hasVerifiedNativeEvidence =
            hasVerifiedNativeEvidence || _isEvidenceFromNativeBridge(signal);
      }
      for (final raw in stored?['stepHistory'] as List<Object?>? ?? const []) {
        if (raw is! Map) continue;
        try {
          final signal = GlobalHealthSignal.fromMap(
            Map<String, Object?>.from(raw),
          );
          if (signal.key != 'steps' ||
              !_isEvidenceFromNativeBridge(signal) ||
              signal.deleted ||
              await _isTombstoned(signal, tombstones: tombstones)) {
            continue;
          }
          retainedStepHistoryMaps.add(signal.toMap());
          stepHistory.add(ConnectedHealthSignalView.fromSignal(signal));
          hasVerifiedNativeEvidence = true;
        } on Object {
          // A corrupt projection must not hide the latest valid snapshot.
        }
      }
      for (final raw
          in stored?['signalHistory'] as List<Object?>? ?? const []) {
        if (raw is! Map) continue;
        try {
          final signal = GlobalHealthSignal.fromMap(
            Map<String, Object?>.from(raw),
          );
          if (!const {
                'heartRate',
                'restingHeartRate',
                'sleep',
                'activeEnergy',
              }.contains(signal.key) ||
              !_isEvidenceFromNativeBridge(signal) ||
              signal.deleted ||
              await _isTombstoned(signal, tombstones: tombstones)) {
            continue;
          }
          retainedSignalHistoryMaps.add(signal.toMap());
          hasVerifiedNativeEvidence = true;
        } on Object {
          // One malformed history row must not hide the remaining records.
        }
      }
      if (stepHistory.isEmpty) {
        stepHistory.addAll(signals.where((signal) => signal.key == 'steps'));
      }
      if (!cachedOnly && removedOutOfScopeSignal && stored != null) {
        await _store.put('connected_health_ui', 'snapshot', <String, Object?>{
          ...stored,
          'signals': retainedSignalMaps,
          'stepHistory': retainedStepHistoryMaps,
          'signalHistory': retainedSignalHistoryMaps,
          'importedCount': retainedSignalMaps.length,
        });
      }
      final explicitlyRequested = consentState?['readRequested'] == true;
      // HealthKit deliberately does not reveal whether read access was
      // granted or denied. authorizationStatus(for:) reports sharing/write
      // status, so an iOS request must remain indeterminate until records are
      // actually returned. Never present it as granted from that snapshot.
      final granted =
          explicitlyRequested &&
          !_isIos &&
          permissions.values.any((value) => value);
      final lastSyncRaw = stored?['lastSyncAt'] as String?;
      return ConnectedHealthSnapshot(
        status: cachedOnly && hasVerifiedNativeEvidence
            ? ConnectedHealthStatus.degraded
            : _isIos && explicitlyRequested
            ? (signals.isNotEmpty || stepHistory.isNotEmpty
                  ? ConnectedHealthStatus.synchronized
                  : ConnectedHealthStatus.authorizationRequested)
            : granted
            ? (lastSyncRaw == null
                  ? ConnectedHealthStatus.ready
                  : ConnectedHealthStatus.synchronized)
            : ConnectedHealthStatus.permissionRequired,
        platformSource: source,
        availableSources: <String>[source],
        signals: signals,
        importedCount: removedOutOfScopeSignal
            ? signals.length
            : stored?['importedCount'] as int? ?? signals.length,
        lastSyncAt: lastSyncRaw == null
            ? null
            : DateTime.parse(lastSyncRaw).toLocal(),
        failureCode: cachedOnly && hasVerifiedNativeEvidence
            ? 'health_cached_snapshot_pending_refresh'
            : null,
        availabilityStatus: availability['status']?.toString(),
        deviceVerified: hasVerifiedNativeEvidence,
        stepHistory: List<ConnectedHealthSignalView>.unmodifiable(stepHistory),
        signalHistory: projectConnectedDailyHistory(
          ConnectedDailyHistoryInput(
            samples: [
              for (final row in retainedSignalHistoryMaps)
                GlobalHealthSignal.fromMap(row),
            ],
            asOf: DateTime.now(),
          ),
        ).map(ConnectedHealthSignalView.fromSignal).toList(growable: false),
      );
    } catch (_) {
      if (!_store.isOwnerCurrent) {
        return const ConnectedHealthSnapshot.unavailable();
      }
      if (!cachedOnly) {
        return (await loadCachedSnapshot()).copyWith(
          status: ConnectedHealthStatus.degraded,
          failureCode: 'native_health_status_unavailable',
        );
      }
      return ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.degraded,
        platformSource: source,
        availableSources: <String>[source],
        signals: const <ConnectedHealthSignalView>[],
        importedCount: 0,
        lastSyncAt: null,
        failureCode: 'native_health_status_unavailable',
      );
    }
  }

  Future<List<GlobalHealthSignal>> _retainedProjection(
    String field, {
    ConnectedHealthTombstoneIndex? tombstones,
  }) async {
    final consent = await _store.get('connected_health_consent', _source!);
    if (consent?['readRequested'] != true) return const [];
    final stored = await _store.get('connected_health_ui', 'snapshot');
    final allowed = connectedHealthReadTypesForPlatform(
      defaultTargetPlatform,
    ).map((type) => type.name).toSet();
    final deletedIds = tombstones ?? await _loadTombstones();
    final result = <GlobalHealthSignal>[];
    for (final raw in stored?[field] as List<Object?>? ?? const []) {
      if (raw is! Map) continue;
      try {
        final signal = GlobalHealthSignal.fromMap(
          Map<String, Object?>.from(raw),
        );
        if (!signal.deleted &&
            allowed.contains(signal.key) &&
            _isEvidenceFromNativeBridge(signal) &&
            !await _isTombstoned(signal, tombstones: deletedIds)) {
          result.add(signal);
        }
      } on Object {
        // A malformed cache row is not permission to invent a reading.
      }
    }
    return result;
  }

  NativeHealthBridge get _bridge =>
      _isIos ? _flows.appleHealth.bridge : _flows.healthConnect.bridge;

  bool _isEvidenceFromNativeBridge(GlobalHealthSignal signal) =>
      signal.provenance.providerId == _bridge.id;

  // Snapshot tombstones once per projection, not once per contributing sample.
  // A daily mean may represent thousands of readings. Keep deletions honored
  // without introducing thousands of serial SQLite calls on dashboard resume.
  Future<ConnectedHealthTombstoneIndex> _loadTombstones() =>
      ConnectedHealthTombstoneIndex.load(_store);

  Future<bool> _isTombstoned(
    GlobalHealthSignal signal, {
    ConnectedHealthTombstoneIndex? tombstones,
  }) async {
    final index = tombstones ?? await _loadTombstones();
    final provider = signal.provenance.providerId;
    final parent = signal.attributes['parentRecordId'];
    final sourceSessionIds = signal.attributes['sourceSessionIds'];
    return index.containsAny(<String>{
      '$provider:${signal.provenance.recordId}',
      if (parent is String) '$provider:$parent',
      if (sourceSessionIds is List)
        for (final id in sourceSessionIds.whereType<String>()) '$provider:$id',
    });
  }

  List<GlobalHealthSignal> _selectRepresentativeSignals(
    List<GlobalHealthSignal> records,
  ) {
    const priority = <String>[
      'steps',
      'sleep',
      'heartRate',
      'restingHeartRate',
      'activeEnergy',
      'weight',
    ];
    final byKey = <String, GlobalHealthSignal>{};
    for (final signal in records) {
      if (BilHealthScope.excludesKey(signal.key)) continue;
      byKey.update(
        signal.key,
        (current) => _preferRepresentativeSignal(current, signal),
        ifAbsent: () => signal,
      );
    }
    final selected = <GlobalHealthSignal>[];
    for (final key in priority) {
      final signal = byKey[key];
      if (signal != null) selected.add(signal);
    }
    for (final entry in byKey.entries) {
      if (!priority.contains(entry.key)) selected.add(entry.value);
    }
    return selected.take(8).toList(growable: false);
  }

  GlobalHealthSignal _preferRepresentativeSignal(
    GlobalHealthSignal current,
    GlobalHealthSignal candidate,
  ) {
    // Refresh only metadata for the exact same measured sleep projection.
    // Legacy cached projections dropped native device evidence. A timestamp
    // tie must not keep that incomplete cache over the canonical store's
    // freshly reconstructed attributes. Different identities, device/source
    // provenance, confidence, units or measurements retain the existing rule.
    if (current.key == 'sleep' &&
        current.identity == candidate.identity &&
        current.canonicalValue == candidate.canonicalValue &&
        current.canonicalUnit == candidate.canonicalUnit &&
        current.deleted == candidate.deleted &&
        current.provenance.sourceId == candidate.provenance.sourceId &&
        current.provenance.deviceId == candidate.provenance.deviceId &&
        current.provenance.timeZoneId == candidate.provenance.timeZoneId &&
        current.provenance.observedAt == candidate.provenance.observedAt &&
        current.provenance.confidence == candidate.provenance.confidence) {
      return candidate;
    }
    return HealthSignalConflictResolver.prefer(current, candidate);
  }
}
