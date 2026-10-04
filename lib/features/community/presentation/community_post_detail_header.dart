part of 'community_hub_page.dart';

class _CommunityPostDetailHeader extends StatelessWidget {
  const _CommunityPostDetailHeader({
    required this.post,
    required this.stats,
    required this.referenceMetadata,
    required this.authorProfile,
    required this.authorMembershipTier,
    required this.followBusy,
    required this.viewCount,
    required this.liking,
    required this.saved,
    required this.saving,
    required this.sharing,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    required this.onToggleFollow,
    required this.repository,
  });

  final CommunityPost post;
  final CommunityPostStats stats;
  final CommunityPostReferenceMetadata? referenceMetadata;
  final CommunityProfileOverview? authorProfile;
  final String? authorMembershipTier;
  final bool followBusy;
  final int? viewCount;
  final bool liking;
  final bool saved;
  final bool saving;
  final bool sharing;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final Future<void> Function(BuildContext) onShare;
  final VoidCallback onToggleFollow;
  final CommunityRepository repository;

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
                    if (authorMembershipTier case final tier?) ...[
                      const SizedBox(height: 4),
                      _CommunityMembershipTierChip(
                        tier: tier,
                        compact: true,
                      ),
                    ],
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
              repository: repository,
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
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
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
                            ? Icons.thumb_up_rounded
                            : Icons.thumb_up_outlined,
                      ),
                label: Text('${stats.likeCount}'),
              ),
              Chip(
                avatar: const Icon(Icons.mode_comment_outlined, size: 18),
                label: Text('${stats.commentCount}'),
              ),
              if (viewCount != null)
                Chip(
                  avatar: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text(viewCount.toString()),
                ),
              IconButton(
                key: const Key('community-post-detail-save'),
                tooltip: saved
                    ? communityText(
                        context,
                        'Remove from saved',
                        'إزالة من المحفوظات',
                      )
                    : communityText(context, 'Save post', 'حفظ المنشور'),
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        saved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
              ),
              Builder(
                builder: (shareContext) => IconButton(
                  key: const Key('community-post-detail-share'),
                  tooltip: communityText(
                    context,
                    'Share post',
                    'مشاركة المنشور',
                  ),
                  onPressed: sharing ? null : () => onShare(shareContext),
                  icon: sharing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_outlined),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
