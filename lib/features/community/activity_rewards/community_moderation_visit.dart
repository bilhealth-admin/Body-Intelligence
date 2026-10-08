import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/community_repository.dart';
import '../services/community_owner_operation.dart';

/// A moderation page visit is permanently retired by any delivered account
/// transition. Returning to A after A -> B -> A does not revive old callbacks.
class CommunityModerationVisit {
  CommunityModerationVisit({
    required this.repository,
    required this.isAttached,
    required this.onRetired,
  }) : ownerId = _readOwner(repository) {
    final auth = repository.communitySocialClient.auth;
    var deliveredOwner = auth.currentUser?.id;
    _subscription = auth.onAuthStateChange.listen(
      (state) {
        final next = state.session?.user.id;
        final changed = next != deliveredOwner;
        deliveredOwner = next;
        if (changed || _readOwner(repository) != ownerId) _retire();
      },
      onError: (Object _, StackTrace _) {
        if (_readOwner(repository) != ownerId) _retire();
      },
    );
  }

  final CommunityRepository repository;
  final String? ownerId;
  final bool Function() isAttached;
  final VoidCallback onRetired;
  StreamSubscription<AuthState>? _subscription;
  bool _disposed = false;
  bool _retired = false;

  static String? _readOwner(CommunityRepository repository) {
    try {
      return repository.currentUserId;
    } on AuthException {
      return null;
    }
  }

  bool get isCurrent =>
      !_disposed &&
      !_retired &&
      isAttached() &&
      ownerId != null &&
      _readOwner(repository) == ownerId;

  Future<void> requireFreshModerator() async {
    if (!isCurrent) throw const CommunityOwnerOperationCancelled();
    repository.invalidateCommunityModeratorStatus();
    final allowed = await repository.isCommunityModerator();
    if (!isCurrent) throw const CommunityOwnerOperationCancelled();
    if (!allowed) throw const AuthException('Moderator access revoked');
  }

  Future<T> run<T>(Future<T> Function() action) {
    final owner = ownerId;
    if (!isCurrent || owner == null) {
      return Future<T>.error(const CommunityOwnerOperationCancelled());
    }
    return repository.runForCommunityOwner(
      action,
      ownerId: owner,
      isCurrentOwner: () => isCurrent,
    );
  }

  void _retire() {
    if (_disposed || _retired) return;
    _retired = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (isAttached()) onRetired();
  }

  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}
