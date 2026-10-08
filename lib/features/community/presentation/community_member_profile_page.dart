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
    this.profileActivityDataSource,
    super.key,
  });

  final String userId;
  final CommunityRepository? repository;
  final CommunityProfileActivityDataSource? profileActivityDataSource;

  @override
  State<CommunityMemberProfilePage> createState() =>
      _CommunityMemberProfilePageState();
}

class _CommunityMemberProfilePageState
    extends State<CommunityMemberProfilePage> {
  static const _pageSize = 24;

  CommunityRepository? _repository;
  String? _profileOwnerId;
  String? _profileTargetId;
  bool _profileOwnerCancelled = false;
  int _profileBinding = 0;
  StreamSubscription<AuthState>? _profileAuth;
  final _profileOwnerChanges = ValueNotifier<int>(0);
  bool _profileSignalDisposed = false;
  CommunityProfileOverview? _profile;
  CommunityCreatorProfile? _creator;
  CommunityGoldBalance? _goldBalance;
  List<CommunityQuest> _quests = const <CommunityQuest>[];
  String? _coverUrl;
  final List<CommunityPost> _posts = [];
  final List<CommunityProfileReview> _reviews = [];
  final List<CommunityDraftSummary> _draftSummaries = [];
  final Map<String, int> _viewCounts = <String, int>{};
  final Map<String, CommunityPostReferenceMetadata> _referenceByPost =
      <String, CommunityPostReferenceMetadata>{};
  final _profileActivity = _CommunityProfileActivityState();
  late Future<void> _loading;
  DateTime? _before;
  String? _beforeId;
  DateTime? _reviewBefore;
  String? _reviewBeforeId;
  bool _hasMore = false;
  bool _reviewHasMore = false;
  bool _loadingMore = false;
  bool _loadingMoreReviews = false;
  int _loadGeneration = 0;
  bool _refreshing = false;
  bool _gridMode = false;
  bool _relationshipBusy = false;
  bool _followBusy = false;
  bool _managingPost = false;
  _CommunityProfileContentTab _contentTab = _CommunityProfileContentTab.moments;
  _CommunityProfileMomentFilter _momentFilter =
      _CommunityProfileMomentFilter.all;

  @override
  void initState() {
    super.initState();
    _bindProfileOwner();
    _loading = _loadInitial();
  }

  @override
  void didUpdateWidget(covariant CommunityMemberProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        !identical(
          oldWidget.profileActivityDataSource,
          widget.profileActivityDataSource,
        ) ||
        oldWidget.userId != widget.userId) {
      _endProfileVisit();
      _bindProfileOwner();
      _loading = _loadInitial();
    } else if (_repository != null && !_sameProfileOwner) {
      _invalidateProfileOwner();
    }
  }

  @override
  void dispose() {
    _endProfileVisit(dispose: true);
    super.dispose();
  }

  void _setProfileState(VoidCallback callback) => setState(callback);

  Future<void> _loadInitial() async {
    final visit = _captureProfileVisit();
    if (visit == null) return;
    final repository = visit.repository;
    repository.invalidateCommunityModeratorStatus();
    final generation = ++_loadGeneration;
    _refreshing = true;
    _loadingMore = false;
    _loadingMoreReviews = false;
    try {
      await visit.run(() async {
        final core = await Future.wait<Object>([
          repository.loadProfileOverview(visit.targetId),
          repository.loadProfilePosts(userId: visit.targetId, limit: _pageSize),
        ]);
        visit.check();
        final profile = core[0] as CommunityProfileOverview;
        final batch = core[1] as CommunityFeedBatch;
        final postsVisible = profile.isSelf || profile.showPosts;
        String? coverUrl;

        CommunityCreatorProfile? creator;
        CommunityGoldBalance? goldBalance;
        List<CommunityQuest> quests = const <CommunityQuest>[];
        List<CommunityProfileReview> reviews = const <CommunityProfileReview>[];
        List<CommunityDraftSummary> drafts = const <CommunityDraftSummary>[];
        Map<String, int> counts = const <String, int>{};
        List<CommunityPostReferenceMetadata> references =
            const <CommunityPostReferenceMetadata>[];

        if (repository.useServerCommunityReferenceParity) {
          final postIds = (postsVisible ? batch.posts : const <CommunityPost>[])
              .map((post) => post.id)
              .toList(growable: false);
          final extras = await Future.wait<Object>([
            repository.loadCommunityCreatorProfile(visit.targetId),
            profile.isSelf
                ? repository.listMyCommunityDrafts(limit: 50)
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
          visit.check();
          creator = extras[0] as CommunityCreatorProfile;
          drafts = extras[1] as List<CommunityDraftSummary>;
          counts = extras[2] as Map<String, int>;
          references = extras[3] as List<CommunityPostReferenceMetadata>;
          coverUrl = await repository.loadCommunityProfileCoverUrl(
            visit.targetId,
          );
          visit.check();
          if (postsVisible) {
            try {
              // Reviews are a separately authorized, paginated surface. Load
              // the first page from the owning repository; a zero-length
              // placeholder leaves the Reviews tab permanently empty.
              reviews = await repository.loadCommunityProfileReviews(
                userId: visit.targetId,
                limit: _pageSize,
              );
              visit.check();
            } on CommunityOwnerOperationCancelled {
              rethrow;
            } on Object {
              // An unavailable reviews endpoint must not expose private data
              // or block the rest of an otherwise authorized profile.
              reviews = const <CommunityProfileReview>[];
            }
          }
          if (profile.isSelf) {
            try {
              final rewards = await Future.wait<Object>([
                repository.loadGoldBalance(),
                repository.loadCommunityQuests(),
              ]);
              visit.check();
              goldBalance = rewards[0] as CommunityGoldBalance;
              quests = rewards[1] as List<CommunityQuest>;
            } on CommunityOwnerOperationCancelled {
              rethrow;
            } on Object {
              // Creator rewards are an enhancement to the self-profile. The
              // profile itself remains usable when reward policy is unavailable.
              goldBalance = null;
              quests = const <CommunityQuest>[];
            }
          }
        }
        visit.check();
        if (generation != _loadGeneration) return;
        _coverUrl = coverUrl;
        _profile = profile;
        _creator = creator;
        _goldBalance = goldBalance;
        _quests = List<CommunityQuest>.unmodifiable(quests);
        _posts
          ..clear()
          ..addAll(postsVisible ? batch.posts : const <CommunityPost>[]);
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
          ..addAll(postsVisible ? reviews : const <CommunityProfileReview>[]);
        _draftSummaries
          ..clear()
          ..addAll(drafts);
        _before = postsVisible ? batch.nextBefore : null;
        _beforeId = postsVisible ? batch.nextBeforeId : null;
        _hasMore = postsVisible && batch.hasMore;
        _reviewHasMore = postsVisible && reviews.length == _pageSize;
        _reviewBefore = postsVisible ? reviews.lastOrNull?.createdAt : null;
        _reviewBeforeId = postsVisible ? reviews.lastOrNull?.reviewId : null;
      });
    } on CommunityOwnerOperationCancelled {
      // The old visit is complete; it cannot populate the new viewer.
    } finally {
      if (generation == _loadGeneration) _refreshing = false;
    }
  }

  Future<void> _refresh() async {
    if (!_sameProfileOwner) return;
    final future = _loadInitial();
    setState(() {
      _loading = future;
    });
    try {
      await future;
      await _reloadProfileActivityAfterRefresh();
    } on CommunityOwnerOperationCancelled {
      // The refreshed profile belongs to an invalidated visit.
    } on Object {
      // FutureBuilder renders the retry state.
    }
  }

  Future<void> _loadMore() async {
    final visit = _captureProfileVisit();
    final repository = visit?.repository;
    if (repository == null ||
        _loadingMore ||
        _refreshing ||
        (_profile?.isSelf != true && _profile?.showPosts != true) ||
        !_hasMore ||
        _before == null ||
        _beforeId == null) {
      return;
    }
    final generation = _loadGeneration;
    setState(() => _loadingMore = true);
    try {
      await visit!.run(() async {
        final batch = await repository.loadProfilePosts(
          userId: visit.targetId,
          before: _before,
          beforeId: _beforeId,
          limit: _pageSize,
        );
        visit.check();
        if (generation != _loadGeneration) return;
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

        visit.check();
        if (generation != _loadGeneration) return;
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
      });
    } on CommunityOwnerOperationCancelled {
      // Invalidated profile pagination never applies to a later visit.
    } catch (_) {
      if (visit?.isCurrent() == true && generation == _loadGeneration) {
        _showFailure();
      }
    } finally {
      if (visit?.isCurrent() == true && generation == _loadGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _loadMoreReviews() async {
    final visit = _captureProfileVisit();
    final repository = visit?.repository;
    if (repository == null ||
        _loadingMoreReviews ||
        _refreshing ||
        (_profile?.isSelf != true && _profile?.showPosts != true) ||
        !_reviewHasMore ||
        _reviewBefore == null ||
        _reviewBeforeId == null) {
      return;
    }
    final generation = _loadGeneration;
    setState(() => _loadingMoreReviews = true);
    try {
      await visit!.run(() async {
        final page = await repository.loadCommunityProfileReviews(
          userId: visit.targetId,
          before: _reviewBefore,
          beforeId: _reviewBeforeId,
          limit: _pageSize,
        );
        visit.check();
        if (generation != _loadGeneration) return;
        final known = _reviews.map((review) => review.reviewId).toSet();
        setState(() {
          _reviews.addAll(page.where((review) => known.add(review.reviewId)));
          _reviewHasMore = page.length == _pageSize;
          if (page.isNotEmpty) {
            _reviewBefore = page.last.createdAt;
            _reviewBeforeId = page.last.reviewId;
          }
        });
      });
    } on CommunityOwnerOperationCancelled {
      // Invalidated profile pagination never applies to a later visit.
    } catch (_) {
      if (visit?.isCurrent() == true && generation == _loadGeneration) {
        _showFailure();
      }
    } finally {
      if (visit?.isCurrent() == true && generation == _loadGeneration) {
        setState(() => _loadingMoreReviews = false);
      }
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
    key: const Key('community-member-profile-page'),
    bottomNavigationBar: BilReferenceBottomBar(
      selected: 3,
      dark: Theme.of(context).brightness == Brightness.dark,
      onSelected: (index) {
        final visit = _captureProfileVisit();
        if (visit == null) return;
        if (index == 2) {
          unawaited(showBilQuickAdd(context, originPath: '/community'));
        } else {
          context.go(BilReferenceBottomBar.routes[index]);
        }
      },
    ),
    appBar: AppBar(
      leading: const CommunityReturnButton(),
      toolbarHeight: 48,
      actions: [
        IconButton(
          tooltip: _gridMode
              ? communityText(context, 'List view', 'عرض القائمة')
              : communityText(context, 'Grid view', 'عرض الشبكة'),
          onPressed: _profileActivity.tab == _CommunityProfilePrimaryTab.posts
              ? () => setState(() => _gridMode = !_gridMode)
              : null,
          icon: Icon(
            _gridMode ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
          ),
        ),
      ],
    ),
    body: _profileOwnerCancelled
        ? const _CommunityProfileOwnerChangedBody()
        : _repository == null
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
              final visit = _captureProfileVisit();
              if (visit == null) {
                return const _CommunityProfileOwnerChangedBody();
              }
              final profile = _profile!;
              return RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CommunityMemberProfileHeader(
                          visit: visit,
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
                    if (profile.isSelf)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: _CommunitySelfQuickActions(
                            draftCount: _draftSummaries.length,
                            draftCountIsLowerBound:
                                _draftSummaries.length == 50,
                            statsAvailable: _creator != null,
                            onPosts: () {
                              if (!visit.isCurrent()) return;
                              pushCommunityPage<void>(
                                context,
                                CommunityMyPostsPage(
                                  repository: visit.repository,
                                  showProfileHeader: false,
                                ),
                              );
                            },
                            onDrafts: () {
                              if (visit.isCurrent()) {
                                context.push('/community/drafts');
                              }
                            },
                            onSaved: () {
                              if (!visit.isCurrent()) return;
                              pushCommunityPage<void>(
                                context,
                                CommunitySavedPostsPage(
                                  repository: visit.repository,
                                ),
                              );
                            },
                            onStats: _openSelfCreatorStats,
                          ),
                        ),
                      )
                    else if (_creator case final creator?)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: _CommunityCreatorPanel(
                            visit: visit,
                            creator: creator,
                            isSelf: false,
                            goldBalance: _goldBalance,
                            quests: _quests,
                          ),
                        ),
                      ),
                    ..._profilePrimaryContentSlivers(profile),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              );
            },
          ),
  );
}
