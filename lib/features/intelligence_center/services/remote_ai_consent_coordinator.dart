import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'coach_cloud_privacy_boundary.dart';

typedef RemoteAiConsentRead = Future<Object?> Function();
typedef RemoteAiConsentWrite = Future<void> Function();
typedef RemoteAiConsentOwner = String? Function();

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
  });

  final RemoteAiConsentOwner owner;
  final RemoteAiConsentRead read;
  final RemoteAiConsentWrite write;

  String? _cachedOwner;
  bool _granted = false;
  Future<bool>? _readInFlight;
  Future<bool>? _grantInFlight;

  Future<bool> isGranted({bool forceServerRead = false}) {
    final owner = _syncOwner();
    if (owner == null) return Future<bool>.value(false);
    if (_granted && !forceServerRead) return Future<bool>.value(true);
    return _readInFlight ??= _readCurrent(owner).whenComplete(() {
      _readInFlight = null;
    });
  }

  Future<bool> grantAndVerify() {
    final owner = _syncOwner();
    if (owner == null) return Future<bool>.value(false);
    if (_granted) return Future<bool>.value(true);
    return _grantInFlight ??= _grantCurrent(owner).whenComplete(() {
      _grantInFlight = null;
    });
  }

  void invalidate() {
    _granted = false;
    _readInFlight = null;
  }

  String? _syncOwner() {
    final owner = this.owner()?.trim();
    final normalized = owner == null || owner.isEmpty ? null : owner;
    if (_cachedOwner != normalized) {
      _cachedOwner = normalized;
      _granted = false;
      _readInFlight = null;
      _grantInFlight = null;
    }
    return normalized;
  }

  Future<bool> _readCurrent(String owner) async {
    final receipt = await read().timeout(const Duration(seconds: 8));
    final granted = isCurrentRemoteAiConsentGranted(receipt);
    if (_syncOwner() == owner) _granted = granted;
    return granted;
  }

  Future<bool> _grantCurrent(String owner) async {
    await write().timeout(const Duration(seconds: 8));
    if (_syncOwner() != owner) return false;
    // Force one authoritative readback after persistence. The pending message
    // cannot proceed to Gemini unless policy version 3 is visible here.
    return isGranted(forceServerRead: true);
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
    );
  }
  return _sharedCoordinator!;
}
