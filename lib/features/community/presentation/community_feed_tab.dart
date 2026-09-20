part of 'community_hub_page.dart';

class _FeedTab extends StatefulWidget {
  const _FeedTab({required this.repository, required this.imagePicker, super.key});
  final CommunityRepository repository;
  final CommunityPostImagePickerContract imagePicker;
  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> with AutomaticKeepAliveClientMixin<_FeedTab> {
  late Future<List<CommunityPost>> _feed = Future<List<CommunityPost>>.sync(() => widget.repository.loadFeed());
  final _draft = _CommunityComposerDraft();
  bool _managingPost = false;
  bool _openingComposer = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _openComposer({String? tag}) async {
    if (_openingComposer || _managingPost) return;
    if (tag != null && _draft.body.isEmpty) _draft.body = '#$tag ';
    setState(() => _openingComposer = true);
    try {
      final submitted = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
        builder: (_) => _CommunityPostComposerPage(
          repository: widget.repository, imagePicker: widget.imagePicker,
          draft: _draft,
        ),
      ));
      if (!mounted || submitted != true) return;
      setState(() {
        _feed = Future<List<CommunityPost>>.sync(
          () => widget.repository.loadFeed(),
        );
      });
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(communityText(context,
        'Post submitted for human review. Only you can see it until it is approved.',
        'تم إرسال المنشور للمراجعة البشرية. لن يراه سواك حتى يتم اعتماده.'))));
    } finally {
      if (mounted) setState(() => _openingComposer = false);
    }
  }

  Future<void> _managePost(CommunityPost post, String action) async {
    if (_openingComposer || _managingPost) return;
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(communityText(context, 'Delete post?', 'حذف المشاركة؟')),
          content: Text(
            communityText(
              context,
              'This removes your post from Community.',
              'سيؤدي ذلك إلى إزالة مشاركتك من المجتمع.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(communityText(context, 'Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(communityText(context, 'Delete', 'حذف')),
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
        final refreshedFeed = Future<List<CommunityPost>>.sync(() => widget.repository.loadFeed());
        if (mounted) {
          setState(() {
            _feed = refreshedFeed;
          });
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'report'
                ? communityText(
                    context,
                    'Report sent for review.',
                    'تم إرسال البلاغ للمراجعة.',
                  )
                : communityText(context, 'Post deleted.', 'تم حذف المشاركة.'),
          ),
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
    final refreshedFeed = Future<List<CommunityPost>>.sync(() => widget.repository.loadFeed());
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: OutlinedButton.icon(
                        key: const Key('community-browse-topics'),
                        onPressed: _openingComposer || _managingPost ? null
                          : () => CommunityTaxonomySheet.show(context,
                            onSelectTag: (tag) => _openComposer(tag: tag)),
                        icon: const Icon(Icons.grid_view_rounded),
                        label: Text(CommunityTaxonomySheet.browseLabel(context)),
                      ),
                    ),
                  ),
                  if (loading && snapshot.hasData)
                    const SliverToBoxAdapter(child: LinearProgressIndicator()),
                  if (snapshot.hasError)
                    SliverFillRemaining(hasScrollBody: false,
                      child: _InlineError(onRetry: _refresh))
                  else if (loading && !snapshot.hasData)
                    const SliverFillRemaining(hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()))
                  else if (posts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                        child: Center(child: Text(communityText(context,
                          'No posts yet. Start the first conversation.',
                          'لا توجد مشاركات بعد. ابدأ بأول مشاركة.'),
                          textAlign: TextAlign.center)),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      sliver: SliverList(delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final post = posts[index];
                          return Padding(
                            key: ValueKey(post.id),
                            padding: const EdgeInsets.only(bottom: 18),
                            child: _CommunityPostCard(
                              post: post, currentUserId: widget.repository.currentUserId,
                              actionsEnabled: !_openingComposer && !_managingPost,
                              onAction: (value) => _managePost(post, value),
                            ),
                          );
                        }, childCount: posts.length,
                      )),
                    ),
                ],
              ),
            );
          },
        ),
        PositionedDirectional(
          end: 20, bottom: 20,
          child: SafeArea(top: false, left: false,
            child: FloatingActionButton(
              key: const Key('community-create-post'),
              heroTag: 'bil-community-create-post',
              tooltip: communityText(context,
                'Share an experience or win', 'شارك تجربة أو إنجازًا'),
              onPressed: _openingComposer || _managingPost ? null : _openComposer,
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.post,
    required this.currentUserId,
    required this.actionsEnabled,
    required this.onAction,
  });

  final CommunityPost post;
  final String currentUserId;
  final bool actionsEnabled;
  final ValueChanged<String> onAction;

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
              BilAccountAvatar(radius: 20, networkUrl: post.authorAvatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NaturalCommunityText(
                      post.authorName ??
                          communityText(context, 'BIL member', 'عضو BIL'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatShortDate(post.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (post.authorId == currentUserId) ...[
                      const SizedBox(height: 6),
                      _CommunityPostStatusChip(post: post),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: Key('community-post-actions-${post.id}'),
                enabled: actionsEnabled,
                onSelected: onAction,
                itemBuilder: (_) => post.authorId == currentUserId
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
                      ],
              ),
            ],
          ),
          if (post.hasImage) ...[
            const SizedBox(height: 16),
            _CommunityFeedImage(post: post),
          ],
          const SizedBox(height: 14),
          SelectableText(post.body,
            key: ValueKey('community-post-body-${post.id}'),
            style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    ),
  );
}

class _CommunityPostStatusChip extends StatelessWidget {
  const _CommunityPostStatusChip({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final (icon, english, arabic) = switch (post.moderationStatus) {
      CommunityPostModerationStatus.pending => (
        Icons.schedule_rounded,
        'Pending review',
        'بانتظار المراجعة',
      ),
      CommunityPostModerationStatus.approved => (
        Icons.verified_outlined,
        'Approved',
        'معتمد',
      ),
      CommunityPostModerationStatus.rejected => (
        Icons.cancel_outlined,
        'Rejected',
        'مرفوض',
      ),
    };
    final localizedStatus = communityText(context, english, arabic);
    final statusLabel = communityText(
      context,
      'Post status: {status}',
      'حالة المنشور: {status}',
    ).replaceAll('{status}', localizedStatus);
    return Semantics(
      label: statusLabel,
      child: Chip(
        key: Key('community-post-status-${post.id}'),
        avatar: Icon(icon, size: 16),
        visualDensity: VisualDensity.compact,
        label: Text(localizedStatus),
      ),
    );
  }
}

class _CommunityFeedImage extends StatelessWidget {
  const _CommunityFeedImage({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final ratio = (post.mediaAspectRatio ?? 1).clamp(0.8, 1.91).toDouble();
    final url = post.mediaUrl;
    return Semantics(
      image: true,
      label: communityText(context, 'Post photo', 'صورة المنشور'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          key: Key('community-post-image-${post.id}'),
          aspectRatio: ratio,
          child: url == null
              ? const _CommunityImageFallback()
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const _CommunityImageFallback(),
                ),
        ),
      ),
    );
  }
}

class _CommunityImageFallback extends StatelessWidget {
  const _CommunityImageFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined),
            const SizedBox(height: 6),
            Text(
              communityText(context, 'Photo unavailable', 'الصورة غير متاحة'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
