import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/global_platform_core.dart';

/// Keeps locally cached health evidence and its consent, anchors, and
/// tombstones isolated to the BIL account that created them.
///
/// Existing unscoped rows are deliberately left in place for recovery. They
/// are not copied into an account because their historical owner is unknown.
final class OwnerScopedHealthStore implements GlobalDurableStore {
  OwnerScopedHealthStore({
    required this._inner,
    required String ownerId,
    required this._readCurrentOwnerId,
  }) : _ownerId = _normalizeOwner(ownerId),
       _ownerDigest = sha256
           .convert(utf8.encode(_normalizeOwner(ownerId)))
           .toString()
           .substring(0, 24);

  static const String localDeviceOwner = 'local-device';

  /// Persisted BIL-owned HealthKit/Health Connect cache families. Clearing
  /// these buckets never calls the OS health store or removes Apple Health
  /// records. Keep this list aligned with the health runtime's store calls.
  static const List<String> accountHealthDataBuckets = <String>[
    'connected_health_consent',
    'connected_health_ui',
    'connected_health_evidence',
    'health_anchor',
    'health_signals',
    'health_seen',
  ];

  final GlobalDurableStore _inner;
  final String _ownerId;
  final String? Function() _readCurrentOwnerId;
  final String _ownerDigest;

  static String _normalizeOwner(String? ownerId) {
    final normalized = ownerId?.trim();
    return normalized == null || normalized.isEmpty
        ? localDeviceOwner
        : normalized;
  }

  bool get isOwnerCurrent {
    try {
      return _normalizeOwner(_readCurrentOwnerId()) == _ownerId;
    } on Object {
      return false;
    }
  }

  String _bucket(String bucket) {
    if (!isOwnerCurrent) throw StateError('health_owner_scope_changed');
    // Scope every bucket used by the dedicated health runtime. This keeps a
    // newly added health cache family private by default as well.
    return 'health-owner-v1:$_ownerDigest:$bucket';
  }

  @override
  Future<void> put(
    String bucket,
    String key,
    Map<String, Object?> value,
  ) async {
    await _inner.put(_bucket(bucket), key, value);
    if (!isOwnerCurrent) throw StateError('health_owner_scope_changed');
  }

  @override
  Future<Map<String, Object?>?> get(String bucket, String key) async {
    final value = await _inner.get(_bucket(bucket), key);
    if (!isOwnerCurrent) throw StateError('health_owner_scope_changed');
    return value;
  }

  @override
  Future<List<Map<String, Object?>>> list(String bucket) async {
    final value = await _inner.list(_bucket(bucket));
    if (!isOwnerCurrent) throw StateError('health_owner_scope_changed');
    return value;
  }

  @override
  Future<void> remove(String bucket, String key) async {
    await _inner.remove(_bucket(bucket), key);
    if (!isOwnerCurrent) throw StateError('health_owner_scope_changed');
  }

  @override
  Future<void> clear(String bucket) async {
    await _inner.clear(_bucket(bucket));
    if (!isOwnerCurrent) throw StateError('health_owner_scope_changed');
  }

  /// Removes only this BIL account's local health cache after a durable
  /// account-deletion request. Apple's HealthKit database is not touched.
  Future<void> clearForAccountDeletion() async {
    for (final bucket in accountHealthDataBuckets) {
      await clear(bucket);
    }
  }
}
