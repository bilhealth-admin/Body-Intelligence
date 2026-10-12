import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../community/services/community_owner_operation.dart';
import 'cloud_sync_consent_repository.dart';

enum CloudRestoreScope { nutrition, goals }

enum CloudRestoreConsentAvailability {
  available,
  baseConsentRequired,
  unavailable,
  signedOut,
}

final class CloudRestoreConsentState {
  const CloudRestoreConsentState({
    required this.availability,
    this.ownerId,
    this.grantedScopes = const {},
    this.requestedScopes = const {},
    this.recordedAt = const {},
  });

  final CloudRestoreConsentAvailability availability;
  final String? ownerId;
  final Set<CloudRestoreScope> grantedScopes;
  // Device-local intent is status information only, never authorization.
  final Set<CloudRestoreScope> requestedScopes;
  final Map<CloudRestoreScope, DateTime?> recordedAt;

  bool allows(CloudRestoreScope scope) =>
      availability == CloudRestoreConsentAvailability.available &&
      grantedScopes.contains(scope);

  bool canChange(CloudRestoreScope scope) =>
      availability == CloudRestoreConsentAvailability.available ||
      (availability == CloudRestoreConsentAvailability.baseConsentRequired &&
          grantedScopes.contains(scope));
}

abstract interface class CloudRestoreConsentBackend {
  String? get ownerId;
  Stream<String?> get ownerChanges;
  Future<bool> baseConsentGranted();
  Future<Object?> capabilities();
  Future<Object?> readConsent();
  Future<Object?> writeConsent(CloudRestoreScope scope, bool granted);
}

abstract interface class CloudRestoreConsentLocalStore {
  Future<Map<CloudRestoreScope, bool>> read(String ownerId);
  Future<void> write(String ownerId, CloudRestoreScope scope, bool granted);
}

final class CloudRestoreConsentLease {
  const CloudRestoreConsentLease._(this.ownerId, this.epoch, this.scopes);
  final String ownerId;
  final int epoch;
  final Set<CloudRestoreScope> scopes;
}

/// Extra scopes are opt-in and never inferred from the original cloud grant.
/// The epoch cancels A -> B -> A continuations and local withdrawal immediately;
/// server authorization remains mandatory for every transport operation.
final class CloudRestoreConsentRepository {
  CloudRestoreConsentRepository({
    required SupabaseClient client,
    CloudRestoreConsentLocalStore? localStore,
  }) : this.withBackend(
         backend: _SupabaseRestoreConsentBackend(client),
         localStore: localStore,
       );

  CloudRestoreConsentRepository.withBackend({
    required CloudRestoreConsentBackend backend,
    this._localStore,
  }) : _backend = backend {
    _owner = backend.ownerId;
    _auth = backend.ownerChanges.listen((owner) {
      if (owner == _owner) return;
      _owner = owner;
      _epoch++;
      _lastState = null;
      _denied.clear();
    }, onError: (Object _, StackTrace _) => invalidate());
  }

  static const policyVersion = '1';
  final CloudRestoreConsentBackend _backend;
  final CloudRestoreConsentLocalStore? _localStore;
  late final StreamSubscription<String?> _auth;
  String? _owner;
  int _epoch = 0;
  bool _disposed = false;
  bool _writing = false;
  CloudRestoreConsentState? _lastState;
  final Set<CloudRestoreScope> _denied = {};

  void invalidate() {
    _epoch++;
    _lastState = null;
  }

  CloudRestoreConsentLease captureLease(CloudRestoreConsentState state) {
    if (!identical(state, _lastState) ||
        state.ownerId != _backend.ownerId ||
        (state.availability != CloudRestoreConsentAvailability.available &&
            state.availability !=
                CloudRestoreConsentAvailability.baseConsentRequired)) {
      throw StateError('Cloud restore consent is not current.');
    }
    return CloudRestoreConsentLease._(
      state.ownerId!,
      _epoch,
      Set.unmodifiable(
        state.availability == CloudRestoreConsentAvailability.available
            ? state.grantedScopes
            : <CloudRestoreScope>{},
      ),
    );
  }

  bool isCurrent(CloudRestoreConsentLease lease, CloudRestoreScope scope) =>
      !_disposed &&
      lease.epoch == _epoch &&
      lease.ownerId == _backend.ownerId &&
      lease.scopes.contains(scope) &&
      !_denied.contains(scope);

  Future<CloudRestoreConsentState> read() async {
    invalidate();
    final owner = _backend.ownerId;
    final epoch = _epoch;
    if (owner == null) {
      return const CloudRestoreConsentState(
        availability: CloudRestoreConsentAvailability.signedOut,
      );
    }
    var requested = <CloudRestoreScope>{};
    try {
      final choices = await _localStore?.read(owner) ?? {};
      _check(owner, epoch);
      requested = choices.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toSet();
      _denied.addAll(
        choices.entries
            .where((entry) => !entry.value)
            .map((entry) => entry.key),
      );
      final capability = await _backend.capabilities();
      _check(owner, epoch);
      if (!_supports(capability)) {
        return CloudRestoreConsentState(
          availability: CloudRestoreConsentAvailability.unavailable,
          ownerId: owner,
          requestedScopes: requested,
        );
      }
      final baseGranted = await _backend.baseConsentGranted();
      _check(owner, epoch);
      final raw = await _backend.readConsent();
      _check(owner, epoch);
      if (raw is! Map) throw const FormatException('Invalid consent response');
      final grants = <CloudRestoreScope>{};
      final recorded = <CloudRestoreScope, DateTime?>{};
      for (final scope in CloudRestoreScope.values) {
        final row = raw[scope.name];
        if (row != null && row is! Map) {
          throw const FormatException('Invalid scoped consent');
        }
        if (row is Map) {
          if (row['granted'] == true &&
              row['policy_version'] == policyVersion &&
              !_denied.contains(scope)) {
            grants.add(scope);
            // Remember the explicit server receipt for honest status if this
            // account later reaches a server without the new capability.
            if (!choices.containsKey(scope)) {
              await _localStore?.write(owner, scope, true);
              _check(owner, epoch);
            }
            requested.add(scope);
          }
          recorded[scope] = DateTime.tryParse('${row['recorded_at'] ?? ''}');
        }
      }
      final state = CloudRestoreConsentState(
        availability: baseGranted
            ? CloudRestoreConsentAvailability.available
            : CloudRestoreConsentAvailability.baseConsentRequired,
        ownerId: owner,
        grantedScopes: Set.unmodifiable(grants),
        requestedScopes: Set.unmodifiable(requested),
        recordedAt: Map.unmodifiable(recorded),
      );
      _lastState = state;
      return state;
    } on Object {
      return CloudRestoreConsentState(
        availability: CloudRestoreConsentAvailability.unavailable,
        ownerId: _backend.ownerId == owner && _epoch == epoch ? owner : null,
        requestedScopes: _epoch == epoch ? requested : const {},
      );
    }
  }

  Future<void> setGranted(
    CloudRestoreScope scope,
    bool granted, {
    CloudRestoreConsentLease? expectedSession,
  }) async {
    if (_writing) throw StateError('A consent update is already pending.');
    final owner = _backend.ownerId;
    if (owner == null || _disposed) {
      throw StateError('Authentication is required for cloud restore consent.');
    }
    if (expectedSession != null) {
      _check(expectedSession.ownerId, expectedSession.epoch);
    }
    _writing = true;
    // Withdrawal fences in-flight work before network or storage awaits.
    invalidate();
    if (!granted) _denied.add(scope);
    final epoch = _epoch;
    try {
      await _localStore?.write(owner, scope, granted);
      _check(owner, epoch);
      if (!_supports(await _backend.capabilities())) {
        throw StateError('Cloud restore is unavailable on this server.');
      }
      _check(owner, epoch);
      if (granted) {
        final baseGranted = await _backend.baseConsentGranted();
        _check(owner, epoch);
        if (!baseGranted) throw StateError('Base cloud consent is required.');
      }
      final receipt = await _backend.writeConsent(scope, granted);
      _check(owner, epoch);
      if (receipt is! Map ||
          receipt['scope'] != scope.name ||
          receipt['granted'] != granted ||
          receipt['policy_version'] != policyVersion ||
          DateTime.tryParse('${receipt['recorded_at'] ?? ''}') == null) {
        throw StateError('Cloud consent was not confirmed.');
      }
      if (granted) _denied.remove(scope);
    } finally {
      _writing = false;
    }
  }

  bool _supports(Object? raw) =>
      raw is Map &&
      raw['protocol_version'] == 2 &&
      raw['consent_policy_version'] == policyVersion &&
      raw['scopes'] is List &&
      CloudRestoreScope.values.every(
        (scope) => (raw['scopes'] as List).contains(scope.name),
      );

  void _check(String owner, int epoch) {
    if (_disposed || _backend.ownerId != owner || _epoch != epoch) {
      throw StateError('Cloud restore consent session changed.');
    }
  }

  void dispose() {
    _disposed = true;
    invalidate();
    unawaited(_auth.cancel());
  }
}

final class _SupabaseRestoreConsentBackend
    implements CloudRestoreConsentBackend {
  const _SupabaseRestoreConsentBackend(this.client);
  final SupabaseClient client;
  @override
  String? get ownerId => client.auth.currentUser?.id;
  @override
  Stream<String?> get ownerChanges =>
      client.auth.onAuthStateChange.map((event) => event.session?.user.id);
  @override
  Future<bool> baseConsentGranted() => CommunityOwnerOperation.run(
    client: client,
    ownerId: ownerId,
    action: (_) async {
      final state = await CloudSyncConsentRepository(client: client).read();
      if (state.availability != CloudSyncConsentAvailability.available) {
        throw StateError('Base cloud consent is unavailable');
      }
      return state.granted;
    },
  );
  @override
  Future<Object?> capabilities() => _rpc('bil_cloud_restore_capabilities_v2');
  @override
  Future<Object?> readConsent() => _rpc('bil_cloud_restore_consent_v2');
  @override
  Future<Object?> writeConsent(CloudRestoreScope scope, bool granted) => _rpc(
    'bil_record_cloud_restore_consent_v2',
    params: {
      'p_scope': scope.name,
      'p_granted': granted,
      'p_policy_version': CloudRestoreConsentRepository.policyVersion,
    },
  );

  Future<Object?> _rpc(String name, {Map<String, Object?>? params}) =>
      CommunityOwnerOperation.run(
        client: client,
        ownerId: ownerId,
        action: (_) async => client
            .rpc(name, params: params ?? const {})
            .timeout(const Duration(seconds: 20)),
      );
}
