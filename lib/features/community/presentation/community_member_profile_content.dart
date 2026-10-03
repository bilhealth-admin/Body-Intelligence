part of 'community_hub_page.dart';

extension _CommunityMemberProfileContentSlivers
    on _CommunityMemberProfilePageState {
  List<Widget> _profileContentSlivers(CommunityProfileOverview profile) {
    final tabs = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: _contentTab == _CommunityProfileContentTab.moments
                  ? FilledButton.tonal(
                      key: const Key('community-profile-tab-moments'),
                      onPressed: null,
                      child: Text(communityText(context, 'Moments', 'اللحظات')),
                    )
                  : TextButton(
                      key: const Key('community-profile-tab-moments'),
                      onPressed: () => setState(
                        () => _contentTab = _CommunityProfileContentTab.moments,
                      ),
                      child: Text(communityText(context, 'Moments', 'اللحظات')),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _contentTab == _CommunityProfileContentTab.reviews
                  ? FilledButton.tonal(
                      key: const Key('community-profile-tab-reviews'),
                      onPressed: null,
                      child: Text(
                        communityText(context, 'Reviews', 'المراجعات'),
                      ),
                    )
                  : TextButton(
                      key: const Key('community-profile-tab-reviews'),
                      onPressed: () => setState(
                        () => _contentTab = _CommunityProfileContentTab.reviews,
                      ),
                      child: Text(
                        communityText(context, 'Reviews', 'المراجعات'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

    if (_contentTab == _CommunityProfileContentTab.reviews) {
      return <Widget>[
        tabs,
        if (_reviews.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(Icons.rate_review_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    profile.showPosts
                        ? communityText(
                            context,
                            'No approved reviews yet.',
                            'لا توجد مراجعات معتمدة بعد.',
                          )
                        : communityText(
                            context,
                            'Reviews are private on this profile.',
                            'المراجعات خاصة في هذا الملف.',
                          ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: _reviews.length,
              itemBuilder: (context, index) =>
                  _CommunityProfileReviewTile(review: _reviews[index]),
            ),
          ),
        if (_reviewHasMore)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton.icon(
                  onPressed: _loadingMoreReviews ? null : _loadMoreReviews,
                  icon: _loadingMoreReviews
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(
                    communityText(context, 'Load more', 'تحميل المزيد'),
                  ),
                ),
              ),
            ),
          ),
      ];
    }

    return <Widget>[
      tabs,
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Text(
                communityText(context, 'Moments', 'اللحظات'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Icon(
                _gridMode
                    ? Icons.grid_view_rounded
                    : Icons.view_agenda_outlined,
                size: 18,
              ),
            ],
          ),
        ),
      ),
      if (_posts.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                const Icon(Icons.article_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  profile.showPosts
                      ? communityText(
                          context,
                          'No visible moments yet.',
                          'لا توجد لحظات ظاهرة بعد.',
                        )
                      : communityText(
                          context,
                          'Moments are private on this profile.',
                          'اللحظات خاصة في هذا الملف.',
                        ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        )
      else if (_gridMode)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: .82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _CommunityProfilePostTile(
                post: _posts[index],
                repository: _repository!,
                referenceMetadata: _referenceByPost[_posts[index].id],
                viewCount: _viewCounts[_posts[index].id] ?? 0,
              ),
              childCount: _posts.length,
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: _posts.length,
            itemBuilder: (context, index) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CommunityPostCard(
                  post: _posts[index],
                  repository: _repository!,
                  currentUserId: _repository!.currentUserId,
                  referenceMetadata: _referenceByPost[_posts[index].id],
                  actionsEnabled: !_managingPost,
                  showModerationStatus: profile.isSelf,
                  onAction: (action) => _managePost(_posts[index], action),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 12,
                    end: 12,
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_outlined, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        (_viewCounts[_posts[index].id] ?? 0).toString(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      if (_hasMore)
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                onPressed: _loadingMore ? null : _loadMore,
                icon: _loadingMore
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  communityText(context, 'Load more', 'تحميل المزيد'),
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

class _CommunityProfilePostTile extends StatelessWidget {
  const _CommunityProfilePostTile({
    required this.post,
    required this.repository,
    required this.referenceMetadata,
    required this.viewCount,
  });

  final CommunityPost post;
  final CommunityRepository repository;
  final CommunityPostReferenceMetadata? referenceMetadata;
  final int viewCount;

  Future<void> _open(BuildContext context) => pushCommunityPage<void>(
    context,
    _CommunityPostDetailPage(
      post: post,
      initialStats: CommunityPostStats(
        postId: post.id,
        likeCount: post.likeCount,
        liked: post.liked,
        commentCount: post.commentCount,
      ),
      repository: repository,
      referenceMetadata: referenceMetadata,
    ),
  );

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: post.moderationStatus == CommunityPostModerationStatus.approved
        ? () => _open(context)
        : null,
    child: Ink(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: post.mediaUrl == null
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        referenceMetadata?.title?.trim().isNotEmpty == true
                            ? referenceMetadata!.title!
                            : post.body,
                        maxLines: 7,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : Image.network(
                      post.mediaUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          post.body,
                          maxLines: 7,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  const Icon(Icons.favorite_border_rounded, size: 16),
                  const SizedBox(width: 3),
                  Text('${post.likeCount}'),
                  const SizedBox(width: 10),
                  const Icon(Icons.mode_comment_outlined, size: 16),
                  const SizedBox(width: 3),
                  Text('${post.commentCount}'),
                  const SizedBox(width: 10),
                  const Icon(Icons.visibility_outlined, size: 16),
                  const SizedBox(width: 3),
                  Text(viewCount.toString()),
                  if (post.moderationStatus !=
                      CommunityPostModerationStatus.approved) ...[
                    const Spacer(),
                    Icon(
                      post.moderationStatus ==
                              CommunityPostModerationStatus.pending
                          ? Icons.schedule_rounded
                          : Icons.block_rounded,
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CommunityProfileConnectionsSheet extends StatefulWidget {
  const _CommunityProfileConnectionsSheet({
    required this.repository,
    required this.profile,
    required this.kind,
  });

  final CommunityRepository repository;
  final CommunityProfileOverview profile;
  final CommunityProfileConnectionKind kind;

  @override
  State<_CommunityProfileConnectionsSheet> createState() =>
      _CommunityProfileConnectionsSheetState();
}

class _CommunityProfileConnectionsSheetState
    extends State<_CommunityProfileConnectionsSheet> {
  late CommunityProfileConnectionKind _activeKind = widget.kind;
  late Future<List<CommunityProfileConnection>> _connections =
      _loadConnections(_activeKind);
  String? _followBusyUserId;

  Future<List<CommunityProfileConnection>> _loadConnections(
    CommunityProfileConnectionKind kind,
  ) => widget.repository.loadProfileConnections(
    userId: widget.profile.userId,
    kind: kind,
  );

  void _switchKind(CommunityProfileConnectionKind kind) {
    if (kind == _activeKind) return;
    setState(() {
      _activeKind = kind;
      _connections = _loadConnections(kind);
    });
  }

  Future<void> _toggleFollow(CommunityProfileConnection member) async {
    if (_followBusyUserId != null ||
        member.relationship == CommunityRelationshipStatus.self ||
        (!member.viewerFollows && !member.allowFollows)) {
      return;
    }
    setState(() => _followBusyUserId = member.userId);
    try {
      if (member.viewerFollows) {
        await widget.repository.unfollow(member.userId);
      } else {
        await widget.repository.follow(member.userId);
      }
      if (!mounted) return;
      setState(() => _connections = _loadConnections(_activeKind));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Could not update follow state.',
                'تعذر تحديث حالة المتابعة.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _followBusyUserId = null);
    }
  }

  Widget _buildList(BuildContext context) =>
      FutureBuilder<List<CommunityProfileConnection>>(
        future: _connections,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                communityText(
                  context,
                  'This list is unavailable right now.',
                  'هذه القائمة غير متاحة الآن.',
                ),
              ),
            );
          }
          final rows =
              snapshot.data ?? const <CommunityProfileConnection>[];
          if (rows.isEmpty) {
            return Center(
              child: Text(
                communityText(
                  context,
                  'Nothing to show here yet.',
                  'لا يوجد ما يمكن عرضه هنا بعد.',
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = rows[index];
              return ListTile(
                leading: BilAccountAvatar(
                  radius: 22,
                  networkUrl: member.avatarUrl,
                ),
                title: Text(member.displayName),
                subtitle: member.handle == null
                    ? null
                    : Text(
                        '@' + member.handle!,
                        textDirection: TextDirection.ltr,
                      ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (member.relationship !=
                            CommunityRelationshipStatus.self &&
                        (member.viewerFollows || member.allowFollows))
                      TextButton(
                        key: Key(
                          'community-connection-follow-' + member.userId,
                        ),
                        onPressed: _followBusyUserId == null
                            ? () => _toggleFollow(member)
                            : null,
                        child: _followBusyUserId == member.userId
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                member.viewerFollows
                                    ? communityText(
                                        context,
                                        'Following',
                                        'يتابع',
                                      )
                                    : communityText(
                                        context,
                                        'Follow',
                                        'متابعة',
                                      ),
                              ),
                      ),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/community/profile/' + member.userId);
                },
              );
            },
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final socialTabs =
        widget.kind != CommunityProfileConnectionKind.friends;
    final initialIndex =
        widget.kind == CommunityProfileConnectionKind.following ? 1 : 0;

    final content = SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        children: [
          if (socialTabs)
            TabBar(
              key: const Key('community-profile-follow-tabs'),
              onTap: (index) => _switchKind(
                index == 0
                    ? CommunityProfileConnectionKind.followers
                    : CommunityProfileConnectionKind.following,
              ),
              tabs: [
                Tab(
                  text: communityText(context, 'Followers', 'المتابعون'),
                ),
                Tab(
                  text: communityText(context, 'Following', 'يتابع'),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                communityText(context, 'Friends', 'الأصدقاء'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          const SizedBox(height: 8),
          Expanded(child: _buildList(context)),
        ],
      ),
    );

    if (!socialTabs) return content;
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: content,
    );
  }
}

