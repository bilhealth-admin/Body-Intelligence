part of 'community_hub_page.dart';

class _CommunityPostOwnerScope {
  _CommunityPostOwnerScope({
    required this.repository,
    required this.isCurrentVisit,
    this.changes,
  }) : ownerId = _communityDraftOwnerId(repository);

  final CommunityRepository repository;
  final String? ownerId;
  final ValueGetter<bool> isCurrentVisit;
  final Listenable? changes;

  bool get isCurrent =>
      isCurrentVisit() && _communityDraftOwnerId(repository) == ownerId;

  void check() {
    if (!isCurrent) throw const CommunityOwnerOperationCancelled();
    CommunityOwnerOperation.checkCurrent();
  }

  Future<T> run<T>(Future<T> Function() action) => CommunityOwnerOperation.run(
    client: repository.communitySocialClient,
    ownerId: ownerId,
    readOwner: () => _communityDraftOwnerId(repository),
    isCurrentOwner: isCurrentVisit,
    action: (_) => action(),
  );

  Widget guard(Widget child, {bool page = false}) {
    Widget render(BuildContext context) {
      if (isCurrent) return child;
      if (!page) return const _CommunityProfileOwnerChangedBody();
      return Scaffold(
        appBar: AppBar(leading: const CommunityReturnButton()),
        body: const _CommunityProfileOwnerChangedBody(),
      );
    }

    final listenable = changes;
    return listenable == null
        ? Builder(builder: render)
        : ListenableBuilder(
            listenable: listenable,
            builder: (context, _) => render(context),
          );
  }
}

extension _CommunityPostCardOwnerScope on _CommunityPostCardState {
  _CommunityPostOwnerScope _captureCardScope() {
    final repository = widget.repository;
    final postId = widget.post.id;
    final viewer = widget.currentUserId;
    final authenticatedOwner = _communityDraftOwnerId(repository);
    final parentVisit = widget.ownerIsCurrent;
    return _CommunityPostOwnerScope(
      repository: repository,
      changes: widget.ownerChanges,
      isCurrentVisit: () =>
          mounted &&
          identical(repository, widget.repository) &&
          postId == widget.post.id &&
          viewer == widget.currentUserId &&
          (authenticatedOwner == null || authenticatedOwner == viewer) &&
          (parentVisit?.call() ?? true),
    );
  }

  Future<void> _runCardOwner(
    Future<void> Function(_CommunityPostOwnerScope scope) action,
  ) async {
    final scope = _captureCardScope();
    try {
      await scope.run(() => action(scope));
    } on CommunityOwnerOperationCancelled {
      // The old card cannot perform a mutation or update a later visit.
    }
  }
}

extension _CommunityPostDetailOwnerScope on _CommunityPostDetailPageState {
  _CommunityPostOwnerScope _captureDetailScope() {
    final repository = widget.repository;
    final postId = widget.post.id;
    final parentVisit = widget.ownerIsCurrent;
    return _CommunityPostOwnerScope(
      repository: repository,
      changes: widget.ownerChanges,
      isCurrentVisit: () =>
          mounted &&
          identical(repository, widget.repository) &&
          postId == widget.post.id &&
          (parentVisit?.call() ?? true),
    );
  }

  bool get _detailOwnerIsCurrent => _detailOwnerScope.isCurrent;

  Future<void> _runDetailOwner(Future<void> Function() action) async {
    try {
      await _detailOwnerScope.run(action);
    } on CommunityOwnerOperationCancelled {
      // This route and its retained dialogs belong to the original visit.
    }
  }
}
