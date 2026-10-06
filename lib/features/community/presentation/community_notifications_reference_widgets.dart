part of 'community_notifications_page.dart';

const _referenceActivityFilters = <_ActivityFilter>[
  _ActivityFilter.all,
  _ActivityFilter.updates,
  _ActivityFilter.reactions,
  _ActivityFilter.comments,
];

extension _CommunityNotificationsReferenceWidgets
    on _CommunityNotificationsPageState {
  Widget _referenceActivityRow(
    BuildContext context,
    CommunityNotification notification,
    Key marker,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final palette = _activityPalette(notification.kind);
    final actorAvatar = notification.actorAvatarUrl;
    final actorDriven = switch (notification.kind) {
      CommunityNotificationKind.postLike ||
      CommunityNotificationKind.comment ||
      CommunityNotificationKind.reply ||
      CommunityNotificationKind.mention ||
      CommunityNotificationKind.follow => true,
      _ => false,
    };
    final leading = actorDriven && actorAvatar != null
        ? BilAccountAvatar(radius: 20, networkUrl: actorAvatar)
        : Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.$1,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(palette.$2, size: 21, color: palette.$3),
          );

    return DecoratedBox(
      key: marker,
      decoration: BoxDecoration(
        color: notification.seen
            ? Colors.transparent
            : scheme.primaryContainer.withValues(alpha: .12),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .55),
            width: .7,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(4, 7, 0, 7),
        minVerticalPadding: 6,
        leading: leading,
        title: Text(
          _notificationTitle(notification),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: notification.seen ? FontWeight.w600 : FontWeight.w800,
          ),
        ),
        subtitle: notification.kind == CommunityNotificationKind.rewardEarned
            ? Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _CommunityRewardNoticePill(
                  label: communityText(
                    context,
                    'Reward added to your AI balance',
                    'أُضيفت المكافأة إلى رصيد الذكاء الاصطناعي',
                  ),
                ),
              )
            : null,
        trailing: notification.kind ==
                CommunityNotificationKind.collaborationInvite
            ? _notificationTrailing(notification)
            : Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Text(
                  _activityTimeLabel(notification.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight:
                        notification.seen ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ),
        onTap: notification.kind == CommunityNotificationKind.collaborationInvite
            ? null
            : () => _openNotification(notification),
      ),
    );
  }

  (Color, IconData, Color) _activityPalette(
    CommunityNotificationKind kind,
  ) => switch (kind) {
    CommunityNotificationKind.friendRequest ||
    CommunityNotificationKind.follow => (
      const Color(0xFFE6F0FF),
      Icons.person_rounded,
      const Color(0xFF1769E8),
    ),
    CommunityNotificationKind.friendAccepted => (
      const Color(0xFFE1F8EA),
      Icons.check_rounded,
      const Color(0xFF18A765),
    ),
    CommunityNotificationKind.postLike ||
    CommunityNotificationKind.postSave => (
      const Color(0xFFFFE8EC),
      Icons.favorite_rounded,
      const Color(0xFFF04461),
    ),
    CommunityNotificationKind.comment ||
    CommunityNotificationKind.reply ||
    CommunityNotificationKind.mention => (
      const Color(0xFFE8F0FF),
      Icons.chat_bubble_rounded,
      const Color(0xFF1769E8),
    ),
    CommunityNotificationKind.rewardEarned ||
    CommunityNotificationKind.questCompleted ||
    CommunityNotificationKind.badgeEarned => (
      const Color(0xFFFFF3D6),
      Icons.emoji_events_rounded,
      const Color(0xFFE29A00),
    ),
    CommunityNotificationKind.challengeUpdate => (
      const Color(0xFFF1E9FF),
      Icons.bolt_rounded,
      const Color(0xFF7C3AED),
    ),
    CommunityNotificationKind.collaborationInvite ||
    CommunityNotificationKind.collaborationAccepted => (
      const Color(0xFFE8F0FF),
      Icons.groups_rounded,
      const Color(0xFF1769E8),
    ),
  };

  String _activityTimeLabel(DateTime createdAt) {
    final now = DateTime.now().toUtc();
    final value = createdAt.toUtc();
    final delta = now.isBefore(value) ? Duration.zero : now.difference(value);
    if (delta.inMinutes < 1) return communityText(context, 'Now', 'الآن');
    if (delta.inHours < 1) return '${delta.inMinutes}m';
    if (delta.inDays < 1) return '${delta.inHours}h';
    if (delta.inDays < 7) return '${delta.inDays}d';
    return '${value.month}/${value.day}';
  }

  Widget _activitySectionLabel(
    BuildContext context,
    String english,
    String arabic, {
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(4, 13, 0, 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            communityText(context, english, arabic),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        trailing?,
      ],
    ),
  );
}

class _CommunityRewardNoticePill extends StatelessWidget {
  const _CommunityRewardNoticePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(9, 6, 10, 6),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF6DA),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFFFE19A)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.emoji_events_rounded,
          size: 16,
          color: Color(0xFFE29A00),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF8A5C00),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}
