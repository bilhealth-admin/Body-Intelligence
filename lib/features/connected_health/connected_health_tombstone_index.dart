import '../global_platform/core/global_platform_core.dart';

/// A per-load snapshot; never cached across sync or permission transitions.
/// Modern rows are indexed in one read. Legacy value-only tombstones retain
/// their key-based meaning without requiring a schema change or discarding data.
final class ConnectedHealthTombstoneIndex {
  ConnectedHealthTombstoneIndex._(this._store, this._ids, this._legacy);
  final GlobalDurableStore _store;
  final Set<String> _ids;
  final bool _legacy;
  final Map<String, bool> _lookedUp = {};

  static Future<ConnectedHealthTombstoneIndex> load(GlobalDurableStore store) async {
    final rows = await store.list('health_tombstones');
    final ids = <String>{};
    var legacy = false;
    for (final row in rows) {
      final provider = row['provider'];
      final record = row['recordId'];
      if (provider is String && provider.isNotEmpty &&
          record is String && record.isNotEmpty) {
        ids.add('$provider:$record');
      } else {
        // Some installed clients wrote only {deleted: true} under the native
        // record key. list() intentionally returns values, not storage keys.
        legacy = true;
      }
    }
    return ConnectedHealthTombstoneIndex._(store, ids, legacy);
  }

  Future<bool> containsAny(Iterable<String> keys) async {
    final unique = keys.toSet();
    if (unique.any(_ids.contains)) return true;
    if (!_legacy) return false;
    for (final key in unique) {
      final found = _lookedUp[key] ??
          (await _store.get('health_tombstones', key) != null);
      _lookedUp[key] = found;
      if (found) return true;
    }
    return false;
  }
}
