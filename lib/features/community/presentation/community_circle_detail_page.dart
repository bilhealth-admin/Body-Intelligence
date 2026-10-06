part of 'community_hub_page.dart';

// Retain the existing taxonomy detail entry while exposing the same surface.
typedef _CommunityCirclePage = CommunityCirclePage;

class CommunityCirclePage extends StatefulWidget {
  const CommunityCirclePage({
    required this.repository,
    required this.circle,
    this.onComposeCircle,
    this.ownerIsCurrent,
    this.ownerChanges,
    super.key,
  });

  final CommunityRepository repository;
  final CommunityCircle circle;
  final Future<void> Function(String slug)? onComposeCircle;
  final ValueGetter<bool>? ownerIsCurrent;
  final Listenable? ownerChanges;

  @override
  State<CommunityCirclePage> createState() => _CommunityCirclePageState();
}

class _CommunityCirclePageState extends State<CommunityCirclePage> {
  static const _pageSize = 30;
  final List<CommunityPost> _posts = <CommunityPost>[];
  final Map<String, int> _viewCounts = <String, int>{};
  late _CommunityCircleOwnerScope _owner;
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
    _loading = _loadFirst();
  }

  @override
  void didUpdateWidget(covariant CommunityCirclePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.circle.slug != widget.circle.slug ||
        oldWidget.circle.membershipStatus != widget.circle.membershipStatus ||
        oldWidget.circle.joinPolicy != widget.circle.joinPolicy ||
        oldWidget.circle.access != widget.circle.access ||
        !identical(oldWidget.ownerIsCurrent, widget.ownerIsCurrent) ||
        !identical(oldWidget.ownerChanges, widget.ownerChanges)) {
      _owner.dispose();
      _clearVisit();
      _bindOwner();
      _loading = _loadFirst();
    }
  }

  @override
  void dispose() {
    _owner.dispose();
    super.dispose();
  }

  void _clearVisit() {
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
    late final _CommunityCircleOwnerScope owner;
    owner = _CommunityCircleOwnerScope(
      repository: widget.repository,
      target: widget.circle.slug,
      currentVisit: () => mounted && identical(_owner, owner),
      parentIsCurrent: widget.ownerIsCurrent,
      parentChanges: widget.ownerChanges,
      onInvalidated: () {
        _clearVisit();
        setState(() {});
      },
    );
    _owner = owner;
  }

  void _checkLoad(_CommunityProfileVisit visit, int generation) {
    visit.check();
    if (generation != _loadGeneration) {
      throw const CommunityOwnerOperationCancelled();
    }
  }

  Future<void> _loadFirst() async {
    final visit = _owner.capture();
    if (visit == null) return;
    final generation = ++_loadGeneration;
    _refreshing = true;
    try {
      await visit.run(() async {
        final page = await visit.repository.loadCommunityCirclePosts(
          slug: visit.targetId,
          limit: _pageSize,
        );
        _checkLoad(visit, generation);
        final counts = await _communityBrowseViewCounts(
          visit.repository,
          page.posts,
        );
        _checkLoad(visit, generation);
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
      // The old circle cannot populate the new target or load its metrics.
    } finally {
      if (visit.isCurrent() && generation == _loadGeneration) {
        _refreshing = false;
      }
    }
  }

  Future<void> _refresh() async {
    if (!_owner.isCurrent) return;
    final future = _loadFirst();
    setState(() {
      _loading = future;
    });
    try {
      await future;
    } on Object {
      // FutureBuilder renders retry state.
    }
  }

  Future<void> _loadMore() async {
    final visit = _owner.capture();
    if (visit == null ||
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
    setState(() => _loadingMore = true);
    try {
      await visit.run(() async {
        final page = await visit.repository.loadCommunityCirclePosts(
          slug: visit.targetId,
          before: before,
          beforeId: beforeId,
          limit: _pageSize,
        );
        _checkLoad(visit, generation);
        final counts = await _communityBrowseViewCounts(
          visit.repository,
          page.posts,
        );
        _checkLoad(visit, generation);
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
      // A cancelled page cannot append rows or clear a later request's busy UI.
    } catch (_) {
      if (!mounted || !visit.isCurrent() || generation != _loadGeneration) {
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
      if (visit.isCurrent() && generation == _loadGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = _owner.capture();
    if (visit == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(communityText(context, 'Circles', 'الدوائر')),
        ),
        body: const _CommunityProfileOwnerChangedBody(),
      );
    }
    final compose = widget.onComposeCircle;
    final slug = widget.circle.slug;
    return Scaffold(
      appBar: AppBar(
        leading: const CommunityReturnButton(),
        title: Text(_circleRecordTitle(context, widget.circle)),
      ),
      floatingActionButton: widget.circle.activeMember && compose != null
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _composeFromCircle(context, visit, slug, compose),
              icon: const Icon(Icons.edit_outlined),
              label: Text(communityText(context, 'New post', 'منشور جديد')),
            )
          : null,
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
                onPressed: () {
                  if (visit.isCurrent()) _refresh();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              if (visit.isCurrent()) await _refresh();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_circleRecordDescription(context, widget.circle)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _CircleMetric(
                              icon: Icons.people_outline_rounded,
                              value: widget.circle.memberCount,
                              label: communityText(context, 'members', 'أعضاء'),
                            ),
                            _CircleMetric(
                              icon: Icons.article_outlined,
                              value: widget.circle.postCount,
                              label: communityText(context, 'posts', 'منشورات'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _circleRecordRules(context, widget.circle),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
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
                            'No approved posts in this circle yet.',
                            'لا توجد منشورات معتمدة في هذه الدائرة بعد.',
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
                          visit: visit,
                          post: _posts[index],
                          repository: visit.repository,
                          referenceMetadata: null,
                          viewCount: _viewCounts[_posts[index].id],
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
                            communityText(context, 'Load more', 'تحميل المزيد'),
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
