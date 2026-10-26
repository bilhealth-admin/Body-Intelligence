part of 'community_hub_page.dart';

extension _CommunityPostDetailRendering on _CommunityPostDetailPageState {
  Widget buildCommunityPostDetail(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const CommunityReturnButton(),
      title: Text(communityText(context, 'Post', 'منشور')),
    ),
    body: FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            _comments.isEmpty) {
          return const Center(child: BilFeatureWelcomeStatus());
        }
        if (snapshot.hasError && _comments.isEmpty) {
          return Center(
            child: FilledButton.icon(
              key: const Key('community-post-detail-retry'),
              onPressed: _retry,
              icon: const BilNavigationFeedback(
                child: Icon(Icons.refresh_rounded),
              ),
              label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: BilRefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  key: const Key('community-post-detail-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    if (_focusLoading || _focusUnavailable || _focusFailed) ...[
                      Row(
                        children: [
                          if (_focusLoading)
                            const Padding(
                              padding: EdgeInsetsDirectional.only(end: 8),
                              child: SizedBox.square(
                                dimension: 18,
                                child: BilFeatureWelcomeStatus(),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              communityText(
                                context,
                                _focusLoading
                                    ? 'Loading the comment from this notification…'
                                    : _focusUnavailable
                                    ? 'This comment is no longer available.'
                                    : 'Could not open this comment. Try again.',
                                _focusLoading
                                    ? 'جارٍ تحميل تعليق الإشعار…'
                                    : _focusUnavailable
                                    ? 'هذا التعليق لم يعد متاحًا.'
                                    : 'تعذر فتح التعليق. حاول مجددًا.',
                              ),
                            ),
                          ),
                          if (_focusLoading)
                            IconButton(
                              key: const Key(
                                'community-notification-focus-cancel',
                              ),
                              tooltip: communityText(
                                context,
                                'Cancel comment loading',
                                'إلغاء تحميل التعليق',
                              ),
                              onPressed: _cancelNotificationFocus,
                              icon: const Icon(Icons.close_rounded),
                            )
                          else
                            IconButton(
                              key: const Key(
                                'community-notification-focus-retry',
                              ),
                              tooltip: communityText(
                                context,
                                'Retry comment loading',
                                'إعادة تحميل التعليق',
                              ),
                              onPressed: () => unawaited(
                                _loadNotificationFocus(_loadGeneration),
                              ),
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_focusedRoot case final root?) ...[
                      Text(
                        communityText(
                          context,
                          'From this notification',
                          'من هذا الإشعار',
                        ),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      // Build only this focused thread eagerly so ensureVisible
                      // reaches a reply even after a long root. Other threads
                      // retain their existing lazy list behavior.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _commentThreadTiles(root),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _CommunityPostDetailHeader(
                      post: widget.post,
                      stats: _stats,
                      referenceMetadata: widget.referenceMetadata,
                      authorProfile: _authorProfile,
                      authorMembershipTier: _authorMembershipTier,
                      followBusy: _followBusy,
                      viewCount: _viewCount,
                      liking: _likingPost,
                      saved: _savedPost,
                      saving: _savingPost,
                      sharing: _sharingPost,
                      managingPost: _managingPost,
                      onLike: _togglePostLike,
                      onSave: () => unawaited(
                        _CommunityPostDetailReferenceActions(
                          this,
                        )._togglePostSaved(),
                      ),
                      onShare: (anchorContext) =>
                          _CommunityPostDetailReferenceActions(
                            this,
                          )._sharePost(anchorContext),
                      onPostAction: (action) => unawaited(
                        _CommunityPostDetailReferenceActions(
                          this,
                        )._managePostAction(action),
                      ),
                      onToggleFollow: _toggleAuthorFollow,
                      repository: widget.repository,
                      ownerIsCurrent: () => _detailOwnerIsCurrent,
                      ownerChanges: widget.ownerChanges,
                    ),
                    if (widget.post.poll case final poll?) ...[
                      const SizedBox(height: 16),
                      _CommunityPollPanel(
                        ownerIsCurrent: () => _detailOwnerIsCurrent,
                        poll: poll,
                        repository: widget.repository,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      communityText(context, 'Comments', 'التعليقات'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    if (_comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          communityText(
                            context,
                            'No comments yet. Start a respectful conversation.',
                            'لا توجد تعليقات بعد. ابدأ حوارًا محترمًا.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      for (final root in _rootComments.where(
                        (root) => root.id != _focusedRoot?.id,
                      ))
                        ..._commentThreadTiles(root),
                    if (_hasMore)
                      Center(
                        child: TextButton.icon(
                          key: const Key('community-comments-load-more'),
                          onPressed: _loadingMore ? null : _loadMore,
                          icon: _loadingMore
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: BilFeatureWelcomeStatus(),
                                )
                              : const BilNavigationFeedback(
                                  child: Icon(Icons.expand_more_rounded),
                                ),
                          label: Text(
                            communityText(
                              context,
                              'Load more comment threads',
                              'تحميل مزيد من سلاسل التعليقات',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyingTo != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                communityText(
                                  context,
                                  'Replying to {member}',
                                  'الرد على {member}',
                                ).replaceAll(
                                  '{member}',
                                  _replyingTo!.authorHandle == null
                                      ? _replyingTo!.authorName ??
                                            communityText(
                                              context,
                                              'BIL member',
                                              'عضو BIL',
                                            )
                                      : '@${_replyingTo!.authorHandle}',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: communityText(
                                context,
                                'Cancel reply',
                                'إلغاء الرد',
                              ),
                              onPressed: () => _setDetailState(() {
                                _replyingTo = null;
                                _clientId = null;
                              }),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('community-comment-composer'),
                              controller: _composer,
                              focusNode: _composerFocus,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: CommunityTextLimits.bodyCodePointLimit,
                              maxLengthEnforcement: MaxLengthEnforcement.none,
                              buildCounter: communityBodyCounter(_composer),
                              enabled: !_submitting && !_refreshing,
                              textDirection:
                                  _composerDirection ??
                                  Directionality.of(context),
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (value) {
                                final error =
                                    CommunityTextLimits.exceedsBodyLimit(value)
                                    ? communityBodyLimitText(context)
                                    : null;
                                final direction =
                                    BilWrittenLanguageResolver.directionFor(
                                      value,
                                      fallback: Directionality.of(context),
                                    );
                                if (direction != _composerDirection ||
                                    _composerError != error) {
                                  _setDetailState(() {
                                    _composerDirection = direction;
                                    _composerError = error;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                hintText: communityText(
                                  context,
                                  'Write a comment',
                                  'اكتب تعليقًا',
                                ),
                                errorText: _composerError,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            key: const Key('community-comment-submit'),
                            tooltip: communityText(
                              context,
                              'Send comment',
                              'إرسال التعليق',
                            ),
                            onPressed: _submitting || _refreshing
                                ? null
                                : _submitComment,
                            icon: _submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: BilFeatureWelcomeStatus(),
                                  )
                                : const BilNavigationFeedback(
                                    child: Icon(Icons.send_rounded),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
  List<Widget> _commentThreadTiles(CommunityComment root) => [
    _CommunityCommentTile(
      key: root.id == widget.focusCommentId
          ? _notificationFocusKey
          : ValueKey(root.id),
      comment: root,
      ownerId: widget.repository.currentUserId,
      ownerIsCurrent: () => _detailOwnerIsCurrent,
      ownerChanges: widget.ownerChanges,
      membershipTier: _membershipTierByUser[root.authorId],
      mine: root.authorId == widget.repository.currentUserId,
      busy: _refreshing || _submitting || _busyComments.contains(root.id),
      onLike: () => _toggleCommentLike(root),
      onAction: (action) => _commentAction(root, action),
    ),
    if (root.replyCount > 0 || _loadedReplies(root.id).isNotEmpty) ...[
      if (_expandedThreads.contains(root.id)) ...[
        for (final reply in _loadedReplies(root.id))
          _CommunityCommentTile(
            key: reply.id == widget.focusCommentId
                ? _notificationFocusKey
                : ValueKey(reply.id),
            comment: reply,
            ownerId: widget.repository.currentUserId,
            ownerIsCurrent: () => _detailOwnerIsCurrent,
            ownerChanges: widget.ownerChanges,
            membershipTier: _membershipTierByUser[reply.authorId],
            mine: reply.authorId == widget.repository.currentUserId,
            busy:
                _refreshing || _submitting || _busyComments.contains(reply.id),
            parent: root,
            onLike: () => _toggleCommentLike(reply),
            onAction: (action) => _commentAction(reply, action),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: 4,
            children: [
              if (_loadedReplies(root.id).length < root.replyCount)
                TextButton.icon(
                  key: Key('community-comment-load-replies-${root.id}'),
                  onPressed: _loadingReplyThreads.contains(root.id)
                      ? null
                      : () => _loadMoreReplies(root),
                  icon: _loadingReplyThreads.contains(root.id)
                      ? const SizedBox.square(
                          dimension: 14,
                          child: BilFeatureWelcomeStatus(),
                        )
                      : const BilNavigationFeedback(
                          child: Icon(Icons.expand_more_rounded),
                        ),
                  label: Text(
                    communityText(
                      context,
                      'Load more replies',
                      'تحميل مزيد من الردود',
                    ),
                  ),
                ),
              TextButton.icon(
                key: Key('community-comment-hide-replies-${root.id}'),
                onPressed: () =>
                    _setDetailState(() => _expandedThreads.remove(root.id)),
                icon: const BilNavigationFeedback(
                  child: Icon(Icons.expand_less_rounded),
                ),
                label: Text(
                  communityText(context, 'Hide replies', 'إخفاء الردود'),
                ),
              ),
            ],
          ),
        ),
      ] else
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: Key('community-comment-view-replies-${root.id}'),
            onPressed: () =>
                _setDetailState(() => _expandedThreads.add(root.id)),
            icon: const Icon(Icons.forum_outlined),
            label: Text(
              communityText(
                context,
                root.replyCount > 0 ? 'View {count} replies' : 'View replies',
                root.replyCount > 0 ? 'عرض {count} ردود' : 'عرض الردود',
              ).replaceAll('{count}', '${root.replyCount}'),
            ),
          ),
        ),
    ],
  ];
}
