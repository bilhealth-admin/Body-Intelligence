part of 'connected_health_provider.dart';

extension _NativeConnectedHealthGatewayHelpers on NativeConnectedHealthGateway {
  Future<List<GlobalHealthSignal>> _retainedProjection(
    String field, {
    Set<String>? tombstones,
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
  Future<Set<String>> _loadTombstones() async {
    final rows = await _flows.store.list('health_tombstones');
    return <String>{
      for (final row in rows)
        if (row['provider'] is String && row['recordId'] is String)
          '${row['provider']}:${row['recordId']}',
    };
  }

  Future<bool> _isTombstoned(
    GlobalHealthSignal signal, {
    Set<String>? tombstones,
  }) async {
    final deletedIds = tombstones ?? await _loadTombstones();
    final provider = signal.provenance.providerId;
    if (deletedIds.contains('$provider:${signal.provenance.recordId}')) {
      return true;
    }
    final parent = signal.attributes['parentRecordId'];
    if (parent is String && deletedIds.contains('$provider:$parent')) {
      return true;
    }
    final sourceSessionIds = signal.attributes['sourceSessionIds'];
    return sourceSessionIds is List &&
        sourceSessionIds.whereType<String>().any(
          (id) => deletedIds.contains('$provider:$id'),
        );
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
        (current) => HealthSignalConflictResolver.prefer(current, signal),
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
}
