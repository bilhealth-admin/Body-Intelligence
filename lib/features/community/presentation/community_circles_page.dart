part of 'community_hub_page.dart';

class CommunityCirclesPage extends StatefulWidget {
  const CommunityCirclesPage({
    required this.repository,
    this.onComposeCircle,
    this.embedded = false,
    super.key,
  });

  final CommunityRepository repository;
  final Future<void> Function(String slug)? onComposeCircle;
  final bool embedded;

  @override
  State<CommunityCirclesPage> createState() => _CommunityCirclesPageState();
}

class _CommunityCirclesPageState extends State<CommunityCirclesPage> {
  late Future<List<CommunityCircle>> _circles = widget.repository
      .loadCommunityCircles();
  final Set<String> _busy = <String>{};

  Future<void> _refresh() async {
    final future = widget.repository.loadCommunityCircles();
    setState(() => _circles = future);
    try {
      await future;
    } on Object {
      // FutureBuilder renders the retry state.
    }
  }

  Future<void> _toggleMembership(CommunityCircle circle) async {
    if (!_busy.add(circle.slug)) return;
    try {
      if (circle.activeMember || circle.pending) {
        await widget.repository.leaveCommunityCircle(circle.slug);
      } else {
        await widget.repository.joinCommunityCircle(circle.slug);
      }
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Could not update this circle safely. Try again.',
                'تعذر تحديث هذه الدائرة بأمان. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
    } finally {
      _busy.remove(circle.slug);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<CommunityCircle>>(
        future: _circles,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 180),
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
          final circles = snapshot.data ?? const <CommunityCircle>[];
          return ListView.separated(
            key: const Key('community-circles-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: circles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final circle = circles[index];
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final headerAction =
                  textScale < 1.4 && MediaQuery.sizeOf(context).width >= 390;
              final membershipButton = OutlinedButton.icon(
                key: Key('community-circle-membership-${circle.slug}'),
                onPressed: _busy.contains(circle.slug)
                    ? null
                    : () => _toggleMembership(circle),
                icon: Icon(
                  circle.activeMember
                      ? Icons.logout_rounded
                      : circle.pending
                      ? Icons.schedule_rounded
                      : Icons.group_add_outlined,
                  size: 18,
                ),
                label: Text(
                  circle.activeMember
                      ? communityText(context, 'Leave', 'مغادرة')
                      : circle.pending
                      ? communityText(context, 'Pending', 'قيد الانتظار')
                      : communityText(context, 'Join', 'انضمام'),
                ),
              );
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => pushCommunityPage<void>(
                    context,
                    _CommunityCirclePage(
                      repository: widget.repository,
                      circle: circle,
                      onComposeCircle: widget.onComposeCircle,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CommunityCircleCover(slug: circle.slug),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _circleTitle(context, circle.slug),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      if (circle.featured)
                                        const Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${circle.postCount} ${communityText(context, 'posts', 'منشورات')}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _circleDescription(context, circle.slug),
                                    maxLines: textScale >= 1.5 ? 3 : 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (headerAction) ...[
                              const SizedBox(width: 8),
                              membershipButton,
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _CircleMetric(
                              icon: Icons.people_outline_rounded,
                              value: circle.memberCount,
                              label: communityText(context, 'members', 'أعضاء'),
                            ),
                            if (!headerAction) membershipButton,
                            if (circle.activeMember &&
                                widget.onComposeCircle != null)
                              IconButton.filledTonal(
                                tooltip: communityText(
                                  context,
                                  'Post in circle',
                                  'انشر في الدائرة',
                                ),
                                onPressed: () =>
                                    widget.onComposeCircle!(circle.slug),
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
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(
              title: Text(communityText(context, 'Circles', 'الدوائر')),
            ),
            body: body,
          );
  }
}

class _CommunityCirclePage extends StatefulWidget {
  const _CommunityCirclePage({
    required this.repository,
    required this.circle,
    this.onComposeCircle,
  });

  final CommunityRepository repository;
  final CommunityCircle circle;
  final Future<void> Function(String slug)? onComposeCircle;

  @override
  State<_CommunityCirclePage> createState() => _CommunityCirclePageState();
}

class _CommunityCirclePageState extends State<_CommunityCirclePage> {
  static const _pageSize = 30;
  final List<CommunityPost> _posts = <CommunityPost>[];
  final Map<String, int> _viewCounts = <String, int>{};
  late Future<void> _loading = _loadFirst();
  DateTime? _before;
  String? _beforeId;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _refreshing = false;
  int _loadGeneration = 0;

  Future<void> _loadFirst() async {
    final generation = ++_loadGeneration;
    _refreshing = true;
    try {
      final page = await widget.repository.loadCommunityCirclePosts(
        slug: widget.circle.slug,
        limit: _pageSize,
      );
      final counts = await _communityBrowseViewCounts(
        widget.repository,
        page.posts,
      );
      if (!mounted || generation != _loadGeneration) return;
      _viewCounts
        ..clear()
        ..addAll(counts);
      _posts
        ..clear()
        ..addAll(page.posts);
      _before = page.nextBefore;
      _beforeId = page.nextBeforeId;
      _hasMore = page.hasMore;
    } finally {
      if (generation == _loadGeneration) _refreshing = false;
    }
  }

  Future<void> _refresh() async {
    final future = _loadFirst();
    setState(() => _loading = future);
    try {
      await future;
    } on Object {
      // FutureBuilder renders retry state.
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore ||
        _refreshing ||
        !_hasMore ||
        _before == null ||
        _beforeId == null) {
      return;
    }
    final generation = _loadGeneration;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.repository.loadCommunityCirclePosts(
        slug: widget.circle.slug,
        before: _before,
        beforeId: _beforeId,
        limit: _pageSize,
      );
      final counts = await _communityBrowseViewCounts(
        widget.repository,
        page.posts,
      );
      if (!mounted || generation != _loadGeneration) return;
      final known = _posts.map((post) => post.id).toSet();
      setState(() {
        _viewCounts.addAll(counts);
        _posts.addAll(page.posts.where((post) => known.add(post.id)));
        _before = page.nextBefore;
        _beforeId = page.nextBeforeId;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_circleTitle(context, widget.circle.slug))),
    floatingActionButton:
        widget.circle.activeMember && widget.onComposeCircle != null
        ? FloatingActionButton.extended(
            onPressed: () => widget.onComposeCircle!(widget.circle.slug),
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
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
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
                      Text(_circleDescription(context, widget.circle.slug)),
                      const SizedBox(height: 10),
                      Text(
                        communityText(
                          context,
                          'Be respectful, avoid private health details, and follow Community policy.',
                          'كن محترمًا، وتجنب التفاصيل الصحية الخاصة، والتزم بسياسة المجتمع.',
                        ),
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
                        post: _posts[index],
                        repository: widget.repository,
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

class _CommunityCircleCover extends StatelessWidget {
  const _CommunityCircleCover({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: Key('community-circle-cover-$slug'),
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Icon(
        _circleIcon(slug),
        size: 30,
        color: scheme.onPrimaryContainer,
      ),
    );
  }
}

class _CircleMetric extends StatelessWidget {
  const _CircleMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 16), label: Text('$value $label'));
}

String _circleTitle(BuildContext context, String slug) => switch (slug) {
  '10k-steps' => communityText(context, '10K Steps', '10 آلاف خطوة'),
  'healthy-eating' => communityText(context, 'Healthy Eating', 'الأكل الصحي'),
  'beginner-fitness' => communityText(
    context,
    'Beginner Fitness',
    'لياقة للمبتدئين',
  ),
  'strength' => communityText(context, 'Strength', 'القوة'),
  'running' => communityText(context, 'Running', 'الجري'),
  'sleep' => communityText(context, 'Better Sleep', 'نوم أفضل'),
  'ramadan-fasting' => communityText(
    context,
    'Ramadan & Fasting',
    'رمضان والصيام',
  ),
  'weight-loss-journey' => communityText(
    context,
    'Weight-Loss Journey',
    'رحلة خفض الوزن',
  ),
  _ => slug,
};

String _circleDescription(BuildContext context, String slug) => switch (slug) {
  '10k-steps' => communityText(
    context,
    'Build a consistent walking habit and encourage one another.',
    'ابنِ عادة مشي مستمرة وشجّع الآخرين.',
  ),
  'healthy-eating' => communityText(
    context,
    'Share practical meal ideas and sustainable eating habits.',
    'شارك أفكار وجبات عملية وعادات غذائية مستدامة.',
  ),
  'beginner-fitness' => communityText(
    context,
    'A welcoming place for safe, gradual fitness progress.',
    'مساحة مرحبة للتقدم التدريجي والآمن في اللياقة.',
  ),
  'strength' => communityText(
    context,
    'Discuss strength training, consistency, and recovery.',
    'ناقش تمارين القوة والاستمرارية والتعافي.',
  ),
  'running' => communityText(
    context,
    'Share running progress, routines, and encouragement.',
    'شارك تقدمك في الجري وروتينك والتشجيع.',
  ),
  'sleep' => communityText(
    context,
    'Support better sleep routines without medical claims.',
    'ادعم عادات نوم أفضل دون ادعاءات طبية.',
  ),
  'ramadan-fasting' => communityText(
    context,
    'Share culturally respectful fasting routines and experiences.',
    'شارك تجارب وروتين الصيام باحترام ثقافي.',
  ),
  'weight-loss-journey' => communityText(
    context,
    'Share sustainable progress and support without comparison pressure.',
    'شارك تقدمًا مستدامًا ودعمًا دون ضغط المقارنة.',
  ),
  _ => '',
};

IconData _circleIcon(String slug) => switch (slug) {
  '10k-steps' => Icons.directions_walk_rounded,
  'healthy-eating' => Icons.restaurant_outlined,
  'beginner-fitness' => Icons.fitness_center_outlined,
  'strength' => Icons.sports_gymnastics_outlined,
  'running' => Icons.directions_run_rounded,
  'sleep' => Icons.bedtime_outlined,
  'ramadan-fasting' => Icons.nightlight_round,
  'weight-loss-journey' => Icons.trending_down_rounded,
  _ => Icons.groups_2_outlined,
};
