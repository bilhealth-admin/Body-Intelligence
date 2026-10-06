part of 'community_hub_page.dart';

extension _CommunityPostDetailRendering on _CommunityPostDetailPageState {
  Widget buildCommunityPostDetail(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(communityText(context, 'Post', 'منشور'))),
    body: FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            _comments.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && _comments.isEmpty) {
          return Center(
            child: FilledButton.icon(
              key: const Key('community-post-detail-retry'),
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  key: const Key('community-post-detail-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
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
                    ),
                    if (widget.post.poll case final poll?) ...[
                      const SizedBox(height: 16),
                      _CommunityPollPanel(
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
                      for (final root in _rootComments) ...[
                        _CommunityCommentTile(
                          key: ValueKey(root.id),
                          comment: root,
                          membershipTier: _membershipTierByUser[root.authorId],
                          mine:
                              root.authorId == widget.repository.currentUserId,
                          busy:
                              _refreshing ||
                              _submitting ||
                              _busyComments.contains(root.id),
                          onLike: () => _toggleCommentLike(root),
                          onAction: (action) => _commentAction(root, action),
                        ),
                        if (root.replyCount > 0) ...[
                          if (_expandedThreads.contains(root.id)) ...[
                            for (final reply in _loadedReplies(root.id))
                              _CommunityCommentTile(
                                key: ValueKey(reply.id),
                                comment: reply,
                                membershipTier:
                                    _membershipTierByUser[reply.authorId],
                                mine:
                                    reply.authorId ==
                                    widget.repository.currentUserId,
                                busy:
                                    _refreshing ||
                                    _submitting ||
                                    _busyComments.contains(reply.id),
                                parent: root,
                                onLike: () => _toggleCommentLike(reply),
                                onAction: (action) =>
                                    _commentAction(reply, action),
                              ),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Wrap(
                                spacing: 4,
                                children: [
                                  if (_loadedReplies(root.id).length <
                                      root.replyCount)
                                    TextButton.icon(
                                      key: Key(
                                        'community-comment-load-replies-${root.id}',
                                      ),
                                      onPressed:
                                          _loadingReplyThreads.contains(root.id)
                                          ? null
                                          : () => _loadMoreReplies(root),
                                      icon:
                                          _loadingReplyThreads.contains(root.id)
                                          ? const SizedBox.square(
                                              dimension: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.expand_more_rounded,
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
                                    key: Key(
                                      'community-comment-hide-replies-${root.id}',
                                    ),
                                    onPressed: () => _setDetailState(
                                      () => _expandedThreads.remove(root.id),
                                    ),
                                    icon: const Icon(Icons.expand_less_rounded),
                                    label: Text(
                                      communityText(
                                        context,
                                        'Hide replies',
                                        'إخفاء الردود',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                key: Key(
                                  'community-comment-view-replies-${root.id}',
                                ),
                                onPressed: () => _setDetailState(
                                  () => _expandedThreads.add(root.id),
                                ),
                                icon: const Icon(Icons.forum_outlined),
                                label: Text(
                                  communityText(
                                    context,
                                    'View {count} replies',
                                    'عرض {count} ردود',
                                  ).replaceAll('{count}', '${root.replyCount}'),
                                ),
                              ),
                            ),
                        ],
                      ],
                    if (_hasMore)
                      Center(
                        child: TextButton.icon(
                          key: const Key('community-comments-load-more'),
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
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
}
