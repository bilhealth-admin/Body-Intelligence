part of 'community_hub_page.dart';

/// Captures the viewer, repository and target belonging to one profile visit.
/// Nested sheets retain this same visit even when a new profile is rendered.
class _CommunityProfileVisit {
  const _CommunityProfileVisit({
    required this.repository,
    required this.ownerId,
    required this.targetId,
    required this.isCurrent,
    required this.changes,
  });

  final CommunityRepository repository;
  final String ownerId;
  final String targetId;
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

extension _CommunityMemberProfileOwnerScope
    on _CommunityMemberProfilePageState {
  bool get _sameProfileOwner {
    try {
      return mounted &&
          !_profileOwnerCancelled &&
          _profileOwnerId != null &&
          _profileTargetId == widget.userId &&
          _repository?.currentUserId == _profileOwnerId;
    } on Object {
      return false;
    }
  }

  void _bindProfileOwner() {
    _repository = widget.repository ?? _communityProfileProductionRepository();
    _profileOwnerId = _repository == null
        ? null
        : _communityDraftOwnerId(_repository!);
    _profileTargetId = widget.userId;
    _profileOwnerCancelled = false;
    final binding = ++_profileBinding;
    final auth = _repository?.communitySocialClient.auth;
    if (auth == null) return;
    var deliveredOwner = auth.currentUser?.id;
    _profileAuth = auth.onAuthStateChange.listen(
      (state) {
        if (!mounted || binding != _profileBinding) return;
        final next = state.session?.user.id;
        final changed = next != deliveredOwner;
        deliveredOwner = next;
        // The delivered event detects queued A -> B -> A, even when the SDK's
        // current session already points to A again before B is delivered.
        if (changed || !_sameProfileOwner) _invalidateProfileOwner();
      },
      onError: (Object _, StackTrace _) {
        // An offline token refresh is not proof of a different account.
      },
    );
  }

  void _notifyProfileVisitChanged({bool dispose = false}) {
    // A target replacement can occur during the parent's build. Notify sibling
    // modal routes after that synchronous frame work, while checks invalidate
    // their callbacks immediately through the binding generation.
    scheduleMicrotask(() {
      if (_profileSignalDisposed) return;
      _profileOwnerChanges.value++;
      if (dispose) {
        _profileSignalDisposed = true;
        _profileOwnerChanges.dispose();
      }
    });
  }

  void _endProfileVisit({bool dispose = false}) {
    _profileOwnerCancelled = true;
    _profileBinding++;
    _loadGeneration++;
    unawaited(_profileAuth?.cancel());
    _profileAuth = null;
    _profile = null;
    _creator = null;
    _goldBalance = null;
    _quests = const [];
    _coverUrl = null;
    _posts.clear();
    _reviews.clear();
    _draftSummaries.clear();
    _viewCounts.clear();
    _referenceByPost.clear();
    _before = null;
    _beforeId = null;
    _reviewBefore = null;
    _reviewBeforeId = null;
    _hasMore = false;
    _reviewHasMore = false;
    _loadingMore = false;
    _loadingMoreReviews = false;
    _refreshing = false;
    _relationshipBusy = false;
    _followBusy = false;
    _managingPost = false;
    _notifyProfileVisitChanged(dispose: dispose);
  }

  void _invalidateProfileOwner() {
    if (_profileOwnerCancelled) return;
    _endProfileVisit();
    if (mounted) _setProfileState(() {});
  }

  _CommunityProfileVisit? _captureProfileVisit() {
    if (!_sameProfileOwner) return null;
    final binding = _profileBinding;
    final repository = _repository!;
    final target = _profileTargetId!;
    return _CommunityProfileVisit(
      repository: repository,
      ownerId: _profileOwnerId!,
      targetId: target,
      changes: _profileOwnerChanges,
      isCurrent: () =>
          _sameProfileOwner &&
          binding == _profileBinding &&
          identical(repository, _repository) &&
          target == widget.userId,
    );
  }
}

class _CommunityProfileOwnerChangedBody extends StatelessWidget {
  const _CommunityProfileOwnerChangedBody();

  @override
  Widget build(BuildContext context) => Center(
    key: const Key('community-profile-owner-changed'),
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Text(
        communityText(
          context,
          'Your account changed. Return to Community to continue.',
          'تغير الحساب. ارجع إلى المجتمع للمتابعة.',
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
