part of 'community_hub_page.dart';

class _CommunityCommentTile extends StatelessWidget {
  const _CommunityCommentTile({
    required this.comment,
    required this.mine,
    required this.busy,
    required this.onLike,
    required this.onAction,
    super.key,
  });

  final CommunityComment comment;
  final bool mine;
  final bool busy;
  final VoidCallback onLike;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(
      start: comment.parentId == null ? 0 : 34,
      bottom: 10,
    ),
    child: Card(
      margin: EdgeInsets.zero,
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
                      value: 'reply',
                      child: Text(communityText(context, 'Reply', 'رد')),
                    ),
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
            SelectableText(
              comment.body,
              key: Key('community-comment-body-${comment.id}'),
              textDirection: BilWrittenLanguageResolver.directionFor(
                comment.body,
                fallback: Directionality.of(context),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${MaterialLocalizations.of(context).formatShortDate(comment.createdAt.toLocal())} · ${TimeOfDay.fromDateTime(comment.createdAt.toLocal()).format(context)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
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
