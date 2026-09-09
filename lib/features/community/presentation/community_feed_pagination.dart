part of 'community_hub_page.dart';

mixin _CommunityFeedPaginationMixin on State<_FeedTab> {
  bool get _loadingMore;
  set _loadingMore(bool value);
  bool get _hasMore;
  set _hasMore(bool value);
  set _feed(Future<List<CommunityPost>> value);

  Future<List<CommunityPost>> _loadFirst() async {
    final posts = await widget.repository.loadFeed(
      limit: _FeedTabState._pageSize,
    );
    _hasMore = posts.length == _FeedTabState._pageSize;
    return posts;
  }

  Future<void> _loadMore(List<CommunityPost> visiblePosts) async {
    if (_loadingMore || !_hasMore || visiblePosts.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final cursor = visiblePosts.last;
      final page = await widget.repository.loadOlderFeed(
        before: cursor.createdAt,
        beforeId: cursor.id,
        limit: _FeedTabState._pageSize,
      );
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (mounted) setState(() => _loadingMore = false);
    }
  }
}
