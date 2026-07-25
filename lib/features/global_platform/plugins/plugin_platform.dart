import '../core/global_platform_core.dart';

final class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.version,
    required this.minCoreVersion,
    required this.maxCoreVersion,
    required this.capabilities,
    required this.permissions,
    required this.dependencies,
    required this.securityReview,
  });
  final String id, version, minCoreVersion, maxCoreVersion, securityReview;
  final Set<String> capabilities, permissions, dependencies;
}

enum PluginState { registered, active, inactive, failed, uninstalled }

final class PluginRecord {
  const PluginRecord(this.manifest, this.state, {this.failureCode});
  final PluginManifest manifest;
  final PluginState state;
  final String? failureCode;
}

abstract interface class PluginLifecycle {
  String get pluginId;
  Future<void> start();
  Future<void> stop();
  Future<void> migrate(String fromVersion, String toVersion);
}

final class PluginRegistry {
  PluginRegistry({
    required this.store,
    required this.audit,
    required this.coreVersion,
  });
  final GlobalDurableStore store;
  final GlobalAuditSink audit;
  final String coreVersion;
  final Map<String, PluginRecord> _records = <String, PluginRecord>{};
  final Map<String, PluginLifecycle> _lifecycles = <String, PluginLifecycle>{};
  Iterable<PluginRecord> get active =>
      _records.values.where((record) => record.state == PluginState.active);

  bool contains(String id) => _records.containsKey(id);

  void attachLifecycle(PluginLifecycle lifecycle) {
    if (!_records.containsKey(lifecycle.pluginId)) {
      throw StateError('Unknown plugin.');
    }
    _lifecycles[lifecycle.pluginId] = lifecycle;
  }

  Future<void> restore() async {
    for (final row in await store.list('plugins')) {
      final manifest = PluginManifest(
        id: row['id']! as String,
        version: row['version']! as String,
        minCoreVersion: row['minCoreVersion']! as String,
        maxCoreVersion: row['maxCoreVersion']! as String,
        capabilities: Set<String>.from(row['capabilities'] as List<Object?>),
        permissions: Set<String>.from(row['permissions'] as List<Object?>),
        dependencies: Set<String>.from(row['dependencies'] as List<Object?>),
        securityReview: row['securityReview']! as String,
      );
      _records[manifest.id] = PluginRecord(
        manifest,
        PluginState.values.byName(row['state']! as String),
      );
    }
  }

  Future<void> register(
    PluginManifest manifest,
    PluginLifecycle lifecycle,
    DateTime at,
  ) async {
    if (_records.containsKey(manifest.id)) {
      throw StateError('Duplicate plugin.');
    }
    if (_compare(coreVersion, manifest.minCoreVersion) < 0 ||
        _compare(coreVersion, manifest.maxCoreVersion) > 0) {
      throw StateError('Incompatible plugin.');
    }
    if (manifest.securityReview != 'approved') {
      throw StateError('Security review is required.');
    }
    for (final dependency in manifest.dependencies) {
      if (!_records.containsKey(dependency)) {
        throw StateError('Missing dependency $dependency');
      }
    }
    _records[manifest.id] = PluginRecord(manifest, PluginState.registered);
    _lifecycles[manifest.id] = lifecycle;
    await _persist(manifest.id);
    await audit.record(
      GlobalAuditEvent(
        action: 'plugin.registered',
        subjectId: manifest.id,
        at: at,
      ),
    );
  }

  Future<void> activate(String id, DateTime at) async {
    final record = _records[id];
    final lifecycle = _lifecycles[id];
    if (record == null || lifecycle == null) {
      throw StateError('Unknown plugin.');
    }
    try {
      await lifecycle.start();
      _records[id] = PluginRecord(record.manifest, PluginState.active);
    } catch (error) {
      _records[id] = PluginRecord(
        record.manifest,
        PluginState.failed,
        failureCode: error.runtimeType.toString(),
      );
      await _persist(id);
      rethrow;
    }
    await _persist(id);
    await audit.record(
      GlobalAuditEvent(action: 'plugin.activated', subjectId: id, at: at),
    );
  }

  Future<void> deactivate(String id, DateTime at) async {
    final record = _records[id];
    if (record == null) return;
    await _lifecycles[id]?.stop();
    _records[id] = PluginRecord(record.manifest, PluginState.inactive);
    await _persist(id);
    await audit.record(
      GlobalAuditEvent(action: 'plugin.deactivated', subjectId: id, at: at),
    );
  }

  Future<void> uninstall(String id, DateTime at) async {
    if (_records.values.any(
      (record) => record.manifest.dependencies.contains(id),
    )) {
      throw StateError('Plugin has dependents.');
    }
    await deactivate(id, at);
    _records.remove(id);
    _lifecycles.remove(id);
    await store.remove('plugins', id);
    await audit.record(
      GlobalAuditEvent(action: 'plugin.uninstalled', subjectId: id, at: at),
    );
  }

  Future<void> _persist(String id) async {
    final record = _records[id]!;
    await store.put('plugins', id, <String, Object?>{
      'id': record.manifest.id,
      'version': record.manifest.version,
      'minCoreVersion': record.manifest.minCoreVersion,
      'maxCoreVersion': record.manifest.maxCoreVersion,
      'capabilities': record.manifest.capabilities.toList()..sort(),
      'permissions': record.manifest.permissions.toList()..sort(),
      'dependencies': record.manifest.dependencies.toList()..sort(),
      'securityReview': record.manifest.securityReview,
      'state': record.state.name,
      'failureCode': record.failureCode,
    });
  }

  int _compare(String a, String b) {
    final left = a.split('.').map(int.parse).toList();
    final right = b.split('.').map(int.parse).toList();
    for (var index = 0; index < 3; index++) {
      final difference = left[index] - right[index];
      if (difference != 0) return difference;
    }
    return 0;
  }
}

final class BilCoreEvidencePlugin implements PluginLifecycle {
  BilCoreEvidencePlugin({required this.store, required this.audit});

  final GlobalDurableStore store;
  final GlobalAuditSink audit;

  @override
  String get pluginId => 'bil.core.evidence';

  @override
  Future<void> start() async {
    await store.put('plugin_runtime', pluginId, <String, Object?>{
      'active': true,
      'capabilities': <String>['evidence.graph', 'timeline.provenance'],
    });
  }

  @override
  Future<void> stop() async {
    await store.put('plugin_runtime', pluginId, <String, Object?>{
      'active': false,
    });
  }

  @override
  Future<void> migrate(String fromVersion, String toVersion) async {
    await store.put(
      'plugin_migrations',
      '$pluginId:$toVersion',
      <String, Object?>{'from': fromVersion, 'to': toVersion},
    );
  }
}
