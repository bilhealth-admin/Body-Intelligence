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

enum _CommunityProfileMomentFilter { all, published, pending, rejected }

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
  String? _coverUrl;
  final List<CommunityPost> _posts = [];
  final List<CommunityProfileReview> _reviews = [];
  final List<CommunityDraftSummary> _draftSummaries = [];
  final Map<String, int> _viewCounts = <String, int>{};
  final Map<String, CommunityPostReferenceMetadata> _referenceByPost =
      <String, CommunityPostReferenceMetadata>{};
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
  _CommunityProfileContentTab _contentTab = _CommunityProfileContentTab.moments;
  _CommunityProfileMomentFilter _momentFilter =
      _CommunityProfileMomentFilter.all;

  Future<void> _loadInitial() async {
    final repository = _repository;
    if (repository == null) return;

    final core = await Future.wait<Object>([
      repository.loadProfileOverview(widget.userId),
      repository.loadProfilePosts(userId: widget.userId, limit: _pageSize),
    ]);
    final profile = core[0] as CommunityProfileOverview;
    final batch = core[1] as CommunityFeedBatch;

    CommunityCreatorProfile? creator;
    List<CommunityProfileReview> reviews = const <CommunityProfileReview>[];
    List<CommunityDraftSummary> drafts = const <CommunityDraftSummary>[];
    Map<String, int> counts = const <String, int>{};
    List<CommunityPostReferenceMetadata> references =
        const <CommunityPostReferenceMetadata>[];

    if (repository.useServerCommunityReferenceParity) {
      final postIds = batch.posts
          .map((post) => post.id)
          .toList(growable: false);
      final extras = await Future.wait<Object>([
        repository.loadCommunityCreatorProfile(widget.userId),
        repository.loadCommunityProfileReviews(
          userId: widget.userId,
          limit: _pageSize,
        ),
        profile.isSelf
            ? repository.listMyCommunityDrafts(limit: 5)
            : Future<List<CommunityDraftSummary>>.value(
                const <CommunityDraftSummary>[],
              ),
        repository.loadCommunityPostViewCounts(postIds),
        postIds.isEmpty
            ? Future<List<CommunityPostReferenceMetadata>>.value(
                const <CommunityPostReferenceMetadata>[],
              )
            : repository.loadCommunityPostReferenceMetadata(postIds),
      ]);
      creator = extras[0] as CommunityCreatorProfile;
      reviews = extras[1] as List<CommunityProfileReview>;
      drafts = extras[2] as List<CommunityDraftSummary>;
      counts = extras[3] as Map<String, int>;
      references = extras[4] as List<CommunityPostReferenceMetadata>;
      _coverUrl = await repository.loadCommunityProfileCoverUrl(
        widget.userId,
      );
    } else {
      _coverUrl = null;
    }

    _profile = profile;
    _creator = creator;
    _posts
      ..clear()
      ..addAll(batch.posts);
    _viewCounts
      ..clear()
      ..addAll(counts);
    _referenceByPost
      ..clear()
      ..addEntries(
        references.map((value) => MapEntry(value.postId, value)),
      );
    _reviews
      ..clear()
      ..addAll(reviews);
    _draftSummaries
      ..clear()
      ..addAll(drafts);
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

      Map<String, int> counts = const <String, int>{};
      List<CommunityPostReferenceMetadata> references =
          const <CommunityPostReferenceMetadata>[];
      if (repository.useServerCommunityReferenceParity &&
          incoming.isNotEmpty) {
        final ids = incoming.map((post) => post.id).toList(growable: false);
        final extras = await Future.wait<Object>([
          repository.loadCommunityPostViewCounts(ids),
          repository.loadCommunityPostReferenceMetadata(ids),
        ]);
        counts = extras[0] as Map<String, int>;
        references = extras[1] as List<CommunityPostReferenceMetadata>;
      }

      if (!mounted) return;
      setState(() {
        _posts.addAll(incoming);
        _viewCounts.addAll(counts);
        _referenceByPost.addEntries(
          references.map((value) => MapEntry(value.postId, value)),
        );
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
        _reviews.addAll(page.where((review) => known.add(review.reviewId)));
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
                          coverUrl: _coverUrl,
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
                    if (profile.isSelf)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _CommunityDraftShortcut(
                            summary: _draftSummaries.firstOrNull,
                            onTap: () =>
                                _CommunityProfileDraftActions(this)
                                    .openDrafts(),
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
