import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../app/router/app_router.dart';
import '../../app/services/app_observability.dart';

enum BilAppleCredentialState { authorized, revoked, notFound }

@immutable
class BilAppleCredentialSession {
  const BilAppleCredentialSession({
    required this.ownerId,
    this.appleUserIdentifier,
  });

  final String ownerId;
  final String? appleUserIdentifier;
}

abstract interface class AppleCredentialIdentifierStore {
  Future<String?> read(String ownerId);
  Future<void> write(String ownerId, String userIdentifier);
  Future<void> delete(String ownerId);
}

/// Keeps Apple's stable per-app subject in the platform Keychain/keystore.
///
/// The identifier is namespaced by the authenticated BIL owner so switching
/// accounts can never apply one person's credential state to another session.
final class SecureAppleCredentialIdentifierStore
    implements AppleCredentialIdentifierStore {
  SecureAppleCredentialIdentifierStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'bil.auth.apple-user-id.v1.';
  static const _pendingCleanupPrefix =
      'bil.auth.apple-user-id-pending-cleanup.v1.';
  final FlutterSecureStorage _storage;

  @visibleForTesting
  static String storageKey(String ownerId) => '$_prefix${ownerId.trim()}';

  @visibleForTesting
  static String pendingCleanupKey(String ownerId) =>
      '$_pendingCleanupPrefix${ownerId.trim()}';

  @override
  Future<String?> read(String ownerId) =>
      _storage.read(key: storageKey(ownerId));

  @override
  Future<void> write(String ownerId, String userIdentifier) =>
      _storage.write(key: storageKey(ownerId), value: userIdentifier.trim());

  @override
  Future<void> delete(String ownerId) =>
      _storage.delete(key: storageKey(ownerId));

  /// Persists deletion intent before the app clears the only live owner
  /// context. Keychain survives process termination, so cleanup can resume on
  /// the next launch if iOS terminates BIL between receipt and local cleanup.
  Future<void> markPendingCleanup(String ownerId) =>
      _storage.write(key: pendingCleanupKey(ownerId), value: ownerId.trim());

  Future<Set<String>> readPendingCleanupOwners() async {
    final entries = await _storage.readAll();
    return entries.entries
        .where((entry) => entry.key.startsWith(_pendingCleanupPrefix))
        .map((entry) => entry.value.trim())
        .where((ownerId) => ownerId.isNotEmpty)
        .toSet();
  }

  Future<void> clearPendingCleanup(String ownerId) =>
      _storage.delete(key: pendingCleanupKey(ownerId));
}

/// Extracts the Apple subject already verified by Supabase. This migrates
/// sessions created before BIL began retaining the native user identifier.
@visibleForTesting
String? appleSubjectForSupabaseUser(User? user) {
  if (user == null) return null;
  for (final identity in user.identities ?? const <UserIdentity>[]) {
    if (identity.provider.trim().toLowerCase() != 'apple') continue;
    final subject = identity.identityData?['sub'];
    if (subject is String && subject.trim().isNotEmpty) return subject.trim();
  }
  return null;
}

@visibleForTesting
bool supabaseSessionAuthenticatedWithApple(User? user) {
  if (user == null) return false;

  final identities = user.identities ?? const <UserIdentity>[];
  final appleIdentities = identities
      .where((identity) => identity.provider.trim().toLowerCase() == 'apple')
      .toList(growable: false);
  if (appleIdentities.isEmpty) {
    // `app_metadata.provider` is the account's first provider, not the
    // provider that authenticated the current session. Only the unambiguous
    // one-provider fallback is safe when Supabase omits identity details.
    final providers = user.appMetadata['providers'];
    if (providers is! Iterable) return false;
    final normalized = providers
        .whereType<String>()
        .map((provider) => provider.trim().toLowerCase())
        .where((provider) => provider.isNotEmpty)
        .toSet();
    return normalized.length == 1 && normalized.single == 'apple';
  }

  if (identities.length == 1) {
    return true;
  }

  // A linked Apple identity does not prove that this session was created by
  // Apple. Compare Supabase's per-user and per-identity last-sign-in values so
  // a later email/Google login cannot be evicted by an older revoked Apple
  // identity on the same account.
  final userLastSignIn = _normalizedInstant(user.lastSignInAt);
  if (userLastSignIn == null) return false;
  return appleIdentities.any(
    (identity) => _normalizedInstant(identity.lastSignInAt) == userLastSignIn,
  );
}

int? _normalizedInstant(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return DateTime.tryParse(normalized)?.toUtc().microsecondsSinceEpoch;
}

/// Invalidates only the expected account and returns as soon as the local
/// session is gone. Supabase clears its in-memory session before awaiting the
/// best-effort `/logout` request, so sensitive UI does not wait on the network.
Future<bool> invalidateMatchingLocalSession({
  required String expectedOwnerId,
  required String? Function() readCurrentOwnerId,
  required Future<void> Function() signOutLocal,
  Duration fallbackTimeout = const Duration(seconds: 2),
  void Function(Object error, StackTrace stackTrace)? onError,
}) async {
  final expected = expectedOwnerId.trim();
  if (expected.isEmpty || readCurrentOwnerId()?.trim() != expected) {
    return false;
  }

  late final Future<void> completion;
  try {
    completion = signOutLocal();
  } catch (error, stackTrace) {
    onError?.call(error, stackTrace);
    return readCurrentOwnerId() == null;
  }

  if (readCurrentOwnerId() == null) {
    unawaited(_observeSignOutCompletion(completion, onError));
    return true;
  }

  try {
    await completion.timeout(fallbackTimeout);
  } catch (error, stackTrace) {
    onError?.call(error, stackTrace);
  }
  return readCurrentOwnerId() == null;
}

Future<void> _observeSignOutCompletion(
  Future<void> completion,
  void Function(Object error, StackTrace stackTrace)? onError,
) async {
  try {
    await completion;
  } catch (error, stackTrace) {
    onError?.call(error, stackTrace);
  }
}

/// Testable authority for reconciling Apple's credential with the local
/// Supabase session. Network/provider errors never invent a revocation;
/// Apple's explicit `revoked`/`notFound` states invalidate the session, while
/// loss of the protected identifier fails closed because later checks would
/// otherwise be impossible.
final class AppleCredentialLifecycleController {
  AppleCredentialLifecycleController({
    required this.identifierStore,
    required this.readCurrentSession,
    required this.readCredentialState,
    required this.signOutLocal,
    this.onSessionInvalidated,
    this.onError,
  });

  final AppleCredentialIdentifierStore identifierStore;
  final FutureOr<BilAppleCredentialSession?> Function() readCurrentSession;
  final Future<BilAppleCredentialState> Function(String userIdentifier)
  readCredentialState;

  /// Returns true only when the expected owner's local session was actually
  /// invalidated. A false result protects a replacement account that won a
  /// race after the credential-state response arrived.
  final Future<bool> Function(String expectedOwnerId) signOutLocal;
  final FutureOr<void> Function()? onSessionInvalidated;
  final void Function(Object error, StackTrace stackTrace)? onError;

  Future<void>? _activeReconciliation;
  bool _reconcileAgain = false;

  Future<void> reconcile() {
    final active = _activeReconciliation;
    if (active != null) {
      _reconcileAgain = true;
      return active;
    }
    final reconciliation = _drainReconciliations();
    _activeReconciliation = reconciliation;
    return reconciliation.whenComplete(() {
      _activeReconciliation = null;
    });
  }

  Future<void> _drainReconciliations() async {
    do {
      _reconcileAgain = false;
      try {
        await _reconcileOnce();
      } catch (error, stackTrace) {
        onError?.call(error, stackTrace);
      }
    } while (_reconcileAgain);
  }

  Future<void> _reconcileOnce() async {
    final session = await readCurrentSession();
    if (session == null || session.ownerId.trim().isEmpty) return;
    final ownerId = session.ownerId.trim();

    String? identifier;
    try {
      identifier = (await identifierStore.read(ownerId))?.trim();
    } catch (error, stackTrace) {
      // Losing access to an existing Keychain subject makes future Apple
      // checks impossible, so do not keep that Apple-authenticated session.
      onError?.call(error, stackTrace);
      await _invalidateOwnerIfCurrent(ownerId);
      return;
    }
    if (identifier == null || identifier.isEmpty) {
      identifier = session.appleUserIdentifier?.trim();
      if (identifier == null || identifier.isEmpty) return;
      try {
        await identifierStore.write(ownerId, identifier);
      } catch (error, stackTrace) {
        // A legacy Apple session whose subject cannot be protected cannot be
        // monitored safely on the next launch. Fail closed, as native Apple
        // sign-in already does when the same secure write fails.
        onError?.call(error, stackTrace);
        await _invalidateOwnerIfCurrent(ownerId);
        return;
      }
    }

    final state = await readCredentialState(identifier);
    if (state == BilAppleCredentialState.authorized) return;

    await _invalidateOwnerIfCurrent(ownerId);
  }

  Future<void> _invalidateOwnerIfCurrent(String ownerId) async {
    // Every operation above can be asynchronous. Never sign out a new account
    // that replaced the checked account while Apple or secure storage replied.
    final current = await readCurrentSession();
    if (current?.ownerId.trim() != ownerId) return;

    final invalidated = await signOutLocal(ownerId);
    if (!invalidated) return;

    // Remove sensitive UI before Keychain I/O. Cleanup is best effort and may
    // not suppress navigation after the local session has already disappeared.
    try {
      await onSessionInvalidated?.call();
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
    try {
      await identifierStore.delete(ownerId);
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
  }
}

/// App-root coordinator for both Apple lifecycle signals:
///
/// * checks `getCredentialState` on startup/sign-in and every foreground
///   resume; and
/// * receives `credentialRevokedNotification` from the native iOS bridge.
class BilAppleCredentialLifecycleCoordinator extends StatefulWidget {
  const BilAppleCredentialLifecycleCoordinator({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<BilAppleCredentialLifecycleCoordinator> createState() =>
      _BilAppleCredentialLifecycleCoordinatorState();
}

class _BilAppleCredentialLifecycleCoordinatorState
    extends State<BilAppleCredentialLifecycleCoordinator>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('bil/apple_sign_in_lifecycle');

  StreamSubscription<AuthState>? _authSubscription;
  AppleCredentialLifecycleController? _controller;
  SecureAppleCredentialIdentifierStore? _identifierStore;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _enabled =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        AppEnvironment.supabaseRuntimeReady;
    if (!_enabled) return;

    WidgetsBinding.instance.addObserver(this);
    final auth = Supabase.instance.client.auth;
    final identifierStore = SecureAppleCredentialIdentifierStore();
    _identifierStore = identifierStore;
    _controller = AppleCredentialLifecycleController(
      identifierStore: identifierStore,
      readCurrentSession: () {
        final user = auth.currentUser;
        if (!supabaseSessionAuthenticatedWithApple(user)) return null;
        return BilAppleCredentialSession(
          ownerId: user!.id,
          appleUserIdentifier: appleSubjectForSupabaseUser(user),
        );
      },
      readCredentialState: (identifier) async {
        final state = await SignInWithApple.getCredentialState(
          identifier,
        ).timeout(const Duration(seconds: 10));
        return switch (state) {
          CredentialState.authorized => BilAppleCredentialState.authorized,
          CredentialState.revoked => BilAppleCredentialState.revoked,
          CredentialState.notFound => BilAppleCredentialState.notFound,
        };
      },
      signOutLocal: (expectedOwnerId) => invalidateMatchingLocalSession(
        expectedOwnerId: expectedOwnerId,
        readCurrentOwnerId: () => auth.currentUser?.id,
        signOutLocal: () => auth.signOut(scope: SignOutScope.local),
        onError: (error, _) {
          AppObservability.logger.record(
            AppLogLevel.warning,
            'apple_local_sign_out_failed',
            attributes: <String, Object?>{
              'errorType': error.runtimeType.toString(),
            },
          );
        },
      ),
      onSessionInvalidated: () => AppRouter.router.go('/startup'),
      onError: (error, _) {
        AppObservability.logger.record(
          AppLogLevel.warning,
          'apple_credential_reconciliation_failed',
          attributes: <String, Object?>{
            'errorType': error.runtimeType.toString(),
          },
        );
      },
    );

    _channel.setMethodCallHandler(_handleNativeCall);
    _authSubscription = auth.onAuthStateChange.listen(
      (_) => unawaited(_controller!.reconcile()),
      onError: (Object error, StackTrace stackTrace) {
        AppObservability.logger.record(
          AppLogLevel.warning,
          'apple_auth_lifecycle_stream_failed',
          attributes: <String, Object?>{
            'errorType': error.runtimeType.toString(),
          },
        );
      },
    );
    unawaited(_startNativeObservation(auth));
  }

  Future<void> _startNativeObservation(GoTrueClient auth) async {
    await _retryPendingDeletionCleanup(auth);
    try {
      await _channel.invokeMethod<void>('startObserving');
    } on MissingPluginException {
      // A mismatched native shell must not suppress the foreground state
      // check supplied by the Sign in with Apple plugin itself.
    } on PlatformException catch (error) {
      AppObservability.logger.record(
        AppLogLevel.warning,
        'apple_revocation_observer_unavailable',
        attributes: <String, Object?>{'errorCode': error.code},
      );
    }
    await _controller?.reconcile();
  }

  Future<void> _retryPendingDeletionCleanup(GoTrueClient auth) async {
    final store = _identifierStore;
    if (store == null) return;

    Set<String> owners;
    try {
      owners = await store.readPendingCleanupOwners();
    } catch (error, stackTrace) {
      _recordCleanupFailure(error, stackTrace);
      return;
    }

    for (final ownerId in owners) {
      if (auth.currentUser?.id == ownerId) {
        final invalidated = await invalidateMatchingLocalSession(
          expectedOwnerId: ownerId,
          readCurrentOwnerId: () => auth.currentUser?.id,
          signOutLocal: () => auth.signOut(scope: SignOutScope.local),
          onError: _recordCleanupFailure,
        );
        if (!invalidated && auth.currentUser?.id == ownerId) continue;
        AppRouter.router.go('/startup');
      }

      try {
        await store.delete(ownerId);
        await store.clearPendingCleanup(ownerId);
      } catch (error, stackTrace) {
        _recordCleanupFailure(error, stackTrace);
      }
    }
  }

  void _recordCleanupFailure(Object error, StackTrace _) {
    AppObservability.logger.record(
      AppLogLevel.warning,
      'apple_pending_cleanup_failed',
      attributes: <String, Object?>{'errorType': error.runtimeType.toString()},
    );
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'credentialRevoked') {
      await _controller?.reconcile();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller?.reconcile());
    }
  }

  @override
  void dispose() {
    if (_enabled) {
      WidgetsBinding.instance.removeObserver(this);
      unawaited(_authSubscription?.cancel());
      _channel.setMethodCallHandler(null);
      unawaited(
        _channel.invokeMethod<void>('stopObserving').catchError((_) {}),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
