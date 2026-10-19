part of 'community_models.dart';

/// Public identity read under the current viewer's RLS; never keyed by photo.
class CommunityPostAuthorIdentity {
  const CommunityPostAuthorIdentity({
    required this.userId,
    this.displayName,
    this.avatarUrl,
    this.social,
  });
  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final CommunityPostAuthorSocial? social;

  CommunityPost applyTo(CommunityPost post) {
    if (post.authorId != userId ||
        (social != null && social!.userId != userId)) {
      throw const FormatException('Community author identity did not match');
    }
    return CommunityPost(
      id: post.id,
      authorId: post.authorId,
      body: post.body,
      createdAt: post.createdAt,
      authorName: displayName,
      authorAvatarUrl: avatarUrl,
      mediaObjectPath: post.mediaObjectPath,
      mediaUrl: post.mediaUrl,
      mediaMimeType: post.mediaMimeType,
      mediaBytes: post.mediaBytes,
      mediaWidth: post.mediaWidth,
      mediaHeight: post.mediaHeight,
      moderationStatus: post.moderationStatus,
      moderationVisibility: post.moderationVisibility,
      reviewedAt: post.reviewedAt,
      likeCount: post.likeCount,
      liked: post.liked,
      commentCount: post.commentCount,
      saved: post.saved,
      authorHandle: social?.handle,
      authorRelationship:
          social?.relationship ?? CommunityRelationshipStatus.none,
      authorCanRequest: social?.canRequest ?? false,
      poll: post.poll,
      media: post.media,
      locationLabel: post.locationLabel,
    );
  }
}
