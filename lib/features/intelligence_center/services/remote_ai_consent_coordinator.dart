import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coach_cloud_privacy_boundary.dart';

typedef RemoteAiConsentRead = Future<Object?> Function();
typedef RemoteAiConsentWrite = Future<void> Function();
typedef RemoteAiConsentOwner = String? Function();
typedef RemoteAiDenialRead = Future<bool> Function(String owner);
typedef RemoteAiDenialWrite = Future<void> Function(String owner, bool denied);

/// Session-scoped, server-authoritative Remote AI consent orchestration.
///
/// Concurrent reads and grants share one future. A positive receipt is cached
/// only for the current authenticated owner; owner changes clear it. Granting
/// is not considered successful until the current policy receipt is read back.
class RemoteAiConsentCoordinator {
  RemoteAiConsentCoordinator({
    required this.owner,
    required this.read,
    required this.write,
    this.revoke,
    this.readDenial,
    this.writeDenial,
  });

  final RemoteAiConsentOwner owner;
  final RemoteAiConsentRead read;
  final RemoteAiConsentWrite write;
  final RemoteAiConsentWrite? revoke;
  final RemoteAiDenialRead? readDenial;
  final RemoteAiDenialWrite? writeDenial;
  final Set<String> _deniedOwners = <String>{};
  Future<void> _denialWrites = Future<void>.value();

  String? _cachedOwner;
  bool _granted = false;
  Future<bool>? _readInFlight;
  Future<bool>? _grantInFlight;
  int _generation = 0;

  Future<bool> isGranted({bool forceServerRead = false}) {
    final owner = _syncOwner();
    if (owner == null) return Future<bool>.value(false);
    if (_deniedOwners.contains(owner)) return Future<bool>.value(false);
    if (_granted && !forceServerRead) return Future<bool>.value(true);
    final existing = _readInFlight;
    if (existing != null) return existing;
    final generation = _generation;
    late final Future<bool> pending;
    pending = _readCurrent(owner, generation).whenComplete(() {
      if (identical(_readInFlight, pending)) _readInFlight = null;
    });
    _readInFlight = pending;
    return pending;
  }

  Future<bool> grantAndVerify() {
    final owner = _syncOwner();
    if (owner == null) return Future<bool>.value(false);
    if (_granted && !_deniedOwners.contains(owner)) {
      return Future<bool>.value(true);
    }
    final existing = _grantInFlight;
    if (existing != null) return existing;
    invalidate();
    final generation = _generation;
    late final Future<bool> pending;
    pending = _grantCurrent(owner, generation).whenComplete(() {
      if (identical(_grantInFlight, pending)) _grantInFlight = null;
    });
    _grantInFlight = pending;
    return pending;
  }

  /// Withdraw immediately, before any network await. Persist even when the
  /// server is unreachable; only a NEW explicit Allow can lift this latch.
  Future<bool> revokeAndVerify() {
    final owner = _syncOwner();
    if (owner == null) return Future<bool>.value(false);
    invalidate();
    _deniedOwners.add(owner);
    return _revokeCurrent(owner, _generation);
  }

  void invalidate() {
    _generation++;
    _granted = false;
    _readInFlight = null;
    _grantInFlight = null;
  }

  String? _syncOwner() {
    final owner = this.owner()?.trim();
    final normalized = owner == null || owner.isEmpty ? null : owner;
    if (_cachedOwner != normalized) {
      _generation++;
      _cachedOwner = normalized;
      _granted = false;
      _readInFlight = null;
      _grantInFlight = null;
    }
    return normalized;
  }

  Future<bool> _readCurrent(String owner, int generation) async {
    final denied =
        _deniedOwners.contains(owner) ||
        await readDenial?.call(owner).timeout(const Duration(seconds: 8)) ==
            true;
    if (_syncOwner() != owner || _generation != generation) return false;
    if (denied) {
      _deniedOwners.add(owner);
      return false;
    }
    if (_syncOwner() != owner || _generation != generation) return false;
    final receipt = await read().timeout(const Duration(seconds: 8));
    final granted = isCurrentRemoteAiConsentGranted(receipt);
    if (_syncOwner() != owner || _generation != generation) return false;
    _granted = granted;
    return granted;
  }

  Future<bool> _grantCurrent(String owner, int generation) async {
    // Keep a prior withdrawal durable throughout grant persistence/readback.
    // Stale Allow/read completions must never clear a newer Don't Allow.
    _deniedOwners.add(owner);
    await _persistDenial(owner, true);
    if (_syncOwner() != owner || _generation != generation) return false;
    await write().timeout(const Duration(seconds: 8));
    if (_syncOwner() != owner || _generation != generation) return false;
    // Force one authoritative readback after persistence. The pending message
    // cannot proceed to Gemini unless policy version 3 is visible here.
    final receipt = await read().timeout(const Duration(seconds: 8));
    if (!isCurrentRemoteAiConsentGranted(receipt) ||
        _syncOwner() != owner ||
        _generation != generation) {
      return false;
    }
    await _persistDenial(owner, false);
    if (_syncOwner() != owner || _generation != generation) {
      await _persistDenial(owner, true);
      return false;
    }
    _deniedOwners.remove(owner);
    _granted = true;
    return true;
  }

  Future<bool> _revokeCurrent(String owner, int generation) async {
    await _persistDenial(owner, true);
    if (_syncOwner() != owner || _generation != generation) return false;
    final write = revoke;
    if (write == null) return false;
    await write().timeout(const Duration(seconds: 8));
    if (_syncOwner() != owner || _generation != generation) return false;
    final receipt = await read().timeout(const Duration(seconds: 8));
    return receipt is Map &&
        receipt['policy_version'] == '3' &&
        receipt['granted'] == false &&
        _syncOwner() == owner &&
        _generation == generation;
  }

  Future<void> _persistDenial(String owner, bool denied) {
    final pending = _denialWrites.then((_) async {
      await writeDenial?.call(owner, denied);
    });
    // A storage failure blocks this operation, without poisoning future retry.
    _denialWrites = pending.then<void>((_) {}, onError: (Object _) {});
    return pending.timeout(const Duration(seconds: 8));
  }
}

RemoteAiConsentCoordinator? _sharedCoordinator;
SupabaseClient? _sharedClient;

RemoteAiConsentCoordinator sharedRemoteAiConsentCoordinator([
  SupabaseClient? suppliedClient,
]) {
  final client = suppliedClient ?? Supabase.instance.client;
  if (!identical(client, _sharedClient) || _sharedCoordinator == null) {
    _sharedClient = client;
    _sharedCoordinator = RemoteAiConsentCoordinator(
      owner: () => client.auth.currentUser?.id,
      read: () => client.rpc('bil_get_remote_ai_consent'),
      write: () async {
        await client.rpc(
          'bil_record_consent',
          params: const <String, Object?>{
            'p_purpose': 'remote_ai',
            'p_policy_version': '3',
            'p_granted': true,
          },
        );
      },
      revoke: () async {
        await client.rpc(
          'bil_record_consent',
          params: const <String, Object?>{
            'p_purpose': 'remote_ai',
            'p_policy_version': '3',
            'p_granted': false,
          },
        );
      },
      readDenial: (owner) async =>
          (await SharedPreferences.getInstance()).getBool(
            'bil.remoteAi.denied.v3.$owner',
          ) ??
          false,
      writeDenial: (owner, denied) async {
        final persisted = await (await SharedPreferences.getInstance()).setBool(
          'bil.remoteAi.denied.v3.$owner',
          denied,
        );
        if (!persisted) throw StateError('remote_ai_denial_not_persisted');
      },
    );
  }
  return _sharedCoordinator!;
}
