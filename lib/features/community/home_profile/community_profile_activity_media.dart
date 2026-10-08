part of '../presentation/community_hub_page.dart';

extension _CommunityMemberProfileActivityMedia
    on _CommunityMemberProfilePageState {
  List<Widget> _profileMediaSlivers(
    _CommunityProfileVisit visit,
    CommunityProfileOverview profile,
  ) {
    final postsVisible = profile.isSelf || profile.showPosts;
    final entries = <_CommunityProfileMediaEntry>[
      if (postsVisible)
        for (final post in _posts)
          for (final media in post.mediaItems)
            _CommunityProfileMediaEntry(post: post, media: media),
    ];
    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text(
            communityText(context, 'Media', 'الوسائط'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      if (entries.isEmpty)
        _profileActivityMessage(
          key: const Key('community-profile-media-empty'),
          icon: Icons.photo_library_outlined,
          text: postsVisible
              ? communityText(
                  context,
                  'No visible media yet.',
                  'لا توجد وسائط ظاهرة بعد.',
                )
              : communityText(
                  context,
                  'Media is private on this profile.',
                  'الوسائط خاصة في هذا الملف.',
                ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _CommunityProfileMediaTile(
                visit: visit,
                entry: entries[index],
                referenceMetadata: _referenceByPost[entries[index].post.id],
              ),
              childCount: entries.length,
            ),
          ),
        ),
      if (postsVisible && _hasMore)
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                key: const Key('community-profile-media-load-more'),
                onPressed: _loadingMore ? null : _loadMore,
                icon: _loadingMore
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  communityText(context, 'Load more media', 'تحميل وسائط أكثر'),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _profileReplySlivers(
    _CommunityProfileVisit visit,
    CommunityProfileOverview profile,
  ) {
    final state = _profileActivity;
    if (!_profileRepliesVisible(profile)) {
      return <Widget>[
        _profileActivityMessage(
          key: const Key('community-profile-replies-private'),
          icon: Icons.lock_outline_rounded,
          text: communityText(
            context,
            'Replies are private on this profile.',
            'الردود خاصة في هذا الملف.',
          ),
        ),
      ];
    }
    if (!state.replyLoaded && !state.replyLoading) {
      scheduleMicrotask(() {
        if (mounted &&
            _profileActivity.tab == _CommunityProfilePrimaryTab.replies) {
          unawaited(_loadProfileReplies(reset: true));
        }
      });
    }
    if (state.replyLoading && state.replies.isEmpty) {
      return const <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    if (state.replyError != null && state.replies.isEmpty) {
      return <Widget>[
        _profileActivityRetry(
          key: const Key('community-profile-replies-retry'),
          onRetry: () => _loadProfileReplies(reset: true),
        ),
      ];
    }
    return <Widget>[
      if (state.replies.isEmpty)
        _profileActivityMessage(
          key: const Key('community-profile-replies-empty'),
          icon: Icons.reply_all_outlined,
          text: communityText(
            context,
            'No visible replies yet.',
            'لا توجد ردود ظاهرة بعد.',
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: state.replies.length,
            itemBuilder: (context, index) => _CommunityProfileReplyTile(
              visit: visit,
              item: state.replies[index],
              referenceMetadata: _referenceByPost[state.replies[index].post.id],
            ),
          ),
        ),
      if (state.replyError != null && state.replies.isNotEmpty)
        _profileActivityRetry(
          key: const Key('community-profile-replies-page-retry'),
          onRetry: () => _loadProfileReplies(reset: false),
        )
      else if (state.replyHasMore)
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                key: const Key('community-profile-replies-load-more'),
                onPressed: state.replyLoading
                    ? null
                    : () => _loadProfileReplies(reset: false),
                icon: state.replyLoading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  communityText(
                    context,
                    'Load more replies',
                    'تحميل ردود أكثر',
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _profileLikeSlivers(
    _CommunityProfileVisit visit,
    CommunityProfileOverview profile,
  ) {
    final state = _profileActivity;
    if (!profile.isSelf) {
      return <Widget>[
        _profileActivityMessage(
          key: const Key('community-profile-likes-private'),
          icon: Icons.lock_outline_rounded,
          text: communityText(
            context,
            'Likes are private. Only this member can view them.',
            'الإعجابات خاصة. لا يمكن عرضها إلا لصاحب الحساب.',
          ),
        ),
      ];
    }
    if (!state.likeLoaded && !state.likeLoading) {
      scheduleMicrotask(() {
        if (mounted &&
            _profileActivity.tab == _CommunityProfilePrimaryTab.likes) {
          unawaited(_loadProfileLikes(reset: true));
        }
      });
    }
    if (state.likeLoading && state.likes.isEmpty) {
      return const <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    if (state.likeError != null && state.likes.isEmpty) {
      return <Widget>[
        _profileActivityRetry(
          key: const Key('community-profile-likes-retry'),
          onRetry: () => _loadProfileLikes(reset: true),
        ),
      ];
    }
    return <Widget>[
      if (state.likes.isEmpty)
        _profileActivityMessage(
          key: const Key('community-profile-likes-empty'),
          icon: Icons.thumb_up_alt_outlined,
          text: communityText(
            context,
            'No visible liked posts yet.',
            'لا توجد منشورات معجب بها ظاهرة بعد.',
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: state.likes.length,
            itemBuilder: (context, index) {
              final item = state.likes[index];
              final post = item.post;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CommunityPostCard(
                    post: post,
                    repository: visit.repository,
                    ownerIsCurrent: visit.isCurrent,
                    ownerChanges: visit.changes,
                    currentUserId: visit.ownerId,
                    referenceMetadata: _referenceByPost[post.id],
                    actionsEnabled: !_managingPost,
                    onAction: (action) => _managePost(post, action),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 8),
                    child: Text(
                      communityText(context, 'Liked post', 'منشور معجب به'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      if (state.likeError != null && state.likes.isNotEmpty)
        _profileActivityRetry(
          key: const Key('community-profile-likes-page-retry'),
          onRetry: () => _loadProfileLikes(reset: false),
        )
      else if (state.likeHasMore)
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                key: const Key('community-profile-likes-load-more'),
                onPressed: state.likeLoading
                    ? null
                    : () => _loadProfileLikes(reset: false),
                icon: state.likeLoading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  communityText(
                    context,
                    'Load more likes',
                    'تحميل إعجابات أكثر',
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _profilePostLoadMore() => SliverToBoxAdapter(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton.icon(
          key: const Key('community-profile-posts-load-more'),
          onPressed: _loadingMore ? null : _loadMore,
          icon: _loadingMore
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more_rounded),
          label: Text(communityText(context, 'Load more', 'تحميل المزيد')),
        ),
      ),
    ),
  );

  Widget _profileActivityMessage({
    required Key key,
    required IconData icon,
    required String text,
  }) => SliverToBoxAdapter(
    child: Padding(
      key: key,
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _profileActivityRetry({
    required Key key,
    required VoidCallback onRetry,
  }) => SliverToBoxAdapter(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: FilledButton.icon(
          key: key,
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
        ),
      ),
    ),
  );
}

class _CommunityProfileMediaTile extends StatelessWidget {
  const _CommunityProfileMediaTile({
    required this.visit,
    required this.entry,
    required this.referenceMetadata,
  });

  final _CommunityProfileVisit visit;
  final _CommunityProfileMediaEntry entry;
  final CommunityPostReferenceMetadata? referenceMetadata;

  Future<void> _open(BuildContext context) async {
    if (!visit.isCurrent() ||
        entry.post.moderationStatus != CommunityPostModerationStatus.approved) {
      return;
    }
    await pushCommunityPage<void>(
      context,
      _CommunityPostDetailPage(
        post: entry.post,
        initialStats: CommunityPostStats(
          postId: entry.post.id,
          likeCount: entry.post.likeCount,
          liked: entry.post.liked,
          commentCount: entry.post.commentCount,
        ),
        repository: visit.repository,
        ownerIsCurrent: visit.isCurrent,
        ownerChanges: visit.changes,
        referenceMetadata: referenceMetadata,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = entry.media.url;
    return InkWell(
      key: Key(
        'community-profile-media-${entry.post.id}-${entry.media.position}',
      ),
      onTap:
          entry.post.moderationStatus == CommunityPostModerationStatus.approved
          ? () => _open(context)
          : null,
      child: url == null
          ? _missingMedia(context)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _missingMedia(context),
            ),
    );
  }

  Widget _missingMedia(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    ),
    child: Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _CommunityProfileReplyTile extends StatelessWidget {
  const _CommunityProfileReplyTile({
    required this.visit,
    required this.item,
    required this.referenceMetadata,
  });

  final _CommunityProfileVisit visit;
  final CommunityProfileReplyItem item;
  final CommunityPostReferenceMetadata? referenceMetadata;

  Future<void> _open(BuildContext context) async {
    if (!visit.isCurrent() ||
        item.post.moderationStatus != CommunityPostModerationStatus.approved) {
      return;
    }
    await pushCommunityPage<void>(
      context,
      _CommunityPostDetailPage(
        post: item.post,
        initialStats: CommunityPostStats(
          postId: item.post.id,
          likeCount: item.post.likeCount,
          liked: item.post.liked,
          commentCount: item.post.commentCount,
        ),
        repository: visit.repository,
        ownerIsCurrent: visit.isCurrent,
        ownerChanges: visit.changes,
        referenceMetadata: referenceMetadata,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      key: Key('community-profile-reply-${item.comment.id}'),
      onTap:
          item.post.moderationStatus == CommunityPostModerationStatus.approved
          ? () => _open(context)
          : null,
      leading: BilAccountAvatar(
        radius: 20,
        networkUrl: item.comment.authorAvatarUrl,
      ),
      title: Text(
        item.comment.body,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          item.post.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: item.comment.likeCount == 0
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.thumb_up_outlined, size: 16),
                const SizedBox(width: 3),
                Text('${item.comment.likeCount}'),
              ],
            ),
    ),
  );
}
