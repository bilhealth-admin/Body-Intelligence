part of 'community_hub_page.dart';

class _FeedTab extends StatefulWidget {
  const _FeedTab({
    required this.repository,
    required this.imagePicker,
    this.initialMode = CommunityFeedMode.explore,
    this.onOpenCircles,
    super.key,
  });
  final CommunityRepository repository;
  final CommunityPostImagePickerContract imagePicker;
  final CommunityFeedMode initialMode;
  final VoidCallback? onOpenCircles;
  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab>
    with
        AutomaticKeepAliveClientMixin<_FeedTab>,
        _CommunityFeedPaginationMixin {
  static const _pageSize = 40;
  @override
  late Future<List<CommunityPost>> _feed = Future<List<CommunityPost>>.sync(
    _loadFirst,
  );
  Future<CommunityPolicyState>? _policyState;
  String? _policyLocale;
  final _draft = _CommunityComposerDraft();
  @override
  final Map<String, CommunityPostReferenceMetadata> _referenceByPost =
      <String, CommunityPostReferenceMetadata>{};
  @override
  final Map<String, int> _viewCountByPost = <String, int>{};
  @override
  final Map<String, CommunityComment> _commentPreviewByPost =
      <String, CommunityComment>{};
  @override
  final Map<String, String> _membershipTierByAuthor = <String, String>{};
  late Future<List<CommunityTopic>> _suggestedTopics = widget.repository
      .loadCommunityTopics();
  bool _managingPost = false;
  bool _openingComposer = false;
  Timer? _entryWelcomeTimer;
  bool _entryWelcomeVisible = true;

  @override
  void initState() {
    super.initState();
    _selectedFeedMode = widget.initialMode;
    // Match AI Coach's entry welcome: keep Community's branded first paint
    // visible for at least 2.2 seconds without delaying the feed request itself.
    _entryWelcomeTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _entryWelcomeVisible = false);
    });
  }

  @override
  void didUpdateWidget(covariant _FeedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode &&
        _selectedFeedMode != widget.initialMode) {
      _selectedFeedMode = widget.initialMode;
      _feed = Future<List<CommunityPost>>.sync(_loadFirst);
    }
  }

  @override
  void dispose() {
    _entryWelcomeTimer?.cancel();
    super.dispose();
  }

  @override
  bool _hasMore = false;
  @override
  bool _loadingMore = false;
  @override
  int _feedGeneration = 0;
  @override
  bool _feedRefreshing = false;

  @override
  late CommunityFeedMode _selectedFeedMode;
  @override
  int? _feedCursorPriority;
  @override
  DateTime? _feedCursorCreatedAt;
  @override
  String? _feedCursorPostId;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (_policyState == null || _policyLocale != locale) {
      _policyLocale = locale;
      _policyState = _loadInitialPolicyState(locale);
    }
  }

  Future<CommunityPolicyState> _loadInitialPolicyState(String locale) async {
    try {
      return await widget.repository.loadCommunityPolicyState(
        localeCode: locale,
      );
    } on Object {
      // Entry splash can temporarily cover the feed while this request
      // finishes. Keep the policy boundary fail-closed without allowing a
      // rejected Future to escape before CommunityPolicyNotice can observe it.
      return const CommunityPolicyState.unavailable();
    }
  }

  Future<CommunityPolicyState?> _refreshPolicyState() async {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final future = widget.repository.loadCommunityPolicyState(
      localeCode: locale,
    );
    setState(() {
      _policyLocale = locale;
      _policyState = future;
    });
    try {
      return await future;
    } on Object {
      return null;
    }
  }

  Future<void> _reviewPolicy() async {
    await pushCommunityPage<void>(
      context,
      CommunitySafetyPage(repository: widget.repository),
    );
    if (mounted) await _refreshPolicyState();
  }

  Future<bool> _ensurePolicyAccepted() async {
    final state = await _refreshPolicyState();
    if (!mounted) return false;
    if (state?.permitsCommunityPublishing == true) return true;
    await _reviewPolicy();
    if (!mounted) return false;
    final refreshed = await _refreshPolicyState();
    return mounted && refreshed?.permitsCommunityPublishing == true;
  }

  Future<void> _openComposer({String? tag, String? circle}) async {
    if (_openingComposer || _managingPost) return;
    if (tag != null) {
      _draft.topicSlugs
        ..clear()
        ..add(tag);
    }
    if (circle != null) {
      _draft.circleSlug = circle;
    }
    setState(() => _openingComposer = true);
    try {
      if (!await _ensurePolicyAccepted()) return;
      if (!mounted) return;
      final submitted = await pushCommunityPage<bool>(
        context,
        _CommunityPostComposerPage(
          repository: widget.repository,
          imagePicker: widget.imagePicker,
          draft: _draft,
        ),
      );
      if (!mounted || submitted != true) return;
      setState(() {
        _feed = Future<List<CommunityPost>>.sync(_loadFirst);
      });
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Post submitted for human review. Only you can see it until it is approved.',
              'تم إرسال المنشور للمراجعة البشرية. لن يراه سواك حتى يتم اعتماده.',
            ),
          ),
          action: SnackBarAction(
            label: communityText(context, 'My posts', 'منشوراتي'),
            onPressed: _openMyPosts,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingComposer = false);
    }
  }

  Future<void> _openMyPosts() async {
    await pushCommunityPage<void>(
      context,
      CommunityMyPostsPage(repository: widget.repository),
    );
  }

  Future<void> _openTopic(CommunityTopic topic) async {
    await pushCommunityPage<void>(
      context,
      _CommunityTopicPage(
        repository: widget.repository,
        topic: topic,
        onComposeTopic: (slug) => _openComposer(tag: slug),
      ),
    );
  }

  Future<void> _managePost(CommunityPost post, String action) async {
    if (_openingComposer || _managingPost) return;
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
        await widget.repository.report(
          targetKind: 'post',
          targetId: post.id,
          reason: 'user_reported_from_feed',
        );
      } else if (action == 'delete') {
        await widget.repository.deletePost(post.id);
        final refreshedFeed = Future<List<CommunityPost>>.sync(_loadFirst);
        if (mounted) {
          setState(() {
            _feed = refreshedFeed;
          });
        }
      } else if (action == 'block') {
        await widget.repository.blockMember(post.authorId);
        final refreshedFeed = Future<List<CommunityPost>>.sync(_loadFirst);
        if (mounted) {
          setState(() {
            _feed = refreshedFeed;
          });
        }
      } else if (action == 'moderate_remove') {
        await widget.repository.removePublishedPostAsModerator(
          postId: post.id,
          reason: moderationReason!,
        );
        final refreshedFeed = Future<List<CommunityPost>>.sync(_loadFirst);
        if (mounted) setState(() => _feed = refreshedFeed);
      } else if (action == 'moderate_hide') {
        await widget.repository.hidePublishedPostAsModerator(
          postId: post.id,
          reason: moderationReason!,
        );
        final refreshedFeed = Future<List<CommunityPost>>.sync(_loadFirst);
        if (mounted) setState(() => _feed = refreshedFeed);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (action) {
            'report' => communityText(
              context,
              'Report sent for review.',
              'تم إرسال البلاغ للمراجعة.',
            ),
            'block' => communityText(
              context,
              'Member blocked.',
              'تم حظر العضو.',
            ),
            'moderate_remove' => communityText(
              context,
              'Post removed by moderation.',
              'تمت إزالة المنشور بواسطة الإشراف.',
            ),
            'moderate_hide' => communityText(
              context,
              'Post hidden by moderation.',
              'تم إخفاء المنشور بواسطة الإشراف.',
            ),
            _ => communityText(context, 'Post deleted.', 'تم حذف المشاركة.'),
          }),
        ),
      );
    } catch (_) {
      if (!mounted) return;
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
    } finally {
      if (mounted) setState(() => _managingPost = false);
    }
  }

  Future<void> _selectFeedMode(CommunityFeedMode mode) async {
    if (mode == _selectedFeedMode || _openingComposer || _managingPost) return;
    setState(() {
      _selectedFeedMode = mode;
      _feed = Future<List<CommunityPost>>.sync(_loadFirst);
    });
    try {
      await _feed;
    } on Object {
      // FutureBuilder presents mode-specific load errors.
    }
  }

  String _feedModeLabel(CommunityFeedMode mode) => switch (mode) {
    CommunityFeedMode.forYou => communityText(context, 'For You', 'لك'),
    CommunityFeedMode.following => communityText(
      context,
      'Following',
      'المتابَعون',
    ),
    CommunityFeedMode.friends => communityText(context, 'Friends', 'الأصدقاء'),
    CommunityFeedMode.explore => communityText(context, 'Explore', 'استكشاف'),
  };

  String _emptyFeedMessage() => switch (_selectedFeedMode) {
    CommunityFeedMode.following => communityText(
      context,
      'Follow members to see their approved posts here.',
      'تابع أعضاءً لتظهر منشوراتهم المعتمدة هنا.',
    ),
    CommunityFeedMode.friends => communityText(
      context,
      'Accepted friends will appear here when they publish.',
      'ستظهر منشورات أصدقائك المقبولين هنا عند النشر.',
    ),
    CommunityFeedMode.forYou => communityText(
      context,
      'Nothing personalized yet. Follow people, topics, or Circles to shape this feed.',
      'لا توجد توصيات مخصصة بعد. تابع أشخاصًا أو مواضيع أو دوائر لتخصيص هذا الموجز.',
    ),
    CommunityFeedMode.explore => communityText(
      context,
      'No approved posts yet. Start the first conversation.',
      'لا توجد منشورات معتمدة بعد. ابدأ أول محادثة.',
    ),
  };

  Future<void> _refresh() async {
    if (_openingComposer || _managingPost) return;
    final refreshedFeed = Future<List<CommunityPost>>.sync(_loadFirst);
    setState(() {
      _feed = refreshedFeed;
      _suggestedTopics = widget.repository.loadCommunityTopics();
    });
    try {
      await refreshedFeed;
    } on Object {
      // FutureBuilder presents the load error; the refresh gesture must not
      // additionally report an unhandled asynchronous exception.
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_entryWelcomeVisible) {
      return const CommunityWelcome();
    }
    return Stack(
      children: [
        FutureBuilder<List<CommunityPost>>(
          future: _feed,
          builder: (context, snapshot) {
            final posts = snapshot.data ?? const <CommunityPost>[];
            final loading = snapshot.connectionState != ConnectionState.done;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: Semantics(
                key: const Key('community-public-feed'),
                label: communityText(
                  context,
                  'Shared with BIL members',
                  'مشاركات أعضاء BIL',
                ),
                child: CustomScrollView(
                  key: PageStorageKey(
                    'community-feed-scroll-${_selectedFeedMode.wireValue}',
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: CommunityPolicyNotice(
                        state: _policyState!,
                        onReview: () => _reviewPolicy(),
                        onRetry: () => _refreshPolicyState(),
                      ),
                    ),
                    if (!loading || snapshot.hasData)
                      SliverToBoxAdapter(
                        child: _CommunityFeedReferenceHeader(
                          repository: widget.repository,
                          posts: posts,
                          topics: _suggestedTopics,
                          enabled: !_openingComposer && !_managingPost,
                          onCompose: _openComposer,
                          onOpenTopic: _openTopic,
                          onOpenCircles: widget.onOpenCircles,
                        ),
                      ),
                    if (loading && snapshot.hasData)
                      const SliverToBoxAdapter(
                        child: LinearProgressIndicator(),
                      ),
                    if (snapshot.hasError)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _InlineError(onRetry: _refresh),
                      )
                    else if (loading && !snapshot.hasData)
                      const SliverToBoxAdapter(child: CommunityWelcome())
                    else if (posts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                          child: Center(
                            child: Text(
                              _emptyFeedMessage(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          _hasMore ? 12 : 100,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final post = posts[index];
                            return Padding(
                              key: ValueKey(post.id),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _CommunityPostCard(
                                post: post,
                                repository: widget.repository,
                                currentUserId: widget.repository.currentUserId,
                                referenceMetadata: _referenceByPost[post.id],
                                viewCount: _viewCountByPost[post.id],
                                commentPreview: _commentPreviewByPost[post.id],
                                authorMembershipTier:
                                    _membershipTierByAuthor[post.authorId],
                                actionsEnabled:
                                    !_openingComposer && !_managingPost,
                                onAction: (value) => _managePost(post, value),
                              ),
                            );
                          }, childCount: posts.length),
                        ),
                      ),
                    if (!snapshot.hasError && posts.isNotEmpty && _hasMore)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          child: Center(
                            child: TextButton.icon(
                              key: const Key('community-feed-load-more'),
                              onPressed: _loadingMore || _feedRefreshing
                                  ? null
                                  : () => _loadMore(posts),
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
                                  'Load older posts',
                                  'تحميل منشورات أقدم',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

      ],
    );
  }
}
