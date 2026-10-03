part of 'community_hub_page.dart';

CommunityRepository? _communityProfileProductionRepository() {
  if (!AppEnvironment.communityConfigured) return null;
  try {
    final supabase = Supabase.instance;
    if (!supabase.isInitialized || supabase.client.auth.currentUser == null) {
      return null;
    }
    return CommunityRepository(supabase.client);
  } on Object {
    return null;
  }
}

enum _CommunityProfileContentTab { moments, reviews }

class CommunityMemberProfilePage extends StatefulWidget {
  const CommunityMemberProfilePage({
    required this.userId,
    this.repository,
    super.key,
  });

  final String userId;
  final CommunityRepository? repository;

  @override
  State<CommunityMemberProfilePage> createState() =>
      _CommunityMemberProfilePageState();
}

class _CommunityMemberProfilePageState
    extends State<CommunityMemberProfilePage> {
  static const _pageSize = 24;

  late final CommunityRepository? _repository =
      widget.repository ?? _communityProfileProductionRepository();
  CommunityProfileOverview? _profile;
  CommunityCreatorProfile? _creator;
  final List<CommunityPost> _posts = [];
  final List<CommunityProfileReview> _reviews = [];
  final Map<String, int> _viewCounts = <String, int>{};
  late Future<void> _loading = _loadInitial();
  DateTime? _before;
  String? _beforeId;
  DateTime? _reviewBefore;
  String? _reviewBeforeId;
  bool _hasMore = false;
  bool _reviewHasMore = false;
  bool _loadingMore = false;
  bool _loadingMoreReviews = false;
  bool _gridMode = true;
  bool _relationshipBusy = false;
  bool _followBusy = false;
  bool _managingPost = false;
  _CommunityProfileContentTab _contentTab =
      _CommunityProfileContentTab.moments;

  Future<void> _loadInitial() async {
    final repository = _repository;
    if (repository == null) return;
    final values = await Future.wait<Object>([
      repository.loadProfileOverview(widget.userId),
      repository.loadProfilePosts(userId: widget.userId, limit: _pageSize),
      repository.loadCommunityCreatorProfile(widget.userId),
      repository.loadCommunityProfileReviews(
        userId: widget.userId,
        limit: _pageSize,
      ),
    ]);
    final profile = values[0] as CommunityProfileOverview;
    final batch = values[1] as CommunityFeedBatch;
    final creator = values[2] as CommunityCreatorProfile;
    final reviews = values[3] as List<CommunityProfileReview>;
    final counts = await repository.loadCommunityPostViewCounts(
      batch.posts.map((post) => post.id).toList(growable: false),
    );

    _profile = profile;
    _creator = creator;
    _posts
      ..clear()
      ..addAll(batch.posts);
    _viewCounts
      ..clear()
      ..addAll(counts);
    _reviews
      ..clear()
      ..addAll(reviews);
    _before = batch.nextBefore;
    _beforeId = batch.nextBeforeId;
    _hasMore = batch.hasMore;
    _reviewHasMore = reviews.length == _pageSize;
    _reviewBefore = reviews.lastOrNull?.createdAt;
    _reviewBeforeId = reviews.lastOrNull?.reviewId;
  }

  Future<void> _refresh() async {
    final future = _loadInitial();
    setState(() => _loading = future);
    try {
      await future;
    } on Object {
      // FutureBuilder renders the retry state.
    }
  }

  Future<void> _loadMore() async {
    final repository = _repository;
    if (repository == null ||
        _loadingMore ||
        !_hasMore ||
        _before == null ||
        _beforeId == null) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final batch = await repository.loadProfilePosts(
        userId: widget.userId,
        before: _before,
        beforeId: _beforeId,
        limit: _pageSize,
      );
      final known = _posts.map((post) => post.id).toSet();
      final incoming = batch.posts
          .where((post) => known.add(post.id))
          .toList(growable: false);
      final counts = await repository.loadCommunityPostViewCounts(
        incoming.map((post) => post.id).toList(growable: false),
      );
      if (!mounted) return;
      setState(() {
        _posts.addAll(incoming);
        _viewCounts.addAll(counts);
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

  Future<void> _loadMoreReviews() async {
    final repository = _repository;
    if (repository == null ||
        _loadingMoreReviews ||
        !_reviewHasMore ||
        _reviewBefore == null ||
        _reviewBeforeId == null) {
      return;
    }
    setState(() => _loadingMoreReviews = true);
    try {
      final page = await repository.loadCommunityProfileReviews(
        userId: widget.userId,
        before: _reviewBefore,
        beforeId: _reviewBeforeId,
        limit: _pageSize,
      );
      if (!mounted) return;
      final known = _reviews.map((review) => review.reviewId).toSet();
      setState(() {
        _reviews.addAll(
          page.where((review) => known.add(review.reviewId)),
        );
        _reviewHasMore = page.length == _pageSize;
        if (page.isNotEmpty) {
          _reviewBefore = page.last.createdAt;
          _reviewBeforeId = page.last.reviewId;
        }
      });
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _loadingMoreReviews = false);
    }
  }

  Future<void> _requestFriend() async {
    final repository = _repository;
    final profile = _profile;
    if (repository == null ||
        profile == null ||
        profile.isSelf ||
        _relationshipBusy) {
      return;
    }
    setState(() => _relationshipBusy = true);
    try {
      await repository.requestFriend(profile.userId);
      final refreshed = await repository.loadProfileOverview(profile.userId);
      if (!mounted) return;
      setState(() => _profile = refreshed);
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _relationshipBusy = false);
    }
  }

  Future<void> _toggleFollow() async {
    final repository = _repository;
    final profile = _profile;
    if (repository == null ||
        profile == null ||
        profile.isSelf ||
        _followBusy ||
        (!profile.viewerFollows && !profile.allowFollows)) {
      return;
    }
    setState(() => _followBusy = true);
    try {
      if (profile.viewerFollows) {
        await repository.unfollow(profile.userId);
      } else {
        await repository.follow(profile.userId);
      }
      final values = await Future.wait<Object>([
        repository.loadProfileOverview(profile.userId),
        repository.loadCommunityCreatorProfile(profile.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = values[0] as CommunityProfileOverview;
        _creator = values[1] as CommunityCreatorProfile;
      });
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _openConnections(CommunityProfileConnectionKind kind) async {
    final repository = _repository;
    final profile = _profile;
    if (repository == null || profile == null) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _CommunityProfileConnectionsSheet(
        repository: repository,
        profile: profile,
        kind: kind,
      ),
    );
  }

  Future<void> _managePost(CommunityPost post, String action) async {
    final repository = _repository;
    if (repository == null || _managingPost) return;

    String? moderationReason;
    if (action == 'moderate_remove' || action == 'moderate_hide') {
      moderationReason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: Text(
            action == 'moderate_hide'
                ? communityText(context, 'Hide post', 'إخفاء المنشور')
                : communityText(context, 'Remove post', 'إزالة المنشور'),
          ),
          children: [
            for (final reason in const [
              'spam',
              'abuse',
              'misleading',
              'privacy',
              'unsafe_or_inappropriate',
              'other',
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, reason),
                child: Text(reason),
              ),
          ],
        ),
      );
      if (moderationReason == null || !mounted) return;
    }

    if (action == 'delete' || action == 'block') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            action == 'delete'
                ? communityText(context, 'Delete post?', 'حذف المشاركة؟')
                : communityText(
                    context,
                    'Block this member?',
                    'حظر هذا العضو؟',
                  ),
          ),
          content: Text(
            action == 'delete'
                ? communityText(
                    context,
                    'This removes your post from Community.',
                    'سيؤدي ذلك إلى إزالة مشاركتك من المجتمع.',
                  )
                : communityText(
                    context,
                    'You will no longer see each other in Community or messages.',
                    'لن يتمكن أي منكما من رؤية الآخر في المجتمع أو الرسائل.',
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(communityText(context, 'Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                action == 'delete'
                    ? communityText(context, 'Delete', 'حذف')
                    : communityText(context, 'Block', 'حظر'),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _managingPost = true);
    try {
      if (action == 'report') {
        await repository.report(
          targetKind: 'post',
          targetId: post.id,
          reason: 'user_reported_from_profile',
        );
      } else if (action == 'delete') {
        await repository.deletePost(post.id);
        if (mounted) {
          setState(() => _posts.removeWhere((item) => item.id == post.id));
        }
      } else if (action == 'block') {
        await repository.blockMember(post.authorId);
        if (mounted) context.pop();
      } else if (action == 'moderate_remove') {
        await repository.removePublishedPostAsModerator(
          postId: post.id,
          reason: moderationReason!,
        );
        if (mounted) {
          setState(() => _posts.removeWhere((item) => item.id == post.id));
        }
      } else if (action == 'moderate_hide') {
        await repository.hidePublishedPostAsModerator(
          postId: post.id,
          reason: moderationReason!,
        );
        if (mounted) {
          setState(() => _posts.removeWhere((item) => item.id == post.id));
        }
      }
      if (mounted && action == 'report') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Report sent for review.',
                'تم إرسال البلاغ للمراجعة.',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _managingPost = false);
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

  List<Widget> _profileContentSlivers(CommunityProfileOverview profile) {
    final tabs = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: _contentTab == _CommunityProfileContentTab.moments
                  ? FilledButton.tonal(
                      key: const Key('community-profile-tab-moments'),
                      onPressed: null,
                      child: Text(
                        communityText(context, 'Moments', 'اللحظات'),
                      ),
                    )
                  : TextButton(
                      key: const Key('community-profile-tab-moments'),
                      onPressed: () => setState(
                        () => _contentTab =
                            _CommunityProfileContentTab.moments,
                      ),
                      child: Text(
                        communityText(context, 'Moments', 'اللحظات'),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _contentTab == _CommunityProfileContentTab.reviews
                  ? FilledButton.tonal(
                      key: const Key('community-profile-tab-reviews'),
                      onPressed: null,
                      child: Text(
                        communityText(context, 'Reviews', 'المراجعات'),
                      ),
                    )
                  : TextButton(
                      key: const Key('community-profile-tab-reviews'),
                      onPressed: () => setState(
                        () => _contentTab =
                            _CommunityProfileContentTab.reviews,
                      ),
                      child: Text(
                        communityText(context, 'Reviews', 'المراجعات'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

    if (_contentTab == _CommunityProfileContentTab.reviews) {
      return <Widget>[
        tabs,
        if (_reviews.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(Icons.rate_review_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    profile.showPosts
                        ? communityText(
                            context,
                            'No approved reviews yet.',
                            'لا توجد مراجعات معتمدة بعد.',
                          )
                        : communityText(
                            context,
                            'Reviews are private on this profile.',
                            'المراجعات خاصة في هذا الملف.',
                          ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: _reviews.length,
              itemBuilder: (context, index) =>
                  _CommunityProfileReviewTile(review: _reviews[index]),
            ),
          ),
        if (_reviewHasMore)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton.icon(
                  onPressed:
                      _loadingMoreReviews ? null : _loadMoreReviews,
                  icon: _loadingMoreReviews
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(
                    communityText(context, 'Load more', 'تحميل المزيد'),
                  ),
                ),
              ),
            ),
          ),
      ];
    }

    return <Widget>[
      tabs,
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Text(
                communityText(context, 'Moments', 'اللحظات'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Icon(
                _gridMode
                    ? Icons.grid_view_rounded
                    : Icons.view_agenda_outlined,
                size: 18,
              ),
            ],
          ),
        ),
      ),
      if (_posts.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                const Icon(Icons.article_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  profile.showPosts
                      ? communityText(
                          context,
                          'No visible moments yet.',
                          'لا توجد لحظات ظاهرة بعد.',
                        )
                      : communityText(
                          context,
                          'Moments are private on this profile.',
                          'اللحظات خاصة في هذا الملف.',
                        ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        )
      else if (_gridMode)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                repository: _repository!,
                viewCount: _viewCounts[_posts[index].id] ?? 0,
              ),
              childCount: _posts.length,
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: _posts.length,
            itemBuilder: (context, index) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CommunityPostCard(
                  post: _posts[index],
                  repository: _repository!,
                  currentUserId: _repository!.currentUserId,
                  actionsEnabled: !_managingPost,
                  showModerationStatus: profile.isSelf,
                  onAction: (action) =>
                      _managePost(_posts[index], action),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 12,
                    end: 12,
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_outlined, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        (_viewCounts[_posts[index].id] ?? 0).toString(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  communityText(context, 'Load more', 'تحميل المزيد'),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(communityText(context, 'Community profile', 'ملف المجتمع')),
      actions: [
        IconButton(
          tooltip: _gridMode
              ? communityText(context, 'List view', 'عرض القائمة')
              : communityText(context, 'Grid view', 'عرض الشبكة'),
          onPressed: _contentTab == _CommunityProfileContentTab.moments
              ? () => setState(() => _gridMode = !_gridMode)
              : null,
          icon: Icon(
            _gridMode ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
          ),
        ),
      ],
    ),
    body: _repository == null
        ? Center(
            child: Text(
              communityText(
                context,
                'Sign in to view Community profiles.',
                'سجّل الدخول لعرض ملفات المجتمع.',
              ),
            ),
          )
        : FutureBuilder<void>(
            future: _loading,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done &&
                  _profile == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || _profile == null) {
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
              final profile = _profile!;
              return RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: _CommunityMemberProfileHeader(
                          profile: profile,
                          creator: _creator,
                          relationshipBusy: _relationshipBusy,
                          followBusy: _followBusy,
                          onRequestFriend: _requestFriend,
                          onToggleFollow: _toggleFollow,
                          onOpenConnections: _openConnections,
                        ),
                      ),
                    ),
                    if (_creator case final creator?)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: _CommunityCreatorPanel(
                            creator: creator,
                            isSelf: profile.isSelf,
                          ),
                        ),
                      ),
                    ..._profileContentSlivers(profile),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              );
            },
          ),
  );
}

class _CommunityMemberProfileHeader extends StatelessWidget {
  const _CommunityMemberProfileHeader({
    required this.profile,
    required this.creator,
    required this.relationshipBusy,
    required this.followBusy,
    required this.onRequestFriend,
    required this.onToggleFollow,
    required this.onOpenConnections,
  });

  final CommunityProfileOverview profile;
  final CommunityCreatorProfile? creator;
  final bool relationshipBusy;
  final bool followBusy;
  final VoidCallback onRequestFriend;
  final VoidCallback onToggleFollow;
  final ValueChanged<CommunityProfileConnectionKind> onOpenConnections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [scheme.primary.withValues(alpha: .12), scheme.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BilAccountAvatar(radius: 42, networkUrl: profile.avatarUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (profile.handle != null)
                      Text(
                        '@${profile.handle}',
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (profile.countryCode != null)
                      Text(
                        profile.countryCode!,
                        style: theme.textTheme.labelMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.bio?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(profile.bio!, style: theme.textTheme.bodyLarge),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (profile.postCount != null)
                _CommunityProfileMetric(
                  icon: Icons.article_outlined,
                  value: '${profile.postCount}',
                  label: communityText(context, 'Posts', 'المنشورات'),
                ),
              if (profile.friendCount != null)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () =>
                      onOpenConnections(CommunityProfileConnectionKind.friends),
                  child: _CommunityProfileMetric(
                    icon: Icons.people_outline_rounded,
                    value: '${profile.friendCount}',
                    label: communityText(context, 'Friends', 'الأصدقاء'),
                  ),
                ),
              if (profile.followerCount != null)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onOpenConnections(
                    CommunityProfileConnectionKind.followers,
                  ),
                  child: _CommunityProfileMetric(
                    icon: Icons.group_outlined,
                    value: '${profile.followerCount}',
                    label: communityText(context, 'Followers', 'المتابعون'),
                  ),
                ),
              if (profile.followingCount != null)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onOpenConnections(
                    CommunityProfileConnectionKind.following,
                  ),
                  child: _CommunityProfileMetric(
                    icon: Icons.person_add_alt_outlined,
                    value: '${profile.followingCount}',
                    label: communityText(context, 'Following', 'يتابع'),
                  ),
                ),
              if (profile.communityLevel != null)
                _CommunityProfileMetric(
                  icon: Icons.workspace_premium_outlined,
                  value: 'Lv ${profile.communityLevel}',
                  label: communityText(
                    context,
                    'Community level',
                    'مستوى المجتمع',
                  ),
                ),
              if (profile.communityXp != null)
                _CommunityProfileMetric(
                  icon: Icons.auto_graph_rounded,
                  value: '${profile.communityXp} XP',
                  label: 'Community XP',
                ),
              if (profile.goldBalance != null)
                _CommunityProfileMetric(
                  icon: Icons.monetization_on_outlined,
                  value: '${profile.goldBalance}',
                  label: 'BIL Gold',
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (profile.isSelf)
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/community/profile'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    communityText(context, 'Edit profile', 'تعديل الملف'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/community/code'),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: Text(
                    communityText(context, 'My BIL Code', 'رمز BIL الخاص بي'),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ProfileRelationshipAction(
                  profile: profile,
                  busy: relationshipBusy,
                  onRequestFriend: onRequestFriend,
                ),
                if (profile.viewerFollows || profile.allowFollows)
                  OutlinedButton.icon(
                    key: const Key('community-profile-follow-action'),
                    onPressed: followBusy ? null : onToggleFollow,
                    icon: followBusy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            profile.viewerFollows
                                ? Icons.person_remove_outlined
                                : Icons.person_add_alt_outlined,
                          ),
                    label: Text(
                      profile.viewerFollows
                          ? communityText(
                              context,
                              'Following',
                              'يتابع',
                            )
                          : communityText(
                              context,
                              'Follow',
                              'متابعة',
                            ),
                    ),
                  ),
                if (profile.followsViewer)
                  Chip(
                    avatar: const Icon(Icons.swap_horiz_rounded, size: 17),
                    label: Text(
                      communityText(
                        context,
                        'Follows you',
                        'يتابعك',
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProfileRelationshipAction extends StatelessWidget {
  const _ProfileRelationshipAction({
    required this.profile,
    required this.busy,
    required this.onRequestFriend,
  });

  final CommunityProfileOverview profile;
  final bool busy;
  final VoidCallback onRequestFriend;

  @override
  Widget build(BuildContext context) => switch (profile.relationship) {
    CommunityRelationshipStatus.none when profile.allowFriendRequests =>
      FilledButton.icon(
        onPressed: busy ? null : onRequestFriend,
        icon: busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add_alt_1_rounded),
        label: Text(communityText(context, 'Add Friend', 'إضافة صديق')),
      ),
    CommunityRelationshipStatus.pending => Chip(
      avatar: const Icon(Icons.schedule_rounded),
      label: Text(
        communityText(context, 'Request pending', 'الطلب قيد الانتظار'),
      ),
    ),
    CommunityRelationshipStatus.incoming => FilledButton.tonalIcon(
      onPressed: () => context.push('/community/connections'),
      icon: const Icon(Icons.mark_email_unread_outlined),
      label: Text(communityText(context, 'Review request', 'مراجعة الطلب')),
    ),
    CommunityRelationshipStatus.accepted => Chip(
      avatar: const Icon(Icons.people_rounded),
      label: Text(communityText(context, 'Friends', 'الأصدقاء')),
    ),
    _ => const SizedBox.shrink(),
  };
}

class _CommunityProfilePostTile extends StatelessWidget {
  const _CommunityProfilePostTile({
    required this.post,
    required this.repository,
    required this.viewCount,
  });

  final CommunityPost post;
  final CommunityRepository repository;
  final int viewCount;

  Future<void> _open(BuildContext context) => pushCommunityPage<void>(
    context,
    _CommunityPostDetailPage(
      post: post,
      initialStats: CommunityPostStats(
        postId: post.id,
        likeCount: post.likeCount,
        liked: post.liked,
        commentCount: post.commentCount,
      ),
      repository: repository,
    ),
  );

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: post.moderationStatus == CommunityPostModerationStatus.approved
        ? () => _open(context)
        : null,
    child: Ink(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: post.mediaUrl == null
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        post.body,
                        maxLines: 7,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : Image.network(
                      post.mediaUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          post.body,
                          maxLines: 7,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  const Icon(Icons.favorite_border_rounded, size: 16),
                  const SizedBox(width: 3),
                  Text('${post.likeCount}'),
                  const SizedBox(width: 10),
                  const Icon(Icons.mode_comment_outlined, size: 16),
                  const SizedBox(width: 3),
                  Text('${post.commentCount}'),
                  const SizedBox(width: 10),
                  const Icon(Icons.visibility_outlined, size: 16),
                  const SizedBox(width: 3),
                  Text(viewCount.toString()),
                  if (post.moderationStatus !=
                      CommunityPostModerationStatus.approved) ...[
                    const Spacer(),
                    Icon(
                      post.moderationStatus ==
                              CommunityPostModerationStatus.pending
                          ? Icons.schedule_rounded
                          : Icons.block_rounded,
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CommunityProfileConnectionsSheet extends StatefulWidget {
  const _CommunityProfileConnectionsSheet({
    required this.repository,
    required this.profile,
    required this.kind,
  });

  final CommunityRepository repository;
  final CommunityProfileOverview profile;
  final CommunityProfileConnectionKind kind;

  @override
  State<_CommunityProfileConnectionsSheet> createState() =>
      _CommunityProfileConnectionsSheetState();
}

class _CommunityProfileConnectionsSheetState
    extends State<_CommunityProfileConnectionsSheet> {
  late Future<List<CommunityProfileConnection>> _connections;
  String? _followBusyUserId;

  @override
  void initState() {
    super.initState();
    _connections = _loadConnections();
  }

  Future<List<CommunityProfileConnection>> _loadConnections() =>
      widget.repository.loadProfileConnections(
        userId: widget.profile.userId,
        kind: widget.kind,
      );

  Future<void> _toggleFollow(CommunityProfileConnection member) async {
    if (_followBusyUserId != null ||
        member.relationship == CommunityRelationshipStatus.self ||
        (!member.viewerFollows && !member.allowFollows)) {
      return;
    }
    setState(() => _followBusyUserId = member.userId);
    try {
      if (member.viewerFollows) {
        await widget.repository.unfollow(member.userId);
      } else {
        await widget.repository.follow(member.userId);
      }
      if (!mounted) return;
      setState(() => _connections = _loadConnections());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Could not update follow state.',
                'تعذر تحديث حالة المتابعة.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _followBusyUserId = null);
    }
  }

  String _title(BuildContext context) => switch (widget.kind) {
    CommunityProfileConnectionKind.followers => communityText(
      context,
      'Followers',
      'المتابعون',
    ),
    CommunityProfileConnectionKind.following => communityText(
      context,
      'Following',
      'يتابع',
    ),
    CommunityProfileConnectionKind.friends => communityText(
      context,
      'Friends',
      'الأصدقاء',
    ),
  };

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .72,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text(
            _title(context),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: FutureBuilder<List<CommunityProfileConnection>>(
            future: _connections,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    communityText(
                      context,
                      'This list is unavailable right now.',
                      'هذه القائمة غير متاحة الآن.',
                    ),
                  ),
                );
              }
              final rows = snapshot.data ?? const [];
              if (rows.isEmpty) {
                return Center(
                  child: Text(
                    communityText(
                      context,
                      'Nothing to show here yet.',
                      'لا يوجد ما يمكن عرضه هنا بعد.',
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final member = rows[index];
                  return ListTile(
                    leading: BilAccountAvatar(
                      radius: 22,
                      networkUrl: member.avatarUrl,
                    ),
                    title: Text(member.displayName),
                    subtitle: member.handle == null
                        ? null
                        : Text(
                            '@${member.handle}',
                            textDirection: TextDirection.ltr,
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (member.relationship !=
                                CommunityRelationshipStatus.self &&
                            (member.viewerFollows || member.allowFollows))
                          TextButton(
                            key: Key(
                              'community-connection-follow-' + member.userId,
                            ),
                            onPressed: _followBusyUserId == null
                                ? () => _toggleFollow(member)
                                : null,
                            child: _followBusyUserId == member.userId
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    member.viewerFollows
                                        ? communityText(
                                            context,
                                            'Following',
                                            'يتابع',
                                          )
                                        : communityText(
                                            context,
                                            'Follow',
                                            'متابعة',
                                          ),
                                  ),
                          ),
                        Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/community/profile/${member.userId}');
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
