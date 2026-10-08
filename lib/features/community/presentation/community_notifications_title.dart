part of 'community_notifications_page.dart';

extension _CommunityNotificationTitle on _CommunityNotificationsPageState {
  String _notificationTitle(CommunityNotification notification) {
    final moderationReceipt = _postModerationReceipt(notification);
    if (moderationReceipt != null) {
      return switch (moderationReceipt.decision) {
        CommunityPostModerationReceiptDecision.approved
            when moderationReceipt.hasConfirmedAiGrant =>
          communityText(
            context,
            'Your post was approved · +5 AI tokens',
            'تم اعتماد منشورك · +5 توكنات AI',
          ),
        CommunityPostModerationReceiptDecision.approved => communityText(
          context,
          'Your post was approved',
          'تم اعتماد منشورك',
        ),
        CommunityPostModerationReceiptDecision.rejected => communityText(
          context,
          'Your post needs changes',
          'منشورك يحتاج تعديلات',
        ),
      };
    }
    final actor = notification.actorDisplayName;
    return switch (notification.kind) {
      CommunityNotificationKind.friendRequest =>
        actor == null
            ? communityText(context, 'New friend request', 'طلب صداقة جديد')
            : communityText(
                context,
                '{actor} sent you a friend request',
                '{actor} أرسل إليك طلب صداقة',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.friendAccepted =>
        actor == null
            ? communityText(
                context,
                'Your friend request was accepted',
                'تم قبول طلب صداقتك',
              )
            : communityText(
                context,
                '{actor} accepted your friend request',
                '{actor} قبل طلب صداقتك',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.postLike =>
        actor == null
            ? communityText(
                context,
                'Someone liked your post',
                'أعجب شخص بمنشورك',
              )
            : communityText(
                context,
                '{actor} liked your post',
                '{actor} أعجب بمنشورك',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.postSave => communityText(
        context,
        'Your post was saved',
        'تم حفظ منشورك',
      ),
      CommunityNotificationKind.comment =>
        actor == null
            ? communityText(
                context,
                'New comment on your post',
                'تعليق جديد على منشورك',
              )
            : communityText(
                context,
                '{actor} commented on your post',
                '{actor} علّق على منشورك',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.reply =>
        actor == null
            ? communityText(
                context,
                'New reply to your comment',
                'رد جديد على تعليقك',
              )
            : communityText(
                context,
                '{actor} replied to your comment',
                '{actor} رد على تعليقك',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.follow =>
        actor == null
            ? communityText(context, 'New follower', 'متابع جديد')
            : communityText(
                context,
                '{actor} followed you',
                '{actor} بدأ بمتابعتك',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.mention =>
        actor == null
            ? communityText(
                context,
                'You were mentioned in a post',
                'تمت الإشارة إليك في منشور',
              )
            : communityText(
                context,
                '{actor} mentioned you in a post',
                '{actor} أشار إليك في منشور',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.rewardEarned => communityText(
        context,
        'You earned a Community reward',
        'حصلت على مكافأة في المجتمع',
      ),
      CommunityNotificationKind.questCompleted => communityText(
        context,
        'Quest completed',
        'اكتملت المهمة',
      ),
      CommunityNotificationKind.badgeEarned => communityText(
        context,
        'New badge earned',
        'حصلت على شارة جديدة',
      ),
      CommunityNotificationKind.challengeUpdate => communityText(
        context,
        'Challenge update',
        'تحديث للتحدي',
      ),
      CommunityNotificationKind.collaborationInvite =>
        actor == null
            ? communityText(context, 'Collaboration invitation', 'دعوة للتعاون')
            : communityText(
                context,
                '{actor} invited you to collaborate on a post',
                '{actor} دعاك للتعاون على منشور',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.collaborationAccepted =>
        actor == null
            ? communityText(
                context,
                'Collaboration invitation accepted',
                'تم قبول دعوة التعاون',
              )
            : communityText(
                context,
                '{actor} accepted your collaboration invitation',
                '{actor} قبل دعوة التعاون الخاصة بك',
              ).replaceAll('{actor}', actor),
    };
  }
}
