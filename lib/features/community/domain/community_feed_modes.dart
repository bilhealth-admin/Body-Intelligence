import 'community_models.dart';

enum CommunityFeedMode {
  forYou('for_you'),
  following('following'),
  friends('friends'),
  explore('explore');

  const CommunityFeedMode(this.wireValue);
  final String wireValue;
}

class CommunityFeedReference {
  const CommunityFeedReference({
    required this.postId,
    required this.createdAt,
    required this.priority,
    required this.reasons,
  });

  final String postId;
  final DateTime createdAt;
  final int priority;
  final List<String> reasons;

  factory CommunityFeedReference.fromJson(Map<String, dynamic> json) {
    final postId = json['post_id'];
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final priority = json['priority'];
    final rawReasons = json['reasons'];
    const allowedReasons = {
      'friend',
      'followed_author',
      'followed_topic',
      'joined_circle',
    };
    if (postId is! String ||
        createdAt == null ||
        priority is! num ||
        priority % 1 != 0 ||
        priority < 0 ||
        priority > 110 ||
        rawReasons is! List ||
        rawReasons.any(
          (value) => value is! String || !allowedReasons.contains(value),
        )) {
      throw const FormatException('Invalid Community feed reference');
    }
    return CommunityFeedReference(
      postId: postId,
      createdAt: createdAt,
      priority: priority.toInt(),
      reasons: List<String>.unmodifiable(rawReasons.cast<String>()),
    );
  }
}

class CommunityFeedModeBatch {
  const CommunityFeedModeBatch({
    required this.posts,
    required this.hasMore,
    required this.references,
    this.nextPriority,
    this.nextBefore,
    this.nextBeforeId,
  });

  final List<CommunityPost> posts;
  final List<CommunityFeedReference> references;
  final bool hasMore;
  final int? nextPriority;
  final DateTime? nextBefore;
  final String? nextBeforeId;
}
