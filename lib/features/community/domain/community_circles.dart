import 'community_models.dart';

enum CommunityCircleAccess { public, private }

enum CommunityCircleJoinPolicy { open, request, invite }

enum CommunityCircleMembershipStatus { active, pending, banned }

enum CommunityCircleMembershipRole { member, moderator }

class CommunityCircle {
  const CommunityCircle({
    required this.slug,
    required this.titleCopyKey,
    required this.descriptionCopyKey,
    required this.rulesCopyKey,
    required this.access,
    required this.joinPolicy,
    required this.featured,
    required this.memberCount,
    required this.postCount,
    this.membershipStatus,
    this.membershipRole,
  });

  static final RegExp slugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
  static final RegExp copyKeyPattern = RegExp(r'^[a-z][a-z0-9_]{2,63}$');

  final String slug;
  final String titleCopyKey;
  final String descriptionCopyKey;
  final String rulesCopyKey;
  final CommunityCircleAccess access;
  final CommunityCircleJoinPolicy joinPolicy;
  final bool featured;
  final int memberCount;
  final int postCount;
  final CommunityCircleMembershipStatus? membershipStatus;
  final CommunityCircleMembershipRole? membershipRole;

  bool get activeMember =>
      membershipStatus == CommunityCircleMembershipStatus.active;
  bool get pending =>
      membershipStatus == CommunityCircleMembershipStatus.pending;

  CommunityCircle copyWith({
    int? memberCount,
    int? postCount,
    CommunityCircleMembershipStatus? membershipStatus,
    bool clearMembership = false,
  }) => CommunityCircle(
    slug: slug,
    titleCopyKey: titleCopyKey,
    descriptionCopyKey: descriptionCopyKey,
    rulesCopyKey: rulesCopyKey,
    access: access,
    joinPolicy: joinPolicy,
    featured: featured,
    memberCount: memberCount ?? this.memberCount,
    postCount: postCount ?? this.postCount,
    membershipStatus: clearMembership
        ? null
        : membershipStatus ?? this.membershipStatus,
    membershipRole: clearMembership ? null : membershipRole,
  );

  factory CommunityCircle.fromJson(Map<String, dynamic> json) {
    int count(Object? value) {
      if (value is! num || value < 0 || value % 1 != 0) {
        throw const FormatException('Invalid Community circle count');
      }
      return value.toInt();
    }

    T? nullableEnum<T extends Enum>(Object? value, List<T> values) {
      if (value == null) return null;
      if (value is! String) {
        throw const FormatException('Invalid Community circle enum');
      }
      for (final item in values) {
        if (item.name == value) return item;
      }
      throw const FormatException('Invalid Community circle enum');
    }

    final slug = json['slug'];
    final titleCopyKey = json['title_copy_key'];
    final descriptionCopyKey = json['description_copy_key'];
    final rulesCopyKey = json['rules_copy_key'];
    final rawAccess = json['access'];
    final rawJoin = json['join_policy'];
    final featured = json['featured'];

    if (slug is! String ||
        slug.length > 48 ||
        !slugPattern.hasMatch(slug) ||
        titleCopyKey is! String ||
        !copyKeyPattern.hasMatch(titleCopyKey) ||
        descriptionCopyKey is! String ||
        !copyKeyPattern.hasMatch(descriptionCopyKey) ||
        rulesCopyKey is! String ||
        !copyKeyPattern.hasMatch(rulesCopyKey) ||
        rawAccess is! String ||
        !CommunityCircleAccess.values.any((value) => value.name == rawAccess) ||
        rawJoin is! String ||
        !CommunityCircleJoinPolicy.values.any(
          (value) => value.name == rawJoin,
        ) ||
        featured is! bool) {
      throw const FormatException('Invalid Community circle');
    }

    return CommunityCircle(
      slug: slug,
      titleCopyKey: titleCopyKey,
      descriptionCopyKey: descriptionCopyKey,
      rulesCopyKey: rulesCopyKey,
      access: CommunityCircleAccess.values.byName(rawAccess),
      joinPolicy: CommunityCircleJoinPolicy.values.byName(rawJoin),
      featured: featured,
      memberCount: count(json['member_count']),
      postCount: count(json['post_count']),
      membershipStatus: nullableEnum(
        json['membership_status'],
        CommunityCircleMembershipStatus.values,
      ),
      membershipRole: nullableEnum(
        json['membership_role'],
        CommunityCircleMembershipRole.values,
      ),
    );
  }
}

class CommunityCirclePostReference {
  const CommunityCirclePostReference({
    required this.postId,
    required this.createdAt,
  });

  final String postId;
  final DateTime createdAt;

  factory CommunityCirclePostReference.fromJson(Map<String, dynamic> json) {
    final postId = json['post_id'];
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    if (postId is! String || createdAt == null) {
      throw const FormatException('Invalid Community circle post reference');
    }
    return CommunityCirclePostReference(postId: postId, createdAt: createdAt);
  }
}

class CommunityCirclePostBatch {
  const CommunityCirclePostBatch({
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
