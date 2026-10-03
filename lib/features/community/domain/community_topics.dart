import 'community_models.dart';

class CommunityTopic {
  const CommunityTopic({
    required this.slug,
    required this.titleCopyKey,
    required this.descriptionCopyKey,
    required this.iconKey,
    required this.featured,
    required this.followerCount,
    required this.postCount,
    required this.following,
  });

  static final RegExp slugPattern = RegExp(
    r'^[a-z0-9]+(?:-[a-z0-9]+)*$',
  );
  static final RegExp copyKeyPattern = RegExp(
    r'^[a-z][a-z0-9_]{2,63}$',
  );

  final String slug;
  final String titleCopyKey;
  final String descriptionCopyKey;
  final String iconKey;
  final bool featured;
  final int followerCount;
  final int postCount;
  final bool following;

  CommunityTopic copyWith({
    int? followerCount,
    int? postCount,
    bool? following,
  }) => CommunityTopic(
    slug: slug,
    titleCopyKey: titleCopyKey,
    descriptionCopyKey: descriptionCopyKey,
    iconKey: iconKey,
    featured: featured,
    followerCount: followerCount ?? this.followerCount,
    postCount: postCount ?? this.postCount,
    following: following ?? this.following,
  );

  factory CommunityTopic.fromJson(Map<String, dynamic> json) {
    int count(Object? value) {
      if (value is! num || value < 0 || value % 1 != 0) {
        throw const FormatException('Invalid Community topic count');
      }
      return value.toInt();
    }

    final slug = json['slug'];
    final titleCopyKey = json['title_copy_key'];
    final descriptionCopyKey = json['description_copy_key'];
    final iconKey = json['icon_key'];
    final featured = json['featured'];
    final following = json['following'];

    if (slug is! String ||
        slug.length > 48 ||
        !slugPattern.hasMatch(slug) ||
        titleCopyKey is! String ||
        !copyKeyPattern.hasMatch(titleCopyKey) ||
        descriptionCopyKey is! String ||
        !copyKeyPattern.hasMatch(descriptionCopyKey) ||
        iconKey is! String ||
        iconKey.isEmpty ||
        iconKey.length > 48 ||
        featured is! bool ||
        following is! bool) {
      throw const FormatException('Invalid Community topic');
    }

    return CommunityTopic(
      slug: slug,
      titleCopyKey: titleCopyKey,
      descriptionCopyKey: descriptionCopyKey,
      iconKey: iconKey,
      featured: featured,
      followerCount: count(json['follower_count']),
      postCount: count(json['post_count']),
      following: following,
    );
  }
}

class CommunityTopicPostReference {
  const CommunityTopicPostReference({
    required this.postId,
    required this.createdAt,
  });

  final String postId;
  final DateTime createdAt;

  factory CommunityTopicPostReference.fromJson(Map<String, dynamic> json) {
    final postId = json['post_id'];
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    if (postId is! String || createdAt == null) {
      throw const FormatException('Invalid Community topic post reference');
    }
    return CommunityTopicPostReference(
      postId: postId,
      createdAt: createdAt,
    );
  }
}

class CommunityTopicPostBatch {
  const CommunityTopicPostBatch({
    required this.posts,
    required this.hasMore,
    this.nextBefore,
    this.nextBeforeId,
  });

  final List<CommunityPost> posts;
  final bool hasMore;
  final DateTime? nextBefore;
  final String? nextBeforeId;
}