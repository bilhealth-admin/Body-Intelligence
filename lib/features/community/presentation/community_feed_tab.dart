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
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunitySafetyPage(repository: widget.repository),
      ),
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
      final submitted = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => _CommunityPostComposerPage(
            repository: widget.repository,
            imagePicker: widget.imagePicker,
            draft: _draft,
          ),
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
        ),
      );
    } finally {
      if (mounted) setState(() => _openingComposer = false);
    }
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: OutlinedButton.icon(
                        key: const Key('community-browse-topics'),
                        onPressed: _openingComposer || _managingPost
                            ? null
                            : () => CommunityTaxonomySheet.show(
                                context,
                                onSelectTag: (tag) => _openComposer(tag: tag),
                              ),
                        icon: const Icon(Icons.grid_view_rounded),
                        label: Text(
                          CommunityTaxonomySheet.browseLabel(context),
                        ),
                      ),
                    ),
                  ),
                  if (loading && snapshot.hasData)
                    const SliverToBoxAdapter(child: LinearProgressIndicator()),
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
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final post = posts[index];
                          return Padding(
                            key: ValueKey(post.id),
                            padding: const EdgeInsets.only(bottom: 18),
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
                            onPressed: _loadingMore
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

class _CommunityPostCard extends StatefulWidget {
  const _CommunityPostCard({
    required this.post,
    required this.repository,
    required this.currentUserId,
    required this.actionsEnabled,
    required this.onAction,
    this.onSavedChanged,
  });

  final CommunityPost post;
  final CommunityRepository repository;
  final String currentUserId;
  final bool actionsEnabled;
  final ValueChanged<String> onAction;
  final ValueChanged<bool>? onSavedChanged;

  @override
  State<_CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<_CommunityPostCard> {
  late CommunityPostStats _stats = CommunityPostStats(
    postId: widget.post.id,
    likeCount: widget.post.likeCount,
    liked: widget.post.liked,
    commentCount: widget.post.commentCount,
  );
  bool _liking = false;
  late bool _saved = widget.post.saved;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _CommunityPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.likeCount != widget.post.likeCount ||
        oldWidget.post.liked != widget.post.liked ||
        oldWidget.post.commentCount != widget.post.commentCount ||
        oldWidget.post.saved != widget.post.saved) {
      _stats = CommunityPostStats(
        postId: widget.post.id,
        likeCount: widget.post.likeCount,
        liked: widget.post.liked,
        commentCount: widget.post.commentCount,
      );
      _saved = widget.post.saved;
    }
  }

  Future<void> _toggleLike() async {
    if (_liking || !widget.actionsEnabled) return;
    setState(() => _liking = true);
    try {
      final stats = await widget.repository.setPostLiked(
        widget.post.id,
        liked: !_stats.liked,
      );
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not update this reaction. Try again.',
              'تعذر تحديث التفاعل. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _toggleSaved() async {
    if (_saving || !widget.actionsEnabled) return;
    setState(() => _saving = true);
    try {
      final result = await widget.repository.setPostSaved(
        widget.post.id,
        saved: !_saved,
      );
      if (mounted) {
        setState(() => _saved = result.saved);
        widget.onSavedChanged?.call(result.saved);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not update saved posts. Try again.',
              'تعذر تحديث المنشورات المحفوظة. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sharePost() async {
    if (!widget.actionsEnabled ||
        widget.post.moderationStatus !=
            CommunityPostModerationStatus.approved) {
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${widget.post.authorName ?? 'BIL member'}\n\n${widget.post.body}',
      ),
    );
  }

  Future<void> _openDetail() async {
    if (!widget.actionsEnabled) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _CommunityPostDetailPage(
          post: widget.post,
          initialStats: _stats,
          repository: widget.repository,
        ),
      ),
    );
    if (!mounted) return;
    try {
      final refreshed = await widget.repository.loadPostStats([widget.post.id]);
      if (mounted && refreshed.length == 1) {
        setState(() => _stats = refreshed.single);
      }
    } on Object {
      // The detail action already completed. A count refresh may retry later.
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BilAccountAvatar(
                radius: 20,
                networkUrl: widget.post.authorAvatarUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NaturalCommunityText(
                      widget.post.authorName ??
                          communityText(context, 'BIL member', 'عضو BIL'),
                    ),
                    if (widget.post.authorHandle != null)
                      Text(
                        '@${widget.post.authorHandle}',
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatShortDate(widget.post.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (widget.post.authorId == widget.currentUserId) ...[
                      const SizedBox(height: 6),
                      _CommunityPostStatusChip(post: widget.post),
                    ] else
                      _CommunityAuthorRelationshipAction(
                        post: widget.post,
                        repository: widget.repository,
                        enabled: widget.actionsEnabled,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: Key('community-post-actions-${widget.post.id}'),
                enabled: widget.actionsEnabled,
                onSelected: widget.onAction,
                itemBuilder: (_) => widget.post.authorId == widget.currentUserId
                    ? [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(communityText(context, 'Delete', 'حذف')),
                        ),
                      ]
                    : [
                        PopupMenuItem(
                          value: 'report',
                          child: Text(
                            communityText(context, 'Report', 'إبلاغ'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Text(
                            communityText(context, 'Block member', 'حظر العضو'),
                          ),
                        ),
                      ],
              ),
            ],
          ),
          if (widget.post.hasImage) ...[
            const SizedBox(height: 16),
            _CommunityFeedImage(post: widget.post),
          ],
          const SizedBox(height: 14),
          _ExpandableCommunityPostBody(
            postId: widget.post.id,
            body: widget.post.body,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                key: Key('community-post-like-${widget.post.id}'),
                onPressed: widget.actionsEnabled && !_liking
                    ? _toggleLike
                    : null,
                icon: _liking
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _stats.liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                label: Text('${_stats.likeCount}'),
              ),
              TextButton.icon(
                key: Key('community-post-comments-${widget.post.id}'),
                onPressed: widget.actionsEnabled ? _openDetail : null,
                icon: const Icon(Icons.mode_comment_outlined),
                label: Text('${_stats.commentCount}'),
              ),
              const Spacer(),
              IconButton(
                key: Key('community-post-save-${widget.post.id}'),
                onPressed: widget.actionsEnabled && !_saving
                    ? _toggleSaved
                    : null,
                tooltip: _saved
                    ? communityText(
                        context,
                        'Remove from saved',
                        'إزالة من المحفوظات',
                      )
                    : communityText(context, 'Save post', 'حفظ المنشور'),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                      ),
              ),
              IconButton(
                key: Key('community-post-share-${widget.post.id}'),
                onPressed:
                    widget.actionsEnabled &&
                        widget.post.moderationStatus ==
                            CommunityPostModerationStatus.approved
                    ? _sharePost
                    : null,
                tooltip: communityText(context, 'Share post', 'مشاركة المنشور'),
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
