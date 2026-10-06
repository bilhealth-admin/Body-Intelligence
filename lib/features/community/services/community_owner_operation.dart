import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityOwnerOperationCancelled extends AuthException {
  const CommunityOwnerOperationCancelled()
    : super('Community operation owner changed');
}

/// One authenticated visit owns every continuation of a Community operation.
/// A delivered A -> B -> A transition still cancels the original A work.
/// This is a cancellation fence, not a substitute for server authorization.
class CommunityOwnerOperation {
  CommunityOwnerOperation._(
    this.client,
    this.ownerId,
    this._readOwner,
    this._isCurrentOwner,
    this._parent,
  ) {
    if (_parent != null) return;
    var deliveredOwner = client.auth.currentUser?.id;
    _auth = client.auth.onAuthStateChange.listen(
      (state) {
        final next = state.session?.user.id;
        if (next != deliveredOwner) {
          _cancelled = true;
        }
        deliveredOwner = next;
      },
      onError: (Object _, StackTrace _) {
        _cancelled = true;
      },
    );
  }

  final SupabaseClient client;
  final String? ownerId;
  final String? Function() _readOwner;
  final bool Function()? _isCurrentOwner;
  final CommunityOwnerOperation? _parent;
  StreamSubscription<AuthState>? _auth;
  bool _cancelled = false;
  static final Object _zoneKey = Object();

  bool get isCurrent {
    if (_cancelled ||
        _parent?.isCurrent == false ||
        _isCurrentOwner?.call() == false) {
      return false;
    }
    try {
      return _readOwner() == ownerId;
    } on AuthException {
      return false;
    }
  }

  void check() {
    if (!isCurrent) {
      throw const CommunityOwnerOperationCancelled();
    }
  }

  static void checkCurrent() {
    (Zone.current[_zoneKey] as CommunityOwnerOperation?)?.check();
  }

  /// Nested calls retain both the parent and their own lifetime predicates.
  /// Closing an editor must still cancel its work while its feed stays open.
  /// Without an editor, the repository captures its own session before
  /// the first await. Null only represents an unauthenticated injected store;
  /// real RPC authorization and services still require an authenticated owner.
  static Future<T> run<T>({
    required SupabaseClient client,
    required String? ownerId,
    required Future<T> Function(CommunityOwnerOperation operation) action,
    String? Function()? readOwner,
    bool Function()? isCurrentOwner,
  }) {
    final parent = Zone.current[_zoneKey] as CommunityOwnerOperation?;
    if (parent != null) {
      parent.check();
      if (!identical(client, parent.client) || ownerId != parent.ownerId) {
        throw const CommunityOwnerOperationCancelled();
      }
      if (isCurrentOwner?.call() == false) {
        throw const CommunityOwnerOperationCancelled();
      }
    }
    final operation = CommunityOwnerOperation._(
      client,
      ownerId,
      readOwner ?? parent?._readOwner ?? () => client.auth.currentUser?.id,
      isCurrentOwner,
      parent,
    );
    return runZoned(() async {
      try {
        operation.check();
        final value = await action(operation);
        operation.check();
        return value;
      } finally {
        operation._cancelled = true;
        // Disposing the observer is synchronous from the operation's point of
        // view. Awaiting a root-zone stream cancellation can strand fake-clock
        // widget tests, and is not needed to fence callbacks after completion.
        unawaited(operation._auth?.cancel());
      }
    }, zoneValues: {_zoneKey: operation});
  }
}
