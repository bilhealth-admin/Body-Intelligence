part of 'community_repository.dart';

mixin _CommunityProfileModerationRepositoryMixin {
  SupabaseClient get _client;

  User get _user;

  CommunityPostStoreContract get _posts;

  Future<CommunityProfile?> loadMyProfile() async {
    final row = await _client
        .from('bil_public_profiles')
        .select(
          'user_id,display_name,avatar_url,bio,locale_code,discoverable,profile_visibility,allow_friend_requests,allow_follows,allow_messages_from,country_code,show_followers,show_following,show_friends,show_posts,show_membership_tier',
        )
        .eq('user_id', _user.id)
        .maybeSingle();
    return row == null ? null : CommunityProfile.fromJson(row);
  }

  Future<CommunityProfileOverview?> loadMyProfileOverview() async {
    try {
      return await loadProfileOverview(_user.id);
    } on Object {
      final profile = await loadMyProfile();
      return profile == null
          ? null
          : CommunityProfileOverview.fromProfile(profile);
    }
  }

  Future<CommunityProfileOverview> loadProfileOverview(String userId) async {
    if (!CommunityRepository._uuid.hasMatch(userId)) {
      throw ArgumentError.value(userId, 'userId');
    }
    final response = await _client.rpc(
      'bil_community_profile_projection_v1',
      params: {'p_user_id': userId},
    );
    if (response is! Map) {
      throw const FormatException('Invalid Community profile projection');
    }
    final overview = CommunityProfileOverview.fromJson(
      Map<String, dynamic>.from(response),
    );
    if (overview.userId != userId) {
      throw const FormatException('Community profile projection mismatch');
    }
    return overview;
  }

  Future<List<CommunityProfileConnection>> loadProfileConnections({
    required String userId,
    required CommunityProfileConnectionKind kind,
    DateTime? before,
    String? beforeUserId,
    int limit = 30,
  }) async {
    if (!CommunityRepository._uuid.hasMatch(userId) ||
        (before == null) != (beforeUserId == null) ||
        (beforeUserId != null &&
            !CommunityRepository._uuid.hasMatch(beforeUserId)) ||
        limit < 1 ||
        limit > 60) {
      throw ArgumentError('Invalid Community profile connection cursor');
    }
    final response = await _client.rpc(
      'bil_community_profile_connections_v2',
      params: {
        'p_user_id': userId,
        'p_kind': kind.name,
        'p_before': before?.toUtc().toIso8601String(),
        'p_before_user_id': beforeUserId,
        'p_limit': limit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community profile connections');
    }
    return List<CommunityProfileConnection>.unmodifiable(
      response.map((row) {
        if (row is! Map) {
          throw const FormatException('Invalid Community profile connection');
        }
        return CommunityProfileConnection.fromJson(
          Map<String, dynamic>.from(row),
        );
      }),
    );
  }

  Future<void> saveMyProfilePrivacy({
    String? countryCode,
    required bool showFollowers,
    required bool showFollowing,
    required bool showFriends,
    required bool showPosts,
    required bool showMembershipTier,
  }) async {
    final normalizedCountry = countryCode?.trim().toUpperCase();
    final validCountry =
        normalizedCountry == null ||
        normalizedCountry.isEmpty ||
        (normalizedCountry.length == 2 &&
            normalizedCountry.codeUnits.every(
              (unit) => unit >= 65 && unit <= 90,
            ));
    if (!validCountry) {
      throw const FormatException('Invalid Community country code');
    }
    final changed = await _client
        .from('bil_public_profiles')
        .update({
          'country_code': normalizedCountry == null || normalizedCountry.isEmpty
              ? null
              : normalizedCountry,
          'show_followers': showFollowers,
          'show_following': showFollowing,
          'show_friends': showFriends,
          'show_posts': showPosts,
          'show_membership_tier': showMembershipTier,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', _user.id)
        .select('user_id');
    if (changed.length != 1) {
      throw StateError('Community profile privacy was not available to update');
    }
  }

  Future<void> saveMyProfile({
    required String displayName,
    required String localeCode,
    required bool discoverable,
    String? bio,
    CommunityProfileVisibility visibility = CommunityProfileVisibility.friends,
    bool allowFriendRequests = true,
    bool allowFollows = false,
    CommunityMessagePermission allowMessagesFrom =
        CommunityMessagePermission.friends,
  }) async {
    final name = displayName.trim();
    final about = bio?.trim();
    if (name.length < 2 || name.length > 60) {
      throw const FormatException('Invalid community display name');
    }
    final canonicalLocale = BilLocalePolicy.canonicalSupportedTag(localeCode);
    if (canonicalLocale == null) {
      throw const FormatException('Unsupported community locale');
    }
    if (about != null && about.length > 280) {
      throw const FormatException('Community bio is too long');
    }
    CommunityTextPolicy.enforceAll({
      CommunityTextSurface.profileDisplayName: name,
      CommunityTextSurface.profileBio: about,
    });
    await _client.from('bil_public_profiles').upsert({
      'user_id': _user.id,
      'display_name': name,
      'bio': about == null || about.isEmpty ? null : about,
      'locale_code': canonicalLocale,
      'discoverable': discoverable,
      'profile_visibility': visibility.name,
      'allow_friend_requests': allowFriendRequests,
      'allow_follows': allowFollows,
      'allow_messages_from': allowMessagesFrom.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<bool> isCommunityModerator() async {
    if (_client.auth.currentUser == null) return false;
    final response = await _client.rpc('bil_is_community_moderator');
    if (response is! bool) {
      throw const FormatException('Invalid community moderator result');
    }
    return response;
  }

  Future<List<CommunityPost>> loadPendingPostsForModeration({
    int limit = 100,
  }) => _posts.loadModerationQueue(limit: limit);

  Future<CommunityPostModerationResult> moderatePost({
    required String postId,
    required CommunityPostModerationDecision decision,
  }) async {
    if (!CommunityRepository._uuid.hasMatch(postId)) {
      throw ArgumentError.value(postId, 'postId');
    }
    final response = await _client.rpc(
      'bil_moderate_community_post',
      params: {'p_post_id': postId, 'p_decision': decision.name},
    );
    if (response is! Map) {
      throw const FormatException('Invalid community moderation result');
    }
    return CommunityPostModerationResult.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> removePublishedPostAsModerator({
    required String postId,
    required String reason,
  }) async {
    if (!CommunityRepository._uuid.hasMatch(postId)) {
      throw ArgumentError.value(postId, 'postId');
    }
    if (!const {
      'spam',
      'abuse',
      'misleading',
      'privacy',
      'unsafe_or_inappropriate',
      'other',
    }.contains(reason)) {
      throw ArgumentError.value(reason, 'reason');
    }
    await _client.rpc(
      'bil_remove_published_community_post',
      params: {'p_post_id': postId, 'p_reason': reason},
    );
  }

  Future<void> hidePublishedPostAsModerator({
    required String postId,
    required String reason,
  }) => _moderatePublishedPost(postId: postId, action: 'hide', reason: reason);

  Future<void> restoreHiddenPostAsModerator({required String postId}) =>
      _moderatePublishedPost(postId: postId, action: 'restore');

  Future<void> _moderatePublishedPost({
    required String postId,
    required String action,
    String? reason,
  }) async {
    if (!CommunityRepository._uuid.hasMatch(postId)) {
      throw ArgumentError.value(postId, 'postId');
    }
    const reasons = {
      'spam',
      'abuse',
      'misleading',
      'privacy',
      'unsafe_or_inappropriate',
      'other',
    };
    if (action != 'restore' && !reasons.contains(reason)) {
      throw ArgumentError.value(reason, 'reason');
    }
    await _client.rpc(
      'bil_moderate_published_community_post',
      params: {'p_post_id': postId, 'p_action': action, 'p_reason': reason},
    );
  }

  Future<List<CommunityPost>> loadHiddenPostsForModeration({
    int limit = 100,
  }) async {
    final response = await _client.rpc(
      'bil_list_hidden_community_posts',
      params: {'p_limit': limit.clamp(1, 100)},
    );
    if (response is! List) {
      throw const FormatException('Invalid hidden Community posts result');
    }
    return response
        .whereType<Map>()
        .map((row) => CommunityPost.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}
