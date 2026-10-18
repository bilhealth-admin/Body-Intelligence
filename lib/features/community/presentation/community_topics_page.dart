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
  late _CommunityTopicOwnerScope _owner;
  late Future<List<CommunityTopic>> _topics;
  final Set<String> _busy = <String>{};
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _bindOwner();
    _topics = _loadTopics(_owner);
  }

  @override
  void didUpdateWidget(covariant CommunityTopicsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _owner.dispose();
      _loadGeneration++;
      _busy.clear();
      _bindOwner();
      _topics = _loadTopics(_owner);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _owner.dispose();
    super.dispose();
  }

  void _bindOwner() {
    late final _CommunityTopicOwnerScope owner;
    owner = _CommunityTopicOwnerScope(
      repository: widget.repository,
      target: 'topics',
      currentVisit: () => mounted && identical(_owner, owner),
      onInvalidated: () {
        if (!mounted || !identical(_owner, owner)) return;
        setState(() {
          _loadGeneration++;
          _busy.clear();
          _topics = Future.value(const <CommunityTopic>[]);
        });
      },
    );
    _owner = owner;
  }

  Future<List<CommunityTopic>> _loadTopics(
    _CommunityTopicOwnerScope visit,
  ) async {
    if (!visit.isCurrent) return const [];
    final generation = ++_loadGeneration;
    try {
      return await visit.run(() async {
        final topics = await visit.repository.loadCommunityTopics();
        visit.check();
        if (generation != _loadGeneration) {
          throw const CommunityOwnerOperationCancelled();
        }
        return topics;
      });
    } on CommunityOwnerOperationCancelled {
      return const [];
    }
  }

  Future<void> _refresh(_CommunityTopicOwnerScope visit) async {
    if (!visit.isCurrent) return;
    final future = _loadTopics(visit);
    setState(() {
      _topics = future;
    });
    try {
      await future;
    } on Object {
      // FutureBuilder owns the retry presentation for this same visit.
    }
  }

  Future<void> _toggleFollow(
    _CommunityTopicOwnerScope visit,
    CommunityTopic topic,
  ) async {
    if (!visit.isCurrent || _busy.contains(topic.slug)) return;
    setState(() {
      _busy.add(topic.slug);
    });
    try {
      await visit.run(() async {
        final following = await visit.repository.followCommunityTopic(
          slug: topic.slug,
          follow: !topic.following,
        );
        visit.check();
        final currentFuture = _topics;
        final current = await currentFuture;
        visit.check();
        if (!identical(_topics, currentFuture)) return;
        setState(() {
          _topics = Future.value(
            current
                .map((value) {
                  if (value.slug != topic.slug ||
                      value.following == following) {
                    return value;
                  }
                  return value.copyWith(
                    following: following,
                    followerCount: following
                        ? value.followerCount + 1
                        : (value.followerCount > 0
                              ? value.followerCount - 1
                              : 0),
                  );
                })
                .toList(growable: false),
          );
        });
      });
    } on CommunityOwnerOperationCancelled {
      // A saved callback cannot acquire a later owner or repaint this page.
    } on Object {
      if (mounted && visit.isCurrent) {
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
      if (visit.isCurrent) {
        setState(() {
          _busy.remove(topic.slug);
        });
      }
    }
  }

  Future<void> _openTopic(
    _CommunityTopicOwnerScope visit,
    CommunityTopic topic,
  ) async {
    if (!visit.isCurrent) return;
    await pushCommunityPage<void>(
      context,
      _CommunityTopicPage(
        repository: visit.repository,
        topic: topic,
        parentVisit: visit,
        onComposeTopic: widget.onComposeTopic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visit = _owner;
    return Scaffold(
      appBar: AppBar(
        leading: const CommunityReturnButton(),
        title: Text(
          communityText(context, 'Community topics', 'مواضيع المجتمع'),
        ),
      ),
      body: !visit.isCurrent
          ? const _CommunityProfileOwnerChangedBody()
          : RefreshIndicator(
              onRefresh: () => _refresh(visit),
              child: FutureBuilder<List<CommunityTopic>>(
                key: ValueKey(visit),
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
                            onPressed: () => _refresh(visit),
                            icon: const BilGlassPressFeedback(
                              child: Icon(Icons.refresh_rounded),
                            ),
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
                      final description =
                          CommunityTaxonomySheet.descriptionForSlug(
                            context,
                            topic.slug,
                          );
                      return BilPearlMaterialCard(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openTopic(visit, topic),
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
                                          : () => _toggleFollow(visit, topic),
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
                                        onPressed: () => _composeFromTopic(
                                          context,
                                          visit,
                                          topic.slug,
                                          widget.onComposeTopic!,
                                        ),
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
}

class _CommunityTopicPage extends StatefulWidget {
  const _CommunityTopicPage({
    required this.repository,
    required this.topic,
    this.parentVisit,
    this.onComposeTopic,
  });

  final CommunityRepository repository;
  final CommunityTopic topic;
  final _CommunityTopicOwnerScope? parentVisit;
  final Future<void> Function(String slug)? onComposeTopic;

  @override
  State<_CommunityTopicPage> createState() => _CommunityTopicPageState();
}

class _CommunityTopicPageState extends State<_CommunityTopicPage> {
  static const _pageSize = 30;

  late _CommunityTopicOwnerScope _owner;
  final List<CommunityPost> _posts = <CommunityPost>[];
  final Map<String, int> _viewCounts = <String, int>{};
  late Future<void> _loading;
  DateTime? _before;
  String? _beforeId;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _refreshing = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _bindOwner();
    _loading = _loadFirst(_owner);
  }

  @override
  void didUpdateWidget(covariant _CommunityTopicPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.topic.slug != widget.topic.slug ||
        !identical(oldWidget.parentVisit, widget.parentVisit)) {
      _owner.dispose();
      _clearRetiredData();
      _bindOwner();
      _loading = _loadFirst(_owner);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _owner.dispose();
    super.dispose();
  }

  void _clearRetiredData() {
    _loadGeneration++;
    _posts.clear();
    _viewCounts.clear();
    _before = null;
    _beforeId = null;
    _hasMore = false;
    _loadingMore = false;
    _refreshing = false;
  }

  void _bindOwner() {
    late final _CommunityTopicOwnerScope owner;
    owner = _CommunityTopicOwnerScope(
      repository: widget.repository,
      target: widget.topic.slug,
      parentVisit: widget.parentVisit,
      currentVisit: () => mounted && identical(_owner, owner),
      onInvalidated: () {
        if (!mounted || !identical(_owner, owner)) return;
        setState(() {
          _clearRetiredData();
          _loading = Future.value();
        });
      },
    );
    _owner = owner;
  }

  Future<void> _loadFirst(_CommunityTopicOwnerScope visit) async {
    if (!visit.isCurrent) return;
    final generation = ++_loadGeneration;
    _refreshing = true;
    _loadingMore = false;
    try {
      await visit.run(() async {
        final page = await visit.repository.loadCommunityTopicPosts(
          slug: visit.target,
          limit: _pageSize,
        );
        visit.check();
        if (generation != _loadGeneration) {
          throw const CommunityOwnerOperationCancelled();
        }
        final counts = await _communityBrowseViewCounts(
          visit.repository,
          page.posts,
        );
        visit.check();
        if (generation != _loadGeneration) {
          throw const CommunityOwnerOperationCancelled();
        }
        _viewCounts
          ..clear()
          ..addAll(counts);
        _posts
          ..clear()
          ..addAll(page.posts);
        _before = page.nextBefore;
        _beforeId = page.nextBeforeId;
        _hasMore = page.hasMore;
      });
    } on CommunityOwnerOperationCancelled {
      // Owner, route and refreshed generation all retire the old continuation.
    } finally {
      if (visit.isCurrent && generation == _loadGeneration) {
        _refreshing = false;
      }
    }
  }

  Future<void> _refresh(_CommunityTopicOwnerScope visit) async {
    if (!visit.isCurrent) return;
    final future = _loadFirst(visit);
    setState(() {
      _loading = future;
    });
    try {
      await future;
    } on Object {
      // FutureBuilder owns the retry state for this same visit.
    }
  }

  Future<void> _loadMore(_CommunityTopicOwnerScope visit) async {
    if (!visit.isCurrent ||
        _loadingMore ||
        _refreshing ||
        !_hasMore ||
        _before == null ||
        _beforeId == null) {
      return;
    }
    final generation = _loadGeneration;
    final before = _before;
    final beforeId = _beforeId;
    setState(() {
      _loadingMore = true;
    });
    try {
      await visit.run(() async {
        final page = await visit.repository.loadCommunityTopicPosts(
          slug: visit.target,
          before: before,
          beforeId: beforeId,
          limit: _pageSize,
        );
        visit.check();
        if (generation != _loadGeneration) {
          throw const CommunityOwnerOperationCancelled();
        }
        final counts = await _communityBrowseViewCounts(
          visit.repository,
          page.posts,
        );
        visit.check();
        if (generation != _loadGeneration) {
          throw const CommunityOwnerOperationCancelled();
        }
        final known = _posts.map((post) => post.id).toSet();
        setState(() {
          _viewCounts.addAll(counts);
          _posts.addAll(page.posts.where((post) => known.add(post.id)));
          _before = page.nextBefore;
          _beforeId = page.nextBeforeId;
          _hasMore = page.hasMore;
        });
      });
    } on CommunityOwnerOperationCancelled {
      // Cancellation never starts optional metrics or a later page.
    } on Object {
      if (mounted && visit.isCurrent && generation == _loadGeneration) {
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
    } finally {
      if (visit.isCurrent && generation == _loadGeneration) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = _owner;
    final title = CommunityTaxonomySheet.titleForSlug(
      context,
      widget.topic.slug,
    );
    final description = CommunityTaxonomySheet.descriptionForSlug(
      context,
      widget.topic.slug,
    );
    return Scaffold(
      appBar: AppBar(
        leading: const CommunityReturnButton(),
        title: Text(title),
      ),
      floatingActionButton: !visit.isCurrent || widget.onComposeTopic == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _composeFromTopic(
                context,
                visit,
                visit.target,
                widget.onComposeTopic!,
              ),
              icon: const Icon(Icons.edit_outlined),
              label: Text(communityText(context, 'New post', 'منشور جديد')),
            ),
      body: !visit.isCurrent
          ? const _CommunityProfileOwnerChangedBody()
          : FutureBuilder<void>(
              key: ValueKey(visit),
              future: _loading,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done &&
                    _posts.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError && _posts.isEmpty) {
                  return Center(
                    child: FilledButton.icon(
                      onPressed: () => _refresh(visit),
                      icon: const BilGlassPressFeedback(
                        child: Icon(Icons.refresh_rounded),
                      ),
                      label: Text(
                        communityText(context, 'Retry', 'إعادة المحاولة'),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => _refresh(visit),
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
                              (context, index) => _postTileForTopic(
                                context,
                                visit,
                                _posts[index],
                                _viewCounts[_posts[index].id],
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
                                onPressed: _loadingMore
                                    ? null
                                    : () => _loadMore(visit),
                                icon: _loadingMore
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const BilGlassPressFeedback(
                                        child: Icon(Icons.expand_more_rounded),
                                      ),
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

/// One browse visit retains its original SDK epoch, repository and target.
/// A nullable owner preserves existing public read behavior; server policy
/// still decides whether an unauthenticated read or action is allowed.
class _CommunityTopicOwnerScope {
  _CommunityTopicOwnerScope({
    required this.repository,
    required this.target,
    required this.currentVisit,
    required this.onInvalidated,
    this.parentVisit,
  }) {
    _account = CommunityAccountVisit(
      repository: repository,
      client: repository.communitySocialClient,
      onChanged: _retire,
    );
    _epoch = _account.epoch;
    _ownerId = _account.owner;
    _ticket = _account.capture();
    parentVisit?.changes.addListener(_parentChanged);
  }

  final CommunityRepository repository;
  final String target;
  final ValueGetter<bool> currentVisit;
  final VoidCallback onInvalidated;
  final _CommunityTopicOwnerScope? parentVisit;
  final ValueNotifier<int> changes = ValueNotifier(0);
  late final CommunityAccountVisit _account;
  late final int _epoch;
  late final String? _ownerId;
  late final CommunityAccountTicket? _ticket;
  bool _retired = false;
  bool _disposeRequested = false;
  bool _signalScheduled = false;
  bool _signalDisposed = false;

  bool get isCurrent =>
      !_retired &&
      !_disposeRequested &&
      currentVisit() &&
      _account.epoch == _epoch &&
      _account.owner == _ownerId &&
      (_ticket?.isCurrent ??
          repository.communitySocialClient.auth.currentUser == null) &&
      (parentVisit?.isCurrent ?? true);

  void check() {
    if (!isCurrent) throw const CommunityOwnerOperationCancelled();
    CommunityOwnerOperation.checkCurrent();
  }

  Future<T> run<T>(Future<T> Function() action) {
    check();
    return CommunityOwnerOperation.run(
      client: repository.communitySocialClient,
      ownerId: _ownerId,
      readOwner: () => _account.owner,
      isCurrentOwner: () => isCurrent,
      action: (_) async {
        final ticket = _ticket;
        final result = ticket == null
            ? await action()
            : await ticket.run(action);
        check();
        return result;
      },
    );
  }

  _CommunityProfileVisit? captureProfileVisit() {
    final ownerId = _ownerId;
    if (!isCurrent || ownerId == null) return null;
    return _CommunityProfileVisit(
      repository: repository,
      ownerId: ownerId,
      targetId: target,
      isCurrent: () => isCurrent,
      changes: changes,
    );
  }

  void _parentChanged() {
    if (parentVisit?.isCurrent == false) _retire();
  }

  void _retire({bool dispose = false}) {
    final wasRetired = _retired;
    _retired = true;
    _disposeRequested = _disposeRequested || dispose;
    if (!wasRetired) {
      parentVisit?.changes.removeListener(_parentChanged);
      _account.dispose();
    }
    if (_signalDisposed || _signalScheduled || (wasRetired && !dispose)) return;
    _signalScheduled = true;
    // Replacement may happen during build. Checks retire immediately; nested
    // routes receive their signal after the current synchronous frame work.
    scheduleMicrotask(() {
      _signalScheduled = false;
      if (_signalDisposed) return;
      changes.value++;
      if (!_disposeRequested && currentVisit()) onInvalidated();
      if (_disposeRequested) {
        _signalDisposed = true;
        changes.dispose();
      }
    });
  }

  void dispose() => _retire(dispose: true);
}

Future<void> _composeFromTopic(
  BuildContext context,
  _CommunityTopicOwnerScope visit,
  String slug,
  Future<void> Function(String) compose,
) async {
  if (!visit.isCurrent) return;
  try {
    await visit.run(() async {
      visit.check();
      await compose(slug);
      visit.check();
    });
  } on CommunityOwnerOperationCancelled {
    // Old intent never becomes an intent belonging to a replacement account.
  } on Object {
    if (context.mounted && visit.isCurrent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not open the composer. Try again.',
              'تعذر فتح محرر المنشور. حاول مجددًا.',
            ),
          ),
        ),
      );
    }
  }
}

Widget _postTileForTopic(
  BuildContext context,
  _CommunityTopicOwnerScope visit,
  CommunityPost post,
  int? viewCount,
) {
  final profileVisit = visit.captureProfileVisit();
  final tile = _CommunityProfilePostTile(
    visit: profileVisit,
    post: post,
    repository: visit.repository,
    referenceMetadata: null,
    viewCount: viewCount,
  );
  if (profileVisit != null) return tile;
  // Optional local/public repositories may support anonymous reading. Retain
  // its content and semantics without allowing its saved action to become B's.
  return InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: post.moderationStatus == CommunityPostModerationStatus.approved
        ? () {
            if (!visit.isCurrent) return;
            unawaited(
              pushCommunityPage<void>(
                context,
                _CommunityPostDetailPage(
                  post: post,
                  initialStats: CommunityPostStats(
                    postId: post.id,
                    likeCount: post.likeCount,
                    liked: post.liked,
                    commentCount: post.commentCount,
                  ),
                  repository: visit.repository,
                  ownerIsCurrent: () => visit.isCurrent,
                  ownerChanges: visit.changes,
                ),
              ),
            );
          }
        : null,
    child: ExcludeFocus(child: IgnorePointer(child: tile)),
  );
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
    avatar: BilGlassPressFeedback(child: Icon(icon, size: 16)),
    label: Text('$value $label'),
  );
}
