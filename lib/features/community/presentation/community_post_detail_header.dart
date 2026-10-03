part of 'community_hub_page.dart';

class _CommunityPostDetailHeader extends StatelessWidget {
  const _CommunityPostDetailHeader({
    required this.post,
    required this.stats,
    required this.referenceMetadata,
    required this.authorProfile,
    required this.followBusy,
    required this.viewCount,
    required this.liking,
    required this.onLike,
    required this.onToggleFollow,
  });

  final CommunityPost post;
  final CommunityPostStats stats;
  final CommunityPostReferenceMetadata? referenceMetadata;
  final CommunityProfileOverview? authorProfile;
  final bool followBusy;
  final int? viewCount;
  final bool liking;
  final VoidCallback onLike;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BilAccountAvatar(radius: 21, networkUrl: post.authorAvatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName ??
                          communityText(context, 'BIL member', 'عضو BIL'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (post.authorHandle != null)
                      Text(
                        '@${post.authorHandle}',
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      '${MaterialLocalizations.of(context).formatShortDate(post.createdAt.toLocal())} · ${TimeOfDay.fromDateTime(post.createdAt.toLocal()).format(context)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (authorProfile case final profile?
                  when profile.viewerFollows || profile.allowFollows)
                TextButton(
                  key: const Key('community-post-detail-follow'),
                  onPressed: followBusy ? null : onToggleFollow,
                  child: followBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          profile.viewerFollows
                              ? communityText(context, 'Following', 'يتابع')
                              : communityText(context, 'Follow', 'متابعة'),
                        ),
                ),
            ],
          ),
          if (post.locationLabel case final location?) ...[
            const SizedBox(height: 8),
            Row(
              key: const Key('community-post-detail-location'),
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (referenceMetadata case final metadata?) ...[
            const SizedBox(height: 12),
            _CommunityPostReferenceBlock(
              metadata: metadata,
              repository: widget.repository,
            ),
          ],
          if (post.hasImage) ...[
            const SizedBox(height: 14),
            _CommunityFeedImage(post: post),
          ],
          const SizedBox(height: 14),
          SelectableText(
            post.body,
            textDirection: BilWrittenLanguageResolver.directionFor(
              post.body,
              fallback: Directionality.of(context),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                key: const Key('community-post-detail-like'),
                onPressed: liking ? null : onLike,
                icon: liking
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        stats.liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                label: Text('${stats.likeCount}'),
              ),
              const SizedBox(width: 8),
              Icon(Icons.mode_comment_outlined, size: 19),
              const SizedBox(width: 5),
              Text('${stats.commentCount}'),
              if (viewCount != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.visibility_outlined, size: 19),
                const SizedBox(width: 5),
                Text(viewCount.toString()),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}
