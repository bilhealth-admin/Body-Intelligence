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

  Future<List<CommunityPost>> _loadFirst() async {
    final generation = ++_feedGeneration;
    _feedRefreshing = true;
    _loadingMore = false;
    try {
      final posts = await widget.repository.loadFeed(
        limit: _FeedTabState._pageSize,
      );
      if (mounted && generation == _feedGeneration) {
        _hasMore = posts.length == _FeedTabState._pageSize;
      }
      return posts;
    } finally {
      if (generation == _feedGeneration) _feedRefreshing = false;
    }
  }

  Future<void> _loadMore(List<CommunityPost> visiblePosts) async {
    if (_loadingMore || _feedRefreshing || !_hasMore || visiblePosts.isEmpty) {
      return;
    }
    final generation = _feedGeneration;
    setState(() => _loadingMore = true);
    try {
      final cursor = visiblePosts.last;
      final page = await widget.repository.loadOlderFeed(
        before: cursor.createdAt,
        beforeId: cursor.id,
        limit: _FeedTabState._pageSize,
      );
      if (!mounted || generation != _feedGeneration) return;
      final known = visiblePosts.map((post) => post.id).toSet();
      final combined = [
        ...visiblePosts,
        ...page.posts.where((post) => known.add(post.id)),
      ];
      setState(() {
        _feed = Future.value(combined);
        _hasMore = page.hasMore;
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
