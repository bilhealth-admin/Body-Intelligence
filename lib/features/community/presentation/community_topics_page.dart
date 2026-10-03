part of 'community_hub_page.dart';

class CommunityTopicsPage extends StatefulWidget {
  const CommunityTopicsPage({
    required this.repository,
    this.onComposeTopic,
    super.key,
  });

  final CommunityRepository repository;
  final Future<void> Function(String slug)? onComposeTopic;

  @override
  State<CommunityTopicsPage> createState() => _CommunityTopicsPageState();
}

class _CommunityTopicsPageState extends State<CommunityTopicsPage> {
  late Future<List<CommunityTopic>> _topics =
      widget.repository.loadCommunityTopics();
  final Set<String> _busy = <String>{};

  Future<void> _refresh() async {
    final future = widget.repository.loadCommunityTopics();
    setState(() => _topics = future);
    try {
      await future;
    } on Object {
      // FutureBuilder owns the retry presentation.
    }
  }

  Future<void> _toggleFollow(CommunityTopic topic) async {
    if (!_busy.add(topic.slug)) return;
    try {
      final following = await widget.repository.followCommunityTopic(
        slug: topic.slug,
        follow: !topic.following,
      );
      if (!mounted) return;
      final current = await _topics;
      if (!mounted) return;
      setState(() {
        _topics = Future.value(
          current
              .map(
                (value) => value.slug == topic.slug
                    ? value.copyWith(
                        following: following,
                        followerCount:
                            (value.followerCount + (following ? 1 : -1))
                                .clamp(0, 1 << 30),
                      )
                    : value,
              )
              .toList(growable: false),
        );
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Could not update this topic. Try again.',
                'تعذر تحديث هذا الموضوع. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
    } finally {
      _busy.remove(topic.slug);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            communityText(context, 'Community topics', 'مواضيع المجتمع'),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<CommunityTopic>>(
            future: _topics,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 160),
                    Center(
                      child: FilledButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          communityText(context, 'Retry', 'إعادة المحاولة'),
                        ),
                      ),
                    ),
                  ],
                );
              }

              final topics = snapshot.data ?? const <CommunityTopic>[];
              return ListView.separated(
                key: const Key('community-topics-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: topics.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  final title = CommunityTaxonomySheet.titleForSlug(
                    context,
                    topic.slug,
                  );
                  final description = CommunityTaxonomySheet.descriptionForSlug(
                    context,
                    topic.slug,
                  );
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => pushCommunityPage<void>(
                        context,
                        _CommunityTopicPage(
                          repository: widget.repository,
                          topic: topic,
                          onComposeTopic: widget.onComposeTopic,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                BilSemanticIconBadge(
                                  kind: BilSemanticIconKind.community,
                                  iconOverride:
                                      CommunityTaxonomySheet.iconForSlug(
                                    topic.slug,
                                  ),
                                  appleIconOverride:
                                      CommunityTaxonomySheet.iconForSlug(
                                    topic.slug,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w800,
                                                  ),
                                            ),
                                          ),
                                          if (topic.featured)
                                            const Icon(
                                              Icons.auto_awesome_rounded,
                                              size: 18,
                                            ),
                                        ],
                                      ),
                                      if (description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _TopicMetric(
                                  icon: Icons.article_outlined,
                                  value: topic.postCount,
                                  label: communityText(
                                    context,
                                    'posts',
                                    'منشورات',
                                  ),
                                ),
                                _TopicMetric(
                                  icon: Icons.people_outline_rounded,
                                  value: topic.followerCount,
                                  label: communityText(
                                    context,
                                    'followers',
                                    'متابعون',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  key: Key(
                                    'community-topic-follow-${topic.slug}',
                                  ),
                                  onPressed: _busy.contains(topic.slug)
                                      ? null
                                      : () => _toggleFollow(topic),
                                  icon: Icon(
                                    topic.following
                                        ? Icons.check_rounded
                                        : Icons.add_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    topic.following
                                        ? communityText(
                                            context,
                                            'Following',
                                            'متابَع',
                                          )
                                        : communityText(
                                            context,
                                            'Follow',
                                            'متابعة',
                                          ),
                                  ),
                                ),
                                if (widget.onComposeTopic != null)
                                  IconButton.filledTonal(
                                    tooltip: communityText(
                                      context,
                                      'Start a post',
                                      'ابدأ منشورًا',
                                    ),
                                    onPressed: () =>
                                        widget.onComposeTopic!(topic.slug),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
}

class _CommunityTopicPage extends StatefulWidget {
  const _CommunityTopicPage({
    required this.repository,
    required this.topic,
    this.onComposeTopic,
  });

  final CommunityRepository repository;
  final CommunityTopic topic;
  final Future<void> Function(String slug)? onComposeTopic;

  @override
  State<_CommunityTopicPage> createState() => _CommunityTopicPageState();
}

class _CommunityTopicPageState extends State<_CommunityTopicPage> {
  static const _pageSize = 30;

  final List<CommunityPost> _posts = <CommunityPost>[];
  late Future<void> _loading = _loadFirst();
  DateTime? _before;
  String? _beforeId;
  bool _hasMore = false;
  bool _loadingMore = false;

  Future<void> _loadFirst() async {
    final page = await widget.repository.loadCommunityTopicPosts(
      slug: widget.topic.slug,
      limit: _pageSize,
    );
    _posts
      ..clear()
      ..addAll(page.posts);
    _before = page.nextBefore;
    _beforeId = page.nextBeforeId;
    _hasMore = page.hasMore;
  }

  Future<void> _refresh() async {
    final future = _loadFirst();
    setState(() => _loading = future);
    try {
      await future;
    } on Object {
      // FutureBuilder owns the retry state.
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _before == null || _beforeId == null) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final page = await widget.repository.loadCommunityTopicPosts(
        slug: widget.topic.slug,
        before: _before,
        beforeId: _beforeId,
        limit: _pageSize,
      );
      if (!mounted) return;
      final known = _posts.map((post) => post.id).toSet();
      setState(() {
        _posts.addAll(page.posts.where((post) => known.add(post.id)));
        _before = page.nextBefore;
        _beforeId = page.nextBeforeId;
        _hasMore = page.hasMore;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = CommunityTaxonomySheet.titleForSlug(
      context,
      widget.topic.slug,
    );
    final description = CommunityTaxonomySheet.descriptionForSlug(
      context,
      widget.topic.slug,
    );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: widget.onComposeTopic == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => widget.onComposeTopic!(widget.topic.slug),
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                communityText(context, 'New post', 'منشور جديد'),
              ),
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
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  communityText(context, 'Retry', 'إعادة المحاولة'),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${widget.topic.slug}',
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(description),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_posts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          communityText(
                            context,
                            'No approved posts in this topic yet.',
                            'لا توجد منشورات معتمدة في هذا الموضوع بعد.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: .82,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _CommunityProfilePostTile(
                          post: _posts[index],
                          repository: widget.repository,
                        ),
                        childCount: _posts.length,
                      ),
                    ),
                  ),
                if (_hasMore)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextButton.icon(
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
                            communityText(
                              context,
                              'Load more',
                              'تحميل المزيد',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TopicMetric extends StatelessWidget {
  const _TopicMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 16),
        label: Text('$value $label'),
      );
}
