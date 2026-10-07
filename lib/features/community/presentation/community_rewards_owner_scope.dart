part of 'community_rewards_page.dart';

/// Retires a page for any delivered account transition, including A -> B -> A.
/// The RPC zone additionally fences credentials resolved after a token refresh.
class _RewardsOwnerVisit {
  _RewardsOwnerVisit({
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
        // A network refresh failure alone does not establish an account change.
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
  bool _cancelled = false;

  static String? _readOwner(CommunityRepository repository) {
    try {
      return repository.currentUserId;
    } on AuthException {
      return null;
    }
  }

  bool get isCurrent =>
      !_disposed &&
      !_cancelled &&
      isAttached() &&
      ownerId != null &&
      _readOwner(repository) == ownerId;

  Future<T> run<T>(Future<T> Function() action) {
    if (!isCurrent) {
      return Future<T>.error(const CommunityOwnerOperationCancelled());
    }
    return repository.runForCommunityOwner(
      action,
      ownerId: ownerId!,
      isCurrentOwner: () => isCurrent,
    );
  }

  void _retire() {
    if (_disposed || _cancelled) return;
    _cancelled = true;
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
