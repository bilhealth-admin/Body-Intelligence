part of 'connected_health_provider.dart';

extension _NativeConnectedHealthGatewayHelpers on NativeConnectedHealthGateway {
  Future<List<GlobalHealthSignal>> _retainedProjection(
    String field, {
    ConnectedHealthTombstoneIndex? tombstones,
  }) async {
    final consent = await _flows.store.get(
      'connected_health_consent',
      _source!,
    );
    if (consent?['readRequested'] != true) return const [];
    final stored = await _flows.store.get('connected_health_ui', 'snapshot');
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
      ConnectedHealthTombstoneIndex.load(_flows.store);

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
