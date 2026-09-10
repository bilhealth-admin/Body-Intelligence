import '../../../data/repositories/preferences_repository.dart';

/// Local edits are durable first. Only an acknowledged write clears the marker;
/// an older cloud read must never replace a newer edit, even after app restart.
class DisplayNameSync {
  DisplayNameSync({
    required this.preferences,
    required this.currentOwnerId,
    required this.readRemote,
    required this.writeRemote,
  });

  static const nameKey = 'displayName';
  static const pendingKey = 'displayName.pending';
  static Map<String, String> localEdit(String name) => {
    nameKey: name.trim(),
    pendingKey: name.trim(),
  };

  final PreferencesRepository preferences;
  final String? Function() currentOwnerId;
  final Future<String?> Function(String owner) readRemote;
  final Future<bool> Function(String owner, String name) writeRemote;
  Future<void>? _running;
  bool _again = false;
  bool _disposed = false;

  void dispose() => _disposed = true;

  Future<void> synchronize() {
    _again = true;
    return _running ??= _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    do {
      _again = false;
      await _synchronizeOnce();
    } while (_again && !_disposed);
  }

  bool _owns(String owner) =>
      !_disposed &&
      currentOwnerId() == owner &&
      preferences.localOwnerId == owner;

  Future<void> _synchronizeOnce() async {
    final owner = currentOwnerId();
    if (owner == null || !_owns(owner)) return;
    try {
      final pending = await preferences.get(pendingKey);
      final local = await preferences.get(nameKey);
      if (!_owns(owner)) return;
      final expected = {nameKey: local, pendingKey: pending};
      if (pending != null) {
        if (pending != local) return;
        // Do not time out a write without cancelling it: a late write could
        // otherwise land after a newer one. UI callers do not wait on this work.
        final saved = await writeRemote(owner, pending);
        if (saved && _owns(owner)) {
          final unchanged = await preferences.mutateIfUnchanged(
            expected: expected,
            remove: [pendingKey],
          );
          if (!unchanged) _again = true;
        }
      } else {
        final remote = (await readRemote(
          owner,
        ).timeout(const Duration(seconds: 8)))?.trim();
        if (!_owns(owner) ||
            remote == null ||
            remote.isEmpty ||
            remote == local) {
          return;
        }
        final unchanged = await preferences.mutateIfUnchanged(
          expected: expected,
          set: {nameKey: remote},
        );
        if (!unchanged) _again = true;
      }
    } on Object {
      // Offline/denied writes remain pending; the local name stays authoritative
      // until a later explicit save, profile load, or restart retries the sync.
    }
  }
}
