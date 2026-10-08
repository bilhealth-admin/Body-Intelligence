part of '../presentation/community_hub_page.dart';

class _CommunityHomeVisit {
  const _CommunityHomeVisit({
    required this.repository,
    required this.ownerId,
    required this.epoch,
    required this.isCurrent,
    required this.changes,
  });

  final CommunityRepository repository;
  final String ownerId;
  final int epoch;
  final ValueGetter<bool> isCurrent;
  final Listenable changes;

  void check() {
    if (!isCurrent()) throw const CommunityOwnerOperationCancelled();
    CommunityOwnerOperation.checkCurrent();
  }

  Future<T> run<T>(Future<T> Function() action) =>
      repository.runForCommunityOwner(
        action,
        ownerId: ownerId,
        isCurrentOwner: isCurrent,
      );

  Widget guard(Widget child) => ListenableBuilder(
    listenable: changes,
    builder: (context, _) =>
        isCurrent() ? child : const _CommunityProfileOwnerChangedBody(),
  );
}

extension _CommunityHomeOwnerScope on _CommunityHubPageState {
  String? _readHomeRepositoryOwner(CommunityRepository? repository) {
    if (repository == null) return null;
    try {
      return repository.currentUserId;
    } on Object {
      return null;
    }
  }

  void _notifyHomeVisitChanged({bool dispose = false}) {
    scheduleMicrotask(() {
      if (_homeSignalDisposed) return;
      _homeOwnerChanges.value++;
      if (dispose) {
        _homeSignalDisposed = true;
        _homeOwnerChanges.dispose();
      }
    });
  }

  void _invalidateHomeVisit() {
    _homeVisitEpoch++;
    _notifyHomeVisitChanged();
  }

  void _bindHomeOwnerSession() {
    unawaited(_authSubscription?.cancel());
    _authSubscription = null;
    final repository = _repository;
    final client = repository?.communitySocialClient ?? _productionClient();
    _deliveredOwnerId = client?.auth.currentUser?.id;
    _ownerId = _readHomeRepositoryOwner(repository) ?? _deliveredOwnerId;
    final binding = ++_homeAuthBinding;
    if (client == null) return;
    _authSubscription = client.auth.onAuthStateChange.listen(
      (state) {
        if (!mounted || binding != _homeAuthBinding) return;
        final nextOwner = state.session?.user.id;
        final changed = nextOwner != _deliveredOwnerId;
        _deliveredOwnerId = nextOwner;
        if (!changed) return;
        _invalidateHomeVisit();
        final currentSdkOwner = client.auth.currentUser?.id;
        _setHomeState(() {
          _ownerId = nextOwner;
          if (widget.repository == null) {
            _repository = nextOwner != null && currentSdkOwner == nextOwner
                ? CommunityRepository(client)
                : null;
          } else {
            _repository = widget.repository;
          }
          final rebound = _repository;
          _profilePreview =
              rebound != null &&
                  nextOwner != null &&
                  _readHomeRepositoryOwner(rebound) == nextOwner
              ? rebound.loadMyProfileOverview()
              : null;
          // A delivered owner transition always discards the old feed state.
          // This is deliberately epoch-based so queued A -> B -> A can never
          // reactivate callbacks captured by the first A visit.
          _feedKey = GlobalKey<_FeedTabState>();
        });
      },
      onError: (Object _, StackTrace _) {
        // Token refresh failures are not proof of a different account.
      },
    );
  }

  _CommunityHomeVisit? _captureHomeVisit(CommunityRepository repository) {
    final owner = _ownerId ?? _readHomeRepositoryOwner(repository);
    if (owner == null) return null;
    final epoch = _homeVisitEpoch;
    bool current() {
      if (!mounted ||
          epoch != _homeVisitEpoch ||
          !identical(repository, _repository) ||
          owner != _ownerId) {
        return false;
      }
      return _readHomeRepositoryOwner(repository) == owner;
    }

    final visit = _CommunityHomeVisit(
      repository: repository,
      ownerId: owner,
      epoch: epoch,
      isCurrent: current,
      changes: _homeOwnerChanges,
    );
    return visit.isCurrent() ? visit : null;
  }
}
