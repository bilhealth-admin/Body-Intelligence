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

  Future<List<CommunityPost>> _loadFirst() async {
    widget.repository.invalidateCommunityModeratorStatus();
    final generation = ++_feedGeneration;
    _feedRefreshing = true;
    _loadingMore = false;
    _feedCursorPriority = null;
    _feedCursorCreatedAt = null;
    _feedCursorPostId = null;
    try {
      final page = await widget.repository
          .loadCommunityFeedMode(
            mode: _selectedFeedMode,
            limit: _FeedTabState._pageSize,
          )
          .timeout(const Duration(seconds: 15));
      final ids = page.posts.map((post) => post.id).toList(growable: false);
      final authorIds = page.posts
          .map((post) => post.authorId)
          .toSet()
          .toList(growable: false);
      final List<CommunityPostReferenceMetadata> references;
      final Map<String, int> viewCounts;
      final Map<String, CommunityComment> commentPreviews;
      final Map<String, String> membershipTiers;
      if (widget.repository.useServerCommunityReferenceParity &&
          ids.isNotEmpty) {
        final extras = await Future.wait<Object>([
          widget.repository.loadCommunityPostReferenceMetadata(ids),
          widget.repository.loadCommunityPostViewCounts(ids),
          widget.repository.loadCommunityFeedCommentPreviews(ids),
          widget.repository.loadVisibleMembershipTiers(authorIds),
        ]);
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
      if (mounted && generation == _feedGeneration) {
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
      }
      return page.posts;
    } finally {
      if (generation == _feedGeneration) _feedRefreshing = false;
    }
  }

  Future<void> _loadMore(List<CommunityPost> visiblePosts) async {
    if (_loadingMore ||
        _feedRefreshing ||
        !_hasMore ||
        visiblePosts.isEmpty ||
        _feedCursorPriority == null ||
        _feedCursorCreatedAt == null ||
        _feedCursorPostId == null) {
      return;
    }
    final generation = _feedGeneration;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.repository.loadCommunityFeedMode(
        mode: _selectedFeedMode,
        beforePriority: _feedCursorPriority,
        before: _feedCursorCreatedAt,
        beforeId: _feedCursorPostId,
        limit: _FeedTabState._pageSize,
      );
      final ids = page.posts.map((post) => post.id).toList(growable: false);
      final authorIds = page.posts
          .map((post) => post.authorId)
          .toSet()
          .toList(growable: false);
      final List<CommunityPostReferenceMetadata> references;
      final Map<String, int> viewCounts;
      final Map<String, CommunityComment> commentPreviews;
      final Map<String, String> membershipTiers;
      if (widget.repository.useServerCommunityReferenceParity &&
          ids.isNotEmpty) {
        final extras = await Future.wait<Object>([
          widget.repository.loadCommunityPostReferenceMetadata(ids),
          widget.repository.loadCommunityPostViewCounts(ids),
          widget.repository.loadCommunityFeedCommentPreviews(ids),
          widget.repository.loadVisibleMembershipTiers(authorIds),
        ]);
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
      if (!mounted || generation != _feedGeneration) return;
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
    } catch (_) {
      if (!mounted || generation != _feedGeneration) return;
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
      if (mounted && generation == _feedGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }
}
