part of 'community_hub_page.dart';

/// A category keeps the surrounding feed and navigation in place. Each read
/// belongs to one owner, topic and generation, including pagination and retry.
class _CommunityInlineTopicFeed extends StatefulWidget {
  const _CommunityInlineTopicFeed({
    super.key,
    required this.topic,
    required this.visit,
    required this.metadata,
    required this.identities,
    required this.viewCounts,
    required this.previews,
    required this.tiers,
    required this.actionsEnabled,
    required this.onPostsLoaded,
    required this.onAction,
    required this.onMutation,
  });
  final CommunityTopic topic;
  final _CommunityFeedVisit visit;
  final Map<String, CommunityPostReferenceMetadata> metadata;
  final Map<String, CommunityPostAuthorIdentity> identities;
  final Map<String, int> viewCounts;
  final Map<String, CommunityComment> previews;
  final Map<String, String> tiers;
  final bool actionsEnabled;
  final ValueChanged<List<CommunityPost>> onPostsLoaded;
  final VoidCallback onMutation;
  final Future<void> Function(CommunityPost, String) onAction;

  @override
  State<_CommunityInlineTopicFeed> createState() =>
      _CommunityInlineTopicFeedState();
}

class _CommunityInlineTopicFeedState extends State<_CommunityInlineTopicFeed> {
  late Future<void> _loading;
  final _posts = <CommunityPost>[];
  int _generation = 0;
  bool _hasMore = false, _loadingMore = false, _refreshing = false;
  DateTime? _before;
  String? _beforeId;

  @override
  void initState() {
    super.initState();
    _loading = _read();
  }

  @override
  void didUpdateWidget(covariant _CommunityInlineTopicFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topic.slug != widget.topic.slug ||
        oldWidget.visit.ownerId != widget.visit.ownerId ||
        !identical(oldWidget.visit.repository, widget.visit.repository)) {
      _posts.clear();
      _hasMore = false;
      _before = null;
      _beforeId = null;
      _loading = _read();
    }
  }

  bool _current(_CommunityFeedVisit visit, int generation, String slug) =>
      mounted &&
      visit.isCurrent() &&
      generation == _generation &&
      widget.topic.slug == slug;

  Future<void> _read({bool append = false}) async {
    final visit = widget.visit;
    final slug = widget.topic.slug;
    final generation = ++_generation;
    _refreshing = !append;
    _loadingMore = append;
    try {
      final page = await visit.run(
        () => visit.repository.loadCommunityTopicPosts(
          slug: slug,
          before: append ? _before : null,
          beforeId: append ? _beforeId : null,
          limit: 30,
        ),
      );
      if (!_current(visit, generation, slug)) return;
      if (page.hasMore &&
          (page.nextBefore == null || page.nextBeforeId == null)) {
        throw const FormatException('Missing Community category cursor');
      }
      setState(() {
        if (!append) _posts.clear();
        final seen = _posts.map((post) => post.id).toSet();
        _posts.addAll(page.posts.where((post) => seen.add(post.id)));
        _hasMore = page.hasMore;
        _before = page.nextBefore;
        _beforeId = page.nextBeforeId;
      });
      widget.onPostsLoaded(page.posts);
    } on CommunityOwnerOperationCancelled {
      // A retired account/topic cannot populate its successor.
    } finally {
      if (_current(visit, generation, slug)) {
        setState(() {
          _refreshing = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> refresh() async {
    if (!widget.visit.isCurrent()) return;
    final loading = _read();
    setState(() {
      _loading = loading;
    });
    try {
      await loading;
    } on Object {
      // The FutureBuilder owns this category's error/retry presentation.
    }
  }

  Future<void> _more() async {
    if (_loadingMore || _refreshing || !_hasMore || !widget.visit.isCurrent()) {
      return;
    }
    final visit = widget.visit;
    final slug = widget.topic.slug;
    final loading = _read(append: true);
    final generation = _generation;
    setState(() {});
    try {
      await loading;
    } on Object {
      if (!_current(visit, generation, slug)) return;
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
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _loading,
    builder: (context, snapshot) {
      if (!widget.visit.isCurrent()) {
        return const SliverToBoxAdapter(
          child: _CommunityProfileOwnerChangedBody(),
        );
      }
      if (snapshot.connectionState != ConnectionState.done && _posts.isEmpty) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: BilFeatureWelcomeStatus()),
          ),
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index == 0) {
              return SizedBox(
                height: _refreshing ? 24 : 3,
                child: _refreshing
                    ? const BilFeatureWelcomeStatus()
                    : const SizedBox.shrink(),
              );
            }
            if (index <= _posts.length) {
              final source = _posts[index - 1];
              final post =
                  widget.identities[source.authorId]?.applyTo(source) ?? source;
              return Padding(
                key: ValueKey('community-category-post-${post.id}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: _CommunityPostCard(
                  post: post,
                  repository: widget.visit.repository,
                  currentUserId: widget.visit.ownerId,
                  actionsEnabled: widget.actionsEnabled,
                  ownerIsCurrent: widget.visit.isCurrent,
                  ownerChanges: widget.visit.changes,
                  referenceMetadata: widget.metadata[post.id],
                  viewCount: widget.viewCounts[post.id],
                  commentPreview: widget.previews[post.id],
                  authorMembershipTier: widget.tiers[post.authorId],
                  onMutation: widget.onMutation,
                  onAction: (action) =>
                      unawaited(widget.onAction(post, action)),
                ),
              );
            }
            if (snapshot.hasError) return _InlineError(onRetry: refresh);
            if (_posts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  communityText(
                    context,
                    'No approved posts in this topic yet.',
                    'لا توجد منشورات معتمدة في هذا الموضوع بعد.',
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return _hasMore
                ? Center(
                    child: TextButton.icon(
                      key: const Key('community-category-load-more'),
                      onPressed: _loadingMore || _refreshing ? null : _more,
                      icon: _loadingMore
                          ? const SizedBox.square(
                              dimension: 16,
                              child: BilFeatureWelcomeStatus(),
                            )
                          : const BilCrystalArrow(
                              extent: 36,
                              child: Icon(Icons.expand_more_rounded),
                            ),
                      label: Text(
                        communityText(
                          context,
                          'Load older posts',
                          'تحميل منشورات أقدم',
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          }, childCount: _posts.length + 2),
        ),
      );
    },
  );
}
