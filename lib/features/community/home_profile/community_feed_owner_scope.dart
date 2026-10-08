part of '../presentation/community_hub_page.dart';

class _CommunityFeedVisit {
  const _CommunityFeedVisit({
    required this.repository,
    required this.ownerId,
    required this.isCurrent,
    this.changes,
  });

  final CommunityRepository repository;
  final String ownerId;
  final ValueGetter<bool> isCurrent;
  final Listenable? changes;

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

  Widget guard(Widget child) {
    final listenable = changes;
    if (listenable == null) {
      return Builder(
        builder: (_) =>
            isCurrent() ? child : const _CommunityProfileOwnerChangedBody(),
      );
    }
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) =>
          isCurrent() ? child : const _CommunityProfileOwnerChangedBody(),
    );
  }
}

_CommunityFeedVisit? _captureCommunityFeedVisit(_FeedTabState state) {
  final repository = state.widget.repository;
  final ownerId = _communityDraftOwnerId(repository);
  final parentVisit = state.widget.ownerIsCurrent;
  if (ownerId == null) return null;
  bool current() {
    if (!state.mounted ||
        !identical(repository, state.widget.repository) ||
        !(parentVisit?.call() ?? true)) {
      return false;
    }
    try {
      return repository.currentUserId == ownerId;
    } on Object {
      return false;
    }
  }

  final visit = _CommunityFeedVisit(
    repository: repository,
    ownerId: ownerId,
    isCurrent: current,
    changes: state.widget.ownerChanges,
  );
  return visit.isCurrent() ? visit : null;
}
