import 'community_models.dart';

/// The revision describes the content actually reviewed, never a client hash.
class CommunityReviewSnapshot {
  const CommunityReviewSnapshot({
    required this.post,
    required this.revision,
    required this.canPublishOnly,
  });
  final CommunityPost post;
  final String revision;
  final bool canPublishOnly;

  CommunityReviewSnapshot withPost(CommunityPost hydrated) =>
      CommunityReviewSnapshot(
        post: hydrated,
        revision: revision,
        canPublishOnly: canPublishOnly,
      );

  static final revisionPattern = RegExp(r'^[0-9a-f]{64}$');
}

class CommunityRewardReview {
  const CommunityRewardReview({
    required this.snapshot,
    required this.requestId,
    required this.status,
    required this.canGrant,
  });
  final CommunityReviewSnapshot snapshot;
  final String? requestId;
  final String status;
  final bool canGrant;
}
