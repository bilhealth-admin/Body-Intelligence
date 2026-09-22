part of 'connected_health_provider.dart';

extension _NativeConnectedHealthGatewayHelpers on NativeConnectedHealthGateway {
  Future<List<GlobalHealthSignal>> _retainedProjection(String field) async {
    final consent = await _flows.store.get(
      'connected_health_consent',
      _source!,
    );
    if (consent?['readRequested'] != true) return const [];
    final stored = await _flows.store.get('connected_health_ui', 'snapshot');
    final allowed = connectedHealthReadTypesForPlatform(
      defaultTargetPlatform,
    ).map((type) => type.name).toSet();
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
            !await _isTombstoned(signal)) {
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

  Future<bool> _isTombstoned(GlobalHealthSignal signal) async {
    final recordIds = <String>{signal.provenance.recordId};
    final sourceSessionIds = signal.attributes['sourceSessionIds'];
    if (sourceSessionIds is List) {
      recordIds.addAll(sourceSessionIds.whereType<String>());
    }
    for (final recordId in recordIds) {
      final tombstone = await _flows.store.get(
        'health_tombstones',
        '${signal.provenance.providerId}:$recordId',
      );
      if (tombstone != null) return true;
    }
    return false;
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
