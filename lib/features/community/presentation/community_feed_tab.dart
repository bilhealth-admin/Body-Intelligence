part of 'community_hub_page.dart';

class _FeedTab extends StatefulWidget {
  const _FeedTab({
    required this.repository,
    required this.imagePicker,
    super.key,
  });
  final CommunityRepository repository;
  final CommunityPostImagePickerContract imagePicker;
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
  bool _managingPost = false;
  bool _openingComposer = false;
  @override
  bool _hasMore = false;
  @override
  bool _loadingMore = false;
  @override
  int _feedGeneration = 0;
  @override
  bool _feedRefreshing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (_policyState == null || _policyLocale != locale) {
      _policyLocale = locale;
      _policyState = widget.repository.loadCommunityPolicyState(
        localeCode: locale,
      );
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

  Future<void> _openComposer({String? tag}) async {
    if (_openingComposer || _managingPost) return;
    if (tag != null && _draft.body.isEmpty) _draft.body = '#$tag ';
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

  Future<void> _managePost(CommunityPost post, String action) async {
    if (_openingComposer || _managingPost) return;
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

  Future<void> _refresh() async {
    if (_openingComposer || _managingPost) return;
    final refreshedFeed = Future<List<CommunityPost>>.sync(_loadFirst);
    setState(() {
      _feed = refreshedFeed;
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
                  key: const PageStorageKey('community-feed-scroll'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: CommunityPolicyNotice(
                        state: _policyState!,
                        onReview: () => _reviewPolicy(),
                        onRetry: () => _refreshPolicyState(),
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
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (posts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                          child: Center(
                            child: Text(
                              communityText(
                                context,
                                'No posts yet. Start the first conversation.',
                                'لا توجد مشاركات بعد. ابدأ بأول مشاركة.',
                              ),
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
        PositionedDirectional(
          end: 20,
          bottom: 20,
          child: SafeArea(
            top: false,
            left: false,
            child: FloatingActionButton(
              key: const Key('community-create-post'),
              heroTag: 'bil-community-create-post',
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: const CircleBorder(),
              tooltip: communityText(
                context,
                'Share an experience or win',
                'شارك تجربة أو إنجازًا',
              ),
              onPressed: _openingComposer || _managingPost
                  ? null
                  : _openComposer,
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ),
      ],
    );
  }
}
