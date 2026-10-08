part of 'community_hub_page.dart';

mixin _CommunityFeedPaginationMixin on State<_FeedTab> {
  bool get _loadingMore;
  set _loadingMore(bool value);
  bool get _hasMore;
  set _hasMore(bool value);
  set _feed(Future<List<CommunityPost>> value);
  int get _feedGeneration;
  set _feedGeneration(int value);
  bool get _feedRefreshing;
  set _feedRefreshing(bool value);
  Map<String, CommunityPostReferenceMetadata> get _referenceByPost;
  Map<String, int> get _viewCountByPost;
  Map<String, CommunityComment> get _commentPreviewByPost;
  Map<String, String> get _membershipTierByAuthor;
  CommunityFeedMode get _selectedFeedMode;
  int? get _feedCursorPriority;
  set _feedCursorPriority(int? value);
  DateTime? get _feedCursorCreatedAt;
  set _feedCursorCreatedAt(DateTime? value);
  String? get _feedCursorPostId;
  set _feedCursorPostId(String? value);
  _CommunityFeedVisit? _captureFeedVisit();

  Future<List<CommunityPost>> _loadFirst() async {
    final visit = _captureFeedVisit();
    if (visit == null) return const <CommunityPost>[];
    final repository = visit.repository;
    repository.invalidateCommunityModeratorStatus();
    final generation = ++_feedGeneration;
    _feedRefreshing = true;
    _loadingMore = false;
    _feedCursorPriority = null;
    _feedCursorCreatedAt = null;
    _feedCursorPostId = null;
    try {
      late CommunityFeedModeBatch page;
      await visit.run(() async {
        page = await repository
            .loadCommunityFeedMode(
              mode: _selectedFeedMode,
              limit: _FeedTabState._pageSize,
            )
            .timeout(const Duration(seconds: 15));
        visit.check();
        final ids = page.posts.map((post) => post.id).toList(growable: false);
        final authorIds = page.posts
            .map((post) => post.authorId)
            .toSet()
            .toList(growable: false);
        final List<CommunityPostReferenceMetadata> references;
        final Map<String, int> viewCounts;
        final Map<String, CommunityComment> commentPreviews;
        final Map<String, String> membershipTiers;
        if (repository.useServerCommunityReferenceParity && ids.isNotEmpty) {
          final extras = await Future.wait<Object>([
            repository.loadCommunityPostReferenceMetadata(ids),
            repository.loadCommunityPostViewCounts(ids),
            repository.loadCommunityFeedCommentPreviews(ids),
            repository.loadVisibleMembershipTiers(authorIds),
          ]);
          visit.check();
          references = extras[0] as List<CommunityPostReferenceMetadata>;
          viewCounts = extras[1] as Map<String, int>;
          commentPreviews = extras[2] as Map<String, CommunityComment>;
          membershipTiers = extras[3] as Map<String, String>;
        } else {
          references = const <CommunityPostReferenceMetadata>[];
          viewCounts = const <String, int>{};
          commentPreviews = const <String, CommunityComment>{};
          membershipTiers = const <String, String>{};
        }
        visit.check();
        if (generation != _feedGeneration) return;
        _referenceByPost
          ..clear()
          ..addEntries(
            references.map((value) => MapEntry(value.postId, value)),
          );
        _viewCountByPost
          ..clear()
          ..addAll(viewCounts);
        _commentPreviewByPost
          ..clear()
          ..addAll(commentPreviews);
        _membershipTierByAuthor
          ..clear()
          ..addAll(membershipTiers);
        _hasMore = page.hasMore;
        _feedCursorPriority = page.nextPriority;
        _feedCursorCreatedAt = page.nextBefore;
        _feedCursorPostId = page.nextBeforeId;
      });
      visit.check();
      return page.posts;
    } on CommunityOwnerOperationCancelled {
      return const <CommunityPost>[];
    } finally {
      if (visit.isCurrent() && generation == _feedGeneration) {
        _feedRefreshing = false;
      }
    }
  }

  Future<void> _loadMore(List<CommunityPost> visiblePosts) async {
    final visit = _captureFeedVisit();
    if (visit == null ||
        _loadingMore ||
        _feedRefreshing ||
        !_hasMore ||
        visiblePosts.isEmpty ||
        _feedCursorPriority == null ||
        _feedCursorCreatedAt == null ||
        _feedCursorPostId == null) {
      return;
    }
    final repository = visit.repository;
    final generation = _feedGeneration;
    setState(() => _loadingMore = true);
    try {
      await visit.run(() async {
        final page = await repository.loadCommunityFeedMode(
          mode: _selectedFeedMode,
          beforePriority: _feedCursorPriority,
          before: _feedCursorCreatedAt,
          beforeId: _feedCursorPostId,
          limit: _FeedTabState._pageSize,
        );
        visit.check();
        final ids = page.posts.map((post) => post.id).toList(growable: false);
        final authorIds = page.posts
            .map((post) => post.authorId)
            .toSet()
            .toList(growable: false);
        final List<CommunityPostReferenceMetadata> references;
        final Map<String, int> viewCounts;
        final Map<String, CommunityComment> commentPreviews;
        final Map<String, String> membershipTiers;
        if (repository.useServerCommunityReferenceParity && ids.isNotEmpty) {
          final extras = await Future.wait<Object>([
            repository.loadCommunityPostReferenceMetadata(ids),
            repository.loadCommunityPostViewCounts(ids),
            repository.loadCommunityFeedCommentPreviews(ids),
            repository.loadVisibleMembershipTiers(authorIds),
          ]);
          visit.check();
          references = extras[0] as List<CommunityPostReferenceMetadata>;
          viewCounts = extras[1] as Map<String, int>;
          commentPreviews = extras[2] as Map<String, CommunityComment>;
          membershipTiers = extras[3] as Map<String, String>;
        } else {
          references = const <CommunityPostReferenceMetadata>[];
          viewCounts = const <String, int>{};
          commentPreviews = const <String, CommunityComment>{};
          membershipTiers = const <String, String>{};
        }
        visit.check();
        if (generation != _feedGeneration) return;
        final known = visiblePosts.map((post) => post.id).toSet();
        final combined = [
          ...visiblePosts,
          ...page.posts.where((post) => known.add(post.id)),
        ];
        setState(() {
          _referenceByPost.addEntries(
            references.map((value) => MapEntry(value.postId, value)),
          );
          _viewCountByPost.addAll(viewCounts);
          _commentPreviewByPost.addAll(commentPreviews);
          _membershipTierByAuthor.addAll(membershipTiers);
          _feed = Future.value(combined);
          _hasMore = page.hasMore;
          _feedCursorPriority = page.nextPriority;
          _feedCursorCreatedAt = page.nextBefore;
          _feedCursorPostId = page.nextBeforeId;
        });
      });
    } on CommunityOwnerOperationCancelled {
      // An old owner/page cannot append into the current feed.
    } catch (_) {
      if (!mounted || !visit.isCurrent() || generation != _feedGeneration) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not load older posts. Try again.',
              'تعذر تحميل المنشورات الأقدم. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (visit.isCurrent() && generation == _feedGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }
}
