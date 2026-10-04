part of 'community_hub_page.dart';

class _CommunityPostCard extends StatefulWidget {
  const _CommunityPostCard({
    required this.post,
    required this.repository,
    required this.currentUserId,
    required this.actionsEnabled,
    required this.onAction,
    this.referenceMetadata,
    this.viewCount,
    this.commentPreview,
    this.onSavedChanged,
    this.showModerationStatus = false,
  });

  final CommunityPost post;
  final CommunityRepository repository;
  final String currentUserId;
  final bool actionsEnabled;
  final ValueChanged<String> onAction;
  final CommunityPostReferenceMetadata? referenceMetadata;
  final int? viewCount;
  final CommunityComment? commentPreview;
  final ValueChanged<bool>? onSavedChanged;
  final bool showModerationStatus;

  @override
  State<_CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<_CommunityPostCard> {
  late final Future<bool> _moderator = widget.repository.isCommunityModerator();
  late CommunityPostStats _stats = CommunityPostStats(
    postId: widget.post.id,
    likeCount: widget.post.likeCount,
    liked: widget.post.liked,
    commentCount: widget.post.commentCount,
  );
  bool _liking = false;
  late bool _saved = widget.post.saved;
  bool _saving = false;
  bool _sharing = false;
  bool _openingDetail = false;

  bool get _socialActionsAvailable =>
      widget.actionsEnabled &&
      widget.post.moderationStatus == CommunityPostModerationStatus.approved;

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
    if (_liking || !_socialActionsAvailable) return;
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
    if (_saving || !_socialActionsAvailable) return;
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

  Future<void> _sharePost(BuildContext anchorContext) async {
    if (_sharing ||
        !widget.actionsEnabled ||
        widget.post.moderationStatus !=
            CommunityPostModerationStatus.approved) {
      return;
    }
    _sharing = true;
    try {
      final box = anchorContext.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          text:
              '${widget.post.authorName ?? communityText(context, 'BIL member', 'عضو BIL')}\n\n${widget.post.body}',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
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
    } finally {
      _sharing = false;
    }
  }

  Future<void> _openDetail() async {
    if (!_socialActionsAvailable || _openingDetail) return;
    _openingDetail = true;
    try {
      await pushCommunityPage<void>(
        context,
        _CommunityPostDetailPage(
          post: widget.post,
          initialStats: _stats,
          repository: widget.repository,
          referenceMetadata: widget.referenceMetadata,
        ),
      );
      if (!mounted) return;
      try {
        final refreshed = await widget.repository.loadPostStats([
          widget.post.id,
        ]);
        if (mounted && refreshed.length == 1) {
          setState(() => _stats = refreshed.single);
        }
      } on Object {
        // The detail action already completed. A count refresh may retry later.
      }
    } finally {
      _openingDetail = false;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
      color: CommunitySapphire.paper(context),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BilAccountAvatar(
                radius: 24,
                networkUrl: widget.post.authorAvatarUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _NaturalCommunityText(
                          widget.post.authorName ??
                              (widget.post.authorId == widget.currentUserId
                                  ? communityText(context, 'You', 'أنت')
                                  : communityText(
                                      context,
                                      'BIL member',
                                      'عضو BIL',
                                    )),
                        ),
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatShortDate(widget.post.createdAt.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    if (widget.post.authorHandle != null)
                      Text(
                        '@${widget.post.authorHandle}',
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (widget.post.authorId == widget.currentUserId &&
                        (widget.showModerationStatus ||
                            widget.post.moderationStatus !=
                                CommunityPostModerationStatus.approved)) ...[
                      const SizedBox(height: 4),
                      _CommunityPostStatusChip(post: widget.post),
                    ] else if (widget.post.authorId != widget.currentUserId)
                      _CommunityAuthorRelationshipAction(
                        post: widget.post,
                        repository: widget.repository,
                        enabled: widget.actionsEnabled,
                      ),
                  ],
                ),
              ),
              FutureBuilder<bool>(
                future: _moderator,
                builder: (context, snapshot) => PopupMenuButton<String>(
                  key: Key('community-post-actions-${widget.post.id}'),
                  icon: const Icon(Icons.more_horiz_rounded),
                  enabled: widget.actionsEnabled,
                  onSelected: widget.onAction,
                  itemBuilder: (_) => [
                    if (widget.post.authorId == widget.currentUserId)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(communityText(context, 'Delete', 'حذف')),
                      )
                    else ...[
                      PopupMenuItem(
                        value: 'report',
                        child: Text(communityText(context, 'Report', 'إبلاغ')),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Text(
                          communityText(context, 'Block member', 'حظر العضو'),
                        ),
                      ),
                    ],
                    if (snapshot.data == true &&
                        widget.post.authorId != widget.currentUserId) ...[
                      PopupMenuItem(
                        value: 'moderate_hide',
                        child: Text(
                          communityText(context, 'Hide post', 'إخفاء المنشور'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'moderate_remove',
                        child: Text(
                          communityText(
                            context,
                            'Remove post',
                            'إزالة المنشور',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (widget.post.locationLabel case final location?) ...[
            const SizedBox(height: 8),
            Row(
              key: Key('community-post-location-${widget.post.id}'),
              children: [
                const Icon(Icons.location_on_outlined, size: 17),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (widget.referenceMetadata case final metadata?) ...[
            const SizedBox(height: 10),
            _CommunityPostReferenceBlock(
              metadata: metadata,
              repository: widget.repository,
              compact: true,
            ),
          ],
          if (widget.post.hasImage) ...[
            const SizedBox(height: 10),
            _CommunityFeedImage(post: widget.post),
          ],
          const SizedBox(height: 12),
          _ExpandableCommunityPostBody(
            postId: widget.post.id,
            body: widget.post.body,
          ),
          if (widget.post.poll case final poll?) ...[
            const SizedBox(height: 12),
            _CommunityPollPanel(
              poll: poll,
              repository: widget.repository,
              compact: true,
            ),
          ],
          const SizedBox(height: 4),
          if (widget.commentPreview case final preview?) ...[
            const SizedBox(height: 5),
            InkWell(
              key: Key('community-post-comment-preview-${widget.post.id}'),
              borderRadius: BorderRadius.circular(14),
              onTap: _socialActionsAvailable ? _openDetail : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BilAccountAvatar(
                      radius: 16,
                      networkUrl: preview.authorAvatarUrl,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preview.authorName ??
                                communityText(context, 'BIL member', 'عضو BIL'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preview.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (preview.replyCount > 0) ...[
                      const SizedBox(width: 7),
                      Text(
                        '+${preview.replyCount}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                key: Key('community-post-like-${widget.post.id}'),
                style: TextButton.styleFrom(
                  foregroundColor: _stats.liked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: _socialActionsAvailable && !_liking
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
                label: Text(
                  '${_stats.likeCount}',
                  semanticsLabel:
                      '${communityText(context, 'Like', 'إعجاب')}: ${_stats.likeCount}',
                ),
              ),
              if (widget.viewCount != null) ...[
                const Icon(Icons.visibility_outlined, size: 18),
                const SizedBox(width: 4),
                Text(
                  widget.viewCount.toString(),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
              TextButton.icon(
                key: Key('community-post-comments-${widget.post.id}'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                ),
                onPressed: _socialActionsAvailable ? _openDetail : null,
                icon: const Icon(Icons.mode_comment_outlined),
                label: Text(
                  '${_stats.commentCount}',
                  semanticsLabel:
                      '${communityText(context, 'Comments', 'التعليقات')}: ${_stats.commentCount}',
                ),
              ),
              IconButton(
                key: Key('community-post-save-${widget.post.id}'),
                color: _saved
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                onPressed: _socialActionsAvailable && !_saving
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
              Builder(
                builder: (shareContext) => IconButton(
                  key: Key('community-post-share-${widget.post.id}'),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  onPressed:
                      widget.actionsEnabled &&
                          widget.post.moderationStatus ==
                              CommunityPostModerationStatus.approved
                      ? () => _sharePost(shareContext)
                      : null,
                  tooltip: communityText(
                    context,
                    'Share post',
                    'مشاركة المنشور',
                  ),
                  icon: const Icon(Icons.share_outlined),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
