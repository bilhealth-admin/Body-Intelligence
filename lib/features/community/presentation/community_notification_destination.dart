import '../../notifications/domain/community_deep_link.dart';
import '../domain/community_attention.dart';

/// Notification metadata is a destination hint, never authorization or content.
abstract final class CommunityNotificationDestination {
  static String? contentRoute(CommunityNotification notification) {
    if (!const {
      CommunityNotificationKind.postLike,
      CommunityNotificationKind.postSave,
      CommunityNotificationKind.comment,
      CommunityNotificationKind.reply,
      CommunityNotificationKind.mention,
    }.contains(notification.kind)) {
      return null;
    }
    final post =
        notification.metadata['post_id'] ??
        (notification.entityKind == 'post' ? notification.entityId : null);
    final comment =
        notification.metadata['comment_id'] ??
        (notification.entityKind == 'comment' ? notification.entityId : null);
    if (post is! String || (comment != null && comment is! String)) return null;
    return CommunityDeepLink.contentRoute(
      postId: post,
      commentId: comment as String?,
    );
  }
}
