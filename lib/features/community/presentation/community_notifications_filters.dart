part of 'community_notifications_page.dart';

extension _CommunityNotificationsFilters on _CommunityNotificationsPageState {
  List<CommunityNotificationKind> get filterKinds => switch (_filter) {
    _ActivityFilter.updates => const [
      CommunityNotificationKind.friendRequest,
      CommunityNotificationKind.friendAccepted,
      CommunityNotificationKind.rewardEarned,
      CommunityNotificationKind.questCompleted,
      CommunityNotificationKind.badgeEarned,
      CommunityNotificationKind.challengeUpdate,
      CommunityNotificationKind.collaborationInvite,
      CommunityNotificationKind.collaborationAccepted,
    ],
    _ActivityFilter.reactions => const [
      CommunityNotificationKind.postLike,
      CommunityNotificationKind.postSave,
    ],
    _ActivityFilter.comments => const [
      CommunityNotificationKind.comment,
      CommunityNotificationKind.reply,
      CommunityNotificationKind.mention,
    ],
    _ActivityFilter.followers => const [CommunityNotificationKind.follow],
  };

  bool matchesFilter(CommunityNotification notification) => switch (_filter) {
    _ActivityFilter.updates =>
      notification.kind == CommunityNotificationKind.friendRequest ||
          notification.kind == CommunityNotificationKind.friendAccepted ||
          notification.kind == CommunityNotificationKind.rewardEarned ||
          notification.kind == CommunityNotificationKind.questCompleted ||
          notification.kind == CommunityNotificationKind.badgeEarned ||
          notification.kind == CommunityNotificationKind.challengeUpdate ||
          notification.kind == CommunityNotificationKind.collaborationInvite ||
          notification.kind == CommunityNotificationKind.collaborationAccepted,
    _ActivityFilter.reactions =>
      notification.kind == CommunityNotificationKind.postLike ||
          notification.kind == CommunityNotificationKind.postSave,
    _ActivityFilter.comments =>
      notification.kind == CommunityNotificationKind.comment ||
          notification.kind == CommunityNotificationKind.reply ||
          notification.kind == CommunityNotificationKind.mention,
    _ActivityFilter.followers =>
      notification.kind == CommunityNotificationKind.follow,
  };

  String filterLabel(_ActivityFilter filter) => switch (filter) {
    _ActivityFilter.updates => communityText(context, 'Updates', 'التحديثات'),
    _ActivityFilter.reactions => communityText(
      context,
      'Likes & saves',
      'الإعجابات والحفظ',
    ),
    _ActivityFilter.comments => communityText(context, 'Comments', 'التعليقات'),
    _ActivityFilter.followers => communityText(
      context,
      'New followers',
      'متابعون جدد',
    ),
  };
}
