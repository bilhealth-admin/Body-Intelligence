part of 'community_repository.dart';

mixin _CommunityReferenceParityRepositoryMixin {
  SupabaseClient get _client;

  Future<CommunityCreatorProfile> loadCommunityCreatorProfile(
    String userId,
  ) async {
    if (!CommunityRepository._uuid.hasMatch(userId)) {
      throw ArgumentError.value(userId, 'userId');
    }
    final response = await _client.rpc(
      'bil_community_creator_projection_v1',
      params: {'p_user_id': userId},
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community creator projection');
    }
    final projection = CommunityCreatorProfile.fromJson(
      Map<String, dynamic>.from(response),
    );
    if (projection.userId != userId) {
      throw const FormatException('Community creator projection mismatch');
    }
    return projection;
  }

  Future<int> recordCommunityPostView(String postId) async {
    if (!CommunityRepository._uuid.hasMatch(postId)) {
      throw ArgumentError.value(postId, 'postId');
    }
    final response = await _client.rpc(
      'bil_record_community_post_view_v1',
      params: {'p_post_id': postId},
    );
    if (response is! num || response < 0 || response % 1 != 0) {
      throw const FormatException('Invalid Community post view count');
    }
    return response.toInt();
  }

  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return const <String, int>{};
    if (postIds.length > 100 ||
        postIds.toSet().length != postIds.length ||
        postIds.any((postId) => !CommunityRepository._uuid.hasMatch(postId))) {
      throw ArgumentError.value(postIds, 'postIds');
    }
    final response = await _client.rpc(
      'bil_community_post_view_counts_v1',
      params: {'p_post_ids': postIds},
    );
    if (response is! List) {
      throw const FormatException('Invalid Community post view counts');
    }
    final result = <String, int>{};
    for (final raw in response) {
      if (raw is! Map) {
        throw const FormatException('Invalid Community post view row');
      }
      final row = Map<String, dynamic>.from(raw);
      final postId = row['post_id'];
      final count = row['view_count'];
      if (postId is! String ||
          !postIds.contains(postId) ||
          count is! num ||
          count < 0 ||
          count % 1 != 0 ||
          result.containsKey(postId)) {
        throw const FormatException('Invalid Community post view row');
      }
      result[postId] = count.toInt();
    }
    return Map<String, int>.unmodifiable(result);
  }

  Future<Map<String, String>> loadCommentMembershipTiers(
    List<String> userIds,
  ) async {
    final unique = userIds.toSet().toList(growable: false);
    if (unique.isEmpty) return const <String, String>{};
    if (unique.length > 100 ||
        unique.any((id) => !CommunityRepository._uuid.hasMatch(id))) {
      throw ArgumentError.value(userIds, 'userIds');
    }
    final response = await _client.rpc(
      'bil_community_comment_membership_tiers_v1',
      params: {'p_user_ids': unique},
    );
    if (response is! List) {
      throw const FormatException(
        'Invalid Community comment membership tier batch',
      );
    }
    final result = <String, String>{};
    for (final raw in response) {
      if (raw is! Map) {
        throw const FormatException(
          'Invalid Community comment membership tier row',
        );
      }
      final row = Map<String, dynamic>.from(raw);
      final userId = row['user_id'];
      final tier = row['membership_tier'];
      if (userId is! String ||
          !unique.contains(userId) ||
          tier is! String ||
          !const {'free', 'premium'}.contains(tier) ||
          result.containsKey(userId)) {
        throw const FormatException(
          'Invalid Community comment membership tier row',
        );
      }
      result[userId] = tier;
    }
    return Map<String, String>.unmodifiable(result);
  }

  Future<List<CommunityProfileReview>> loadCommunityProfileReviews({
    required String userId,
    DateTime? before,
    String? beforeId,
    int limit = 24,
  }) async {
    if (!CommunityRepository._uuid.hasMatch(userId) ||
        (before == null) != (beforeId == null) ||
        (beforeId != null && !CommunityRepository._uuid.hasMatch(beforeId)) ||
        limit < 1 ||
        limit > 60) {
      throw ArgumentError('Invalid Community profile review cursor');
    }
    final response = await _client.rpc(
      'bil_community_profile_reviews_v1',
      params: {
        'p_user_id': userId,
        'p_before': before?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
        'p_limit': limit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community profile reviews');
    }
    return List<CommunityProfileReview>.unmodifiable(
      response.map((raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid Community profile review row');
        }
        return CommunityProfileReview.fromJson(Map<String, dynamic>.from(raw));
      }),
    );
  }
}
