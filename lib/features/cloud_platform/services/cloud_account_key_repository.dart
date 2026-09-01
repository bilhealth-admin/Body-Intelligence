import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal secure-storage seam so cloud key custody can be unit-tested without
/// touching platform keychains/keystores.
abstract interface class CloudSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class FlutterSecureCloudSecretStore implements CloudSecretStore {
  FlutterSecureCloudSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

typedef CloudKeyRpcLookup = FutureOr<dynamic> Function(String fnName);

/// Resolves one stable 256-bit account payload key.
///
/// The server stores the canonical account key in Supabase Vault, never in the
/// public application tables. Each authenticated device caches the returned key
/// only in platform secure storage. The key is namespaced by owner, so account
/// switching cannot reuse another user's payload key.
final class CloudAccountKeyRepository {
  CloudAccountKeyRepository({
    required this._client,
    CloudSecretStore? secureStore,
    CloudKeyRpcLookup? rpc,
  }) : _secureStore = secureStore ?? FlutterSecureCloudSecretStore(),
       _rpc = rpc ?? ((String fnName) => _client.rpc<dynamic>(fnName));

  static const _storagePrefix = 'bil.cloud.payload-key.v1.';
  static const keyByteLength = 32;

  final SupabaseClient _client;
  final CloudSecretStore _secureStore;
  final CloudKeyRpcLookup _rpc;

  /// Reads only key material already cached for this authenticated account.
  ///
  /// Startup recovery deliberately uses this path: it must never invoke the
  /// create-capable Vault RPC or mutate secure storage while the app is
  /// deciding its first route.
  Future<Uint8List?> readCached(String ownerId) async {
    final owner = ownerId.trim();
    if (owner.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Must not be empty');
    }
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || currentUser.id != owner) {
      throw StateError('Cloud key request does not match the active account.');
    }
    final cached = await _secureStore.read('$_storagePrefix$owner');
    return cached == null ? null : _decodeAndValidate(cached);
  }

  Future<Uint8List?> resolveExisting(String ownerId) async {
    final owner = ownerId.trim();
    if (owner.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Must not be empty');
    }
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || currentUser.id != owner) {
      throw StateError('Cloud key request does not match the active account.');
    }

    final storageKey = '$_storagePrefix$owner';
    final cached = await _secureStore.read(storageKey);
    if (cached != null) {
      return _decodeAndValidate(cached);
    }

    final response = await _rpc('bil_get_existing_cloud_key');
    if (response == null) {
      return null;
    }
    if (response is! String || response.trim().isEmpty) {
      throw const FormatException('Invalid BIL cloud key response.');
    }
    final canonical = response.trim();
    final key = _decodeAndValidate(canonical);
    await _secureStore.write(storageKey, canonical);
    return key;
  }

  Future<Uint8List> resolve(String ownerId) async {
    final owner = ownerId.trim();
    if (owner.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Must not be empty');
    }
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || currentUser.id != owner) {
      throw StateError('Cloud key request does not match the active account.');
    }

    final storageKey = '$_storagePrefix$owner';
    final cached = await _secureStore.read(storageKey);
    if (cached != null) {
      return _decodeAndValidate(cached);
    }

    final response = await _client.rpc('bil_get_or_create_cloud_key');
    if (response is! String || response.trim().isEmpty) {
      throw const FormatException('Invalid BIL cloud key response.');
    }
    final canonical = response.trim();
    final key = _decodeAndValidate(canonical);
    await _secureStore.write(storageKey, canonical);
    return key;
  }

  Future<void> removeLocal(String ownerId) async {
    final owner = ownerId.trim();
    if (owner.isEmpty) return;
    await _secureStore.delete('$_storagePrefix$owner');
  }

  static Uint8List _decodeAndValidate(String encoded) {
    late final Uint8List decoded;
    try {
      decoded = Uint8List.fromList(base64.decode(encoded));
    } on FormatException {
      throw const FormatException('Malformed BIL cloud key material.');
    }
    if (decoded.length != keyByteLength) {
      throw const FormatException('BIL cloud key must contain 256 bits.');
    }
    return decoded;
  }
}
