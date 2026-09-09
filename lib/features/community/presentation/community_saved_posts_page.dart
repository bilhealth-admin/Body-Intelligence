part of 'community_hub_page.dart';

class CommunitySavedPostsPage extends StatefulWidget {
  const CommunitySavedPostsPage({required this.repository, super.key});

  final CommunityRepository repository;

  @override
  State<CommunitySavedPostsPage> createState() =>
      _CommunitySavedPostsPageState();
}

class _CommunitySavedPostsPageState extends State<CommunitySavedPostsPage> {
  static const _pageSize = 30;
  final List<CommunityPost> _posts = [];
  late Future<void> _loading = _loadInitial();
  DateTime? _before;
  String? _beforeId;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _managing = false;

  Future<void> _loadInitial() async {
    final batch = await widget.repository.loadSavedPosts(limit: _pageSize);
    _posts
      ..clear()
      ..addAll(batch.posts);
    _before = batch.nextBefore;
    _beforeId = batch.nextBeforeId;
    _hasMore = batch.hasMore;
  }

  Future<void> _refresh() async {
    final future = _loadInitial();
    setState(() => _loading = future);
    try {
      await future;
    } on Object {
      // FutureBuilder keeps the error and retry action visible.
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _before == null || _beforeId == null) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final batch = await widget.repository.loadSavedPosts(
        before: _before,
        beforeId: _beforeId,
        limit: _pageSize,
      );
      if (!mounted) return;
      final known = _posts.map((post) => post.id).toSet();
      setState(() {
        _posts.addAll(batch.posts.where((post) => known.add(post.id)));
        _before = batch.nextBefore;
        _beforeId = batch.nextBeforeId;
        _hasMore = batch.hasMore;
      });
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _managePost(CommunityPost post, String action) async {
    if (_managing) return;
    setState(() => _managing = true);
    try {
      if (action == 'delete') {
        await widget.repository.deletePost(post.id);
      } else if (action == 'report') {
        await widget.repository.report(
          targetKind: 'post',
          targetId: post.id,
          reason: 'user_reported_from_saved_posts',
        );
      } else if (action == 'block') {
        await widget.repository.blockMember(post.authorId);
      }
      if (mounted && action != 'report') await _refresh();
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _managing = false);
    }
  }

  void _showFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          communityText(
            context,
            'Could not complete that action safely. Try again.',
            'تعذر تنفيذ الإجراء بأمان. حاول مجددًا.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(communityText(context, 'Saved posts', 'المحفوظات')),
    ),
    body: FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            _posts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && _posts.isEmpty) {
          return Center(
            child: FilledButton.icon(
              key: const Key('community-saved-retry'),
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: _posts.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(32),
                  children: [
                    const SizedBox(height: 100),
                    const Icon(Icons.bookmark_border_rounded, size: 52),
                    const SizedBox(height: 16),
                    Text(
                      communityText(
                        context,
                        'Posts you save are private and appear here.',
                        'المنشورات التي تحفظها خاصة وتظهر هنا.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.builder(
                  key: const Key('community-saved-list'),
                  padding: const EdgeInsets.all(16),
                  itemCount: _posts.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _posts.length) {
                      return Center(
                        child: TextButton.icon(
                          key: const Key('community-saved-load-more'),
                          onPressed: _loadingMore ? null : _loadMore,
                          icon: _loadingMore
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.expand_more_rounded),
                          label: Text(
                            communityText(context, 'Load more', 'تحميل المزيد'),
                          ),
                        ),
                      );
                    }
                    final post = _posts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _CommunityPostCard(
                        post: post,
                        repository: widget.repository,
                        currentUserId: widget.repository.currentUserId,
                        actionsEnabled: !_managing,
                        onAction: (action) => _managePost(post, action),
                        onSavedChanged: (saved) {
                          if (!saved && mounted) {
                            setState(
                              () => _posts.removeWhere(
                                (item) => item.id == post.id,
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
        );
      },
    ),
  );
}
