part of 'community_hub_page.dart';

class _CommunityCommentTile extends StatelessWidget {
  const _CommunityCommentTile({
    required this.comment,
    required this.mine,
    required this.busy,
    required this.onLike,
    required this.onAction,
    this.parent,
    super.key,
  });

  final CommunityComment comment;
  final CommunityComment? parent;
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
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: comment.parentId == null
            ? null
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BilAccountAvatar(
                  radius: 16,
                  networkUrl: comment.authorAvatarUrl,
                ),
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
                    ],
                  ),
                ),
                PopupMenuButton<String>(
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
            SelectableText(
              comment.body,
              key: Key('community-comment-body-${comment.id}'),
              textDirection: BilWrittenLanguageResolver.directionFor(
                comment.body,
                fallback: Directionality.of(context),
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
                  icon: const Icon(Icons.reply_rounded, size: 18),
                  label: Text(communityText(context, 'Reply', 'رد')),
                ),
                TextButton.icon(
                  key: Key('community-comment-like-${comment.id}'),
                  onPressed: busy ? null : onLike,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
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
    ),
  );
}
