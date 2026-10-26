part of 'community_hub_page.dart';

class _CommunityCommentTile extends StatelessWidget {
  const _CommunityCommentTile({
    required this.comment,
    required this.mine,
    required this.busy,
    required this.onLike,
    required this.onAction,
    required this.ownerId,
    required this.ownerIsCurrent,
    this.ownerChanges,
    this.membershipTier,
    this.parent,
    super.key,
  });

  final String ownerId;
  final ValueGetter<bool> ownerIsCurrent;
  final Listenable? ownerChanges;
  final CommunityComment comment;
  final CommunityComment? parent;
  final String? membershipTier;
  final bool mine;
  final bool busy;
  final VoidCallback onLike;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(
      start: comment.parentId == null ? 0 : 24,
      bottom: 10,
    ),
    child: CommunityCommentCard(
      identity: comment.id,
      source: comment.body,
      builder: (expanded, toggle) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BilAccountAvatar(radius: 16, networkUrl: comment.authorAvatarUrl),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName ??
                          communityText(context, 'BIL member', 'عضو BIL'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (comment.authorHandle != null)
                      Text(
                        '@${comment.authorHandle}',
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (membershipTier case final tier?) ...[
                      const SizedBox(height: 3),
                      Chip(
                        key: Key(
                          'community-comment-membership-tier-${comment.id}',
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        labelPadding: EdgeInsets.zero,
                        avatar: Icon(
                          tier == 'premium'
                              ? Icons.workspace_premium_outlined
                              : Icons.person_outline_rounded,
                          size: 15,
                        ),
                        label: Text(
                          tier == 'premium'
                              ? communityText(context, 'Premium', 'Premium')
                              : communityText(context, 'Free', 'مجاني'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              bilPearlPopupMenuButton<String>(
                key: Key('community-comment-actions-${comment.id}'),
                enabled: !busy,
                onSelected: onAction,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'copy',
                    child: Text(communityText(context, 'Copy', 'نسخ')),
                  ),
                  if (mine)
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
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (parent != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                parent!.body,
                key: Key('community-comment-parent-${comment.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: BilWrittenLanguageResolver.directionFor(
                  parent!.body,
                  fallback: Directionality.of(context),
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          CommunityTranslationContent(
            contentId: 'comment-${comment.id}',
            ownerId: ownerId,
            ownerIsCurrent: ownerIsCurrent,
            ownerChanges: ownerChanges,
            texts: {'body': comment.body},
            builder: (texts) => CommunityCommentText(
              identity: comment.id,
              text: texts['body']!,
              expanded: expanded,
              onToggle: toggle,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${MaterialLocalizations.of(context).formatShortDate(comment.createdAt.toLocal())} · ${TimeOfDay.fromDateTime(comment.createdAt.toLocal()).format(context)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton.icon(
                key: Key('community-comment-reply-${comment.id}'),
                onPressed: busy ? null : () => onAction('reply'),
                icon: const BilNavigationFeedback(
                  child: Icon(Icons.reply_rounded, size: 18),
                ),
                label: Text(communityText(context, 'Reply', 'رد')),
              ),
              TextButton.icon(
                key: Key('community-comment-like-${comment.id}'),
                onPressed: busy ? null : onLike,
                icon: Icon(
                  comment.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                ),
                label: Text('${comment.likeCount}'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
