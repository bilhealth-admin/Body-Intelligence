part of 'community_repository.dart';

mixin _CommunityReferenceParityRepositoryMixin {
  SupabaseClient get _client;

  User get _user;

  static const _profileAvatarBucket = 'profile-avatars';
  static const _profileCoverFolder = 'community-cover';
  static const _profileCoverUuid = Uuid();

  Future<String?> loadCommunityProfileCoverUrl(String userId) async {
    if (!CommunityRepository._uuid.hasMatch(userId)) {
      throw ArgumentError.value(userId, 'userId');
    }
    final response = await _client.rpc(
      'bil_community_profile_cover_v1',
      params: {'p_user_id': userId},
    );
    if (response == null) return null;
    if (response is! String ||
        !response.startsWith('$userId/$_profileCoverFolder/') ||
        !RegExp(
          r'^[0-9a-fA-F-]{36}/community-cover/[0-9a-fA-F-]{36}\.(jpg|png|webp)
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
,
        ).hasMatch(response)) {
      throw const FormatException('Invalid Community profile cover path');
    }
    return _client.storage
        .from(_profileAvatarBucket)
        .getPublicUrl(response);
  }

  Future<String> uploadMyCommunityProfileCover(
    CommunityPostImageDraft draft,
  ) async {
    final image = await validateCommunityPostImageAsync(draft.bytes);
    final objectId = _profileCoverUuid.v4();
    final path =
        '${_user.id}/$_profileCoverFolder/$objectId.${image.extension}';
    var uploaded = false;
    try {
      await _client.storage
          .from(_profileAvatarBucket)
          .uploadBinary(
            path,
            image.bytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: image.mimeType,
              cacheControl: '86400',
            ),
          );
      uploaded = true;

      final previous = await _client.rpc(
        'bil_set_my_community_profile_cover_v1',
        params: {'p_object_path': path},
      );
      if (previous != null && previous is! String) {
        throw const FormatException(
          'Invalid Community profile cover write receipt',
        );
      }
      if (previous is String &&
          previous.isNotEmpty &&
          previous != path) {
        try {
          await _client.storage
              .from(_profileAvatarBucket)
              .remove([previous]);
        } on Object {
          // The profile already points at the new cover. The old public object
          // can be cleaned independently without reverting user-visible state.
        }
      }
      return _client.storage.from(_profileAvatarBucket).getPublicUrl(path);
    } on Object {
      if (uploaded) {
        try {
          await _client.storage.from(_profileAvatarBucket).remove([path]);
        } on Object {
          // Best effort: the server setter remains authoritative.
        }
      }
      rethrow;
    }
  }

  Future<void> removeMyCommunityProfileCover() async {
    final previous = await _client.rpc(
      'bil_set_my_community_profile_cover_v1',
      params: {'p_object_path': null},
    );
    if (previous != null && previous is! String) {
      throw const FormatException(
        'Invalid Community profile cover remove receipt',
      );
    }
    if (previous is String && previous.isNotEmpty) {
      try {
        await _client.storage.from(_profileAvatarBucket).remove([previous]);
      } on Object {
        // The profile reference is already cleared.
      }
    }
  }

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
