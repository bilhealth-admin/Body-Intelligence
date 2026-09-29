part of 'community_messages_page.dart';

/// Content-driven height: a timestamp and badge never compete for ListTile's
/// fixed trailing slot. The complete preview remains one accessible tap target.
class _CommunityConversationTile extends StatelessWidget {
  const _CommunityConversationTile({
    required this.title,
    required this.body,
    required this.unreadCount,
    required this.onTap,
    this.authorName,
    this.avatarUrl,
    this.createdAt,
    super.key,
  });

  final String title, body;
  final String? authorName, avatarUrl;
  final DateTime? createdAt;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = unreadCount > 0;
    final localDate = createdAt?.toLocal();
    final time = localDate == null
        ? null
        : DateUtils.isSameDay(localDate, DateTime.now())
        ? TimeOfDay.fromDateTime(localDate).format(context)
        : MaterialLocalizations.of(context).formatShortDate(localDate);
    return InkWell(
      onTap: onTap,
      child: Ink(
        color: unread
            ? theme.colorScheme.primaryContainer.withValues(alpha: .25)
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BilAccountAvatar(radius: 24, networkUrl: avatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _NaturalMessageText(
                              title,
                              maxLines: 1,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: 8),
                            Semantics(
                              label: '$unreadCount ${communityText(context, 'Unread messages', 'الرسائل غير المقروءة')}',
                              child: ExcludeSemantics(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (authorName != null) ...[
                        const SizedBox(height: 2),
                        _NaturalMessageText(authorName!, maxLines: 1,
                          style: theme.textTheme.bodySmall),
                      ],
                      const SizedBox(height: 4),
                      _NaturalMessageText(body, maxLines: 2,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                      if (time != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(time, style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
