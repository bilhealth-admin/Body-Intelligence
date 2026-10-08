part of 'community_hub_page.dart';

extension _CommunityMemberProfileContentSlivers
    on _CommunityMemberProfilePageState {
  List<Widget> _profileContentSlivers(CommunityProfileOverview profile) {
    final visit = _captureProfileVisit();
    if (visit == null) return const [];
    final postsVisible = profile.isSelf || profile.showPosts;
    final reviews = postsVisible ? _reviews : const <CommunityProfileReview>[];
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
                      onPressed: () => _setProfileState(
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
                      onPressed: () => _setProfileState(
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
        if (reviews.isEmpty)
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
              itemCount: reviews.length,
              itemBuilder: (context, index) =>
                  _CommunityProfileReviewTile(review: reviews[index]),
            ),
          ),
        if (postsVisible && _reviewHasMore)
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

    return <Widget>[tabs, ..._profilePostSlivers(visit, profile)];
  }
}

class _CommunityProfilePostTile extends StatelessWidget {
  const _CommunityProfilePostTile({
    this.visit,
    required this.post,
    required this.repository,
    required this.referenceMetadata,
    required this.viewCount,
  });

  final _CommunityProfileVisit? visit;
  final CommunityPost post;
  final CommunityRepository repository;
  final CommunityPostReferenceMetadata? referenceMetadata;
  final int? viewCount;

  Future<void> _open(BuildContext context) async {
    if (visit?.isCurrent() == false) return;
    await pushCommunityPage<void>(
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
        ownerIsCurrent: visit?.isCurrent,
        ownerChanges: visit?.changes,
        referenceMetadata: referenceMetadata,
      ),
    );
  }

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
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_border_rounded, size: 16),
                      const SizedBox(width: 3),
                      Text('${post.likeCount}'),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mode_comment_outlined, size: 16),
                      const SizedBox(width: 3),
                      Text('${post.commentCount}'),
                    ],
                  ),
                  if (viewCount != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_outlined, size: 16),
                        const SizedBox(width: 3),
                        Text(
                          viewCount.toString(),
                          key: Key('community-profile-post-views-${post.id}'),
                        ),
                      ],
                    ),
                  if (post.moderationStatus !=
                      CommunityPostModerationStatus.approved) ...[
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
