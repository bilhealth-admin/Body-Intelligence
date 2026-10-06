part of 'community_notifications_page.dart';

extension _CommunityNotificationsFilters on _CommunityNotificationsPageState {
  List<CommunityNotificationKind>? get filterKinds => switch (_filter) {
    _ActivityFilter.all => null,
    // Reference tab: approvals / system decisions. Likes, comments and mentions
    // remain visible under All and never disappear from the unread total.
    _ActivityFilter.updates => const [
      CommunityNotificationKind.friendAccepted,
      CommunityNotificationKind.rewardEarned,
      CommunityNotificationKind.questCompleted,
      CommunityNotificationKind.badgeEarned,
      CommunityNotificationKind.challengeUpdate,
      CommunityNotificationKind.collaborationAccepted,
    ],
    // The stored enum name is retained for migration safety; the user-visible
    // reference tab is Mentions.
    _ActivityFilter.reactions => const [
      CommunityNotificationKind.mention,
    ],
    _ActivityFilter.comments => const [
      CommunityNotificationKind.comment,
      CommunityNotificationKind.reply,
    ],
    _ActivityFilter.followers => const [CommunityNotificationKind.follow],
  };

  bool matchesFilter(CommunityNotification notification) => switch (_filter) {
    _ActivityFilter.all => true,
    _ActivityFilter.updates =>
      notification.kind == CommunityNotificationKind.friendAccepted ||
          notification.kind == CommunityNotificationKind.rewardEarned ||
          notification.kind == CommunityNotificationKind.questCompleted ||
          notification.kind == CommunityNotificationKind.badgeEarned ||
          notification.kind == CommunityNotificationKind.challengeUpdate ||
          notification.kind == CommunityNotificationKind.collaborationAccepted,
    _ActivityFilter.reactions =>
      notification.kind == CommunityNotificationKind.mention,
    _ActivityFilter.comments =>
      notification.kind == CommunityNotificationKind.comment ||
          notification.kind == CommunityNotificationKind.reply,
    _ActivityFilter.followers =>
      notification.kind == CommunityNotificationKind.follow,
  };

  String filterLabel(_ActivityFilter filter) => switch (filter) {
    _ActivityFilter.all => communityText(context, 'All', 'الكل'),
    _ActivityFilter.updates =>
      communityText(context, 'Approvals', 'الموافقات'),
    _ActivityFilter.reactions =>
      communityText(context, 'Mentions', 'الإشارات'),
    _ActivityFilter.comments =>
      communityText(context, 'Comments', 'التعليقات'),
    _ActivityFilter.followers =>
      communityText(context, 'Followers', 'المتابعون'),
  };
}
