import '../../nutrition/domain/product_identity.dart';
import 'community_polls.dart';
import 'community_text_limits.dart';

part 'community_post_author_social.dart';
part 'community_content_models.dart';

class CommunityProfile {
  const CommunityProfile({
    required this.userId,
    required this.displayName,
    required this.localeCode,
    required this.discoverable,
    this.avatarUrl,
    this.bio,
    this.visibility = CommunityProfileVisibility.friends,
    this.allowFriendRequests = true,
    this.allowFollows = false,
    this.allowMessagesFrom = CommunityMessagePermission.friends,
    this.countryCode,
    this.showFollowers = true,
    this.showFollowing = true,
    this.showFriends = true,
    this.showPosts = true,
    this.showMembershipTier = false,
  });

  final String userId;
  final String displayName;
  final String localeCode;
  final bool discoverable;
  final String? avatarUrl;
  final String? bio;
  final CommunityProfileVisibility visibility;
  final bool allowFriendRequests;
  final bool allowFollows;
  final CommunityMessagePermission allowMessagesFrom;
  final String? countryCode;
  final bool showFollowers;
  final bool showFollowing;
  final bool showFriends;
  final bool showPosts;
  final bool showMembershipTier;

  factory CommunityProfile.fromJson(Map<String, dynamic> json) =>
      CommunityProfile(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String,
        localeCode: json['locale_code'] as String? ?? 'en',
        discoverable: json['discoverable'] as bool? ?? true,
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        visibility: CommunityProfileVisibility.values.firstWhere(
          (value) => value.name == json['profile_visibility'],
          orElse: () => CommunityProfileVisibility.friends,
        ),
        allowFriendRequests: json['allow_friend_requests'] as bool? ?? true,
        allowFollows: json['allow_follows'] as bool? ?? false,
        allowMessagesFrom: CommunityMessagePermission.values.firstWhere(
          (value) => value.name == json['allow_messages_from'],
          orElse: () => CommunityMessagePermission.friends,
        ),
        countryCode: json['country_code'] as String?,
        showFollowers: json['show_followers'] as bool? ?? true,
        showFollowing: json['show_following'] as bool? ?? true,
        showFriends: json['show_friends'] as bool? ?? true,
        showPosts: json['show_posts'] as bool? ?? true,
        showMembershipTier: json['show_membership_tier'] as bool? ?? false,
      );
}

class CommunityProfileOverview {
  const CommunityProfileOverview({
    required this.userId,
    required this.displayName,
    required this.isSelf,
    required this.relationship,
    required this.allowFriendRequests,
    required this.allowFollows,
    required this.showFollowers,
    required this.showFollowing,
    required this.showFriends,
    required this.showPosts,
    required this.showMembershipTier,
    this.avatarUrl,
    this.bio,
    this.localeCode,
    this.countryCode,
    this.handle,
    this.followerCount,
    this.followingCount,
    this.friendCount,
    this.postCount,
    this.communityXp,
    this.communityLevel,
    this.communityLevelCopyKey,
    this.viewerFollows = false,
    this.followsViewer = false,
    this.nextCommunityLevel,
    this.nextLevelMinXp,
    this.currentLevelMinXp,
    this.goldBalance,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? localeCode;
  final String? countryCode;
  final String? handle;
  final bool isSelf;
  final CommunityRelationshipStatus relationship;
  final bool allowFriendRequests;
  final bool allowFollows;
  final bool showFollowers;
  final bool showFollowing;
  final bool showFriends;
  final bool showPosts;
  final bool showMembershipTier;
  final int? followerCount;
  final int? followingCount;
  final int? friendCount;
  final int? postCount;
  final int? communityXp;
  final int? communityLevel;
  final String? communityLevelCopyKey;
  final bool viewerFollows;
  final bool followsViewer;
  final int? nextCommunityLevel;
  final int? nextLevelMinXp;
  final int? currentLevelMinXp;
  final int? goldBalance;

  factory CommunityProfileOverview.fromJson(Map<String, dynamic> json) {
    int? count(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! num || value < 0 || value % 1 != 0) {
        throw const FormatException('Invalid Community profile count');
      }
      return value.toInt();
    }

    bool validCountry(Object? value) {
      if (value == null) return true;
      if (value is! String || value.length != 2) return false;
      return value.codeUnits.every((unit) => unit >= 65 && unit <= 90);
    }

    final userId = json['user_id'];
    final displayName = json['display_name'];
    final avatarUrl = json['avatar_url'];
    final bio = json['bio'];
    final localeCode = json['locale_code'];
    final countryCode = json['country_code'];
    final handle = json['handle'];
    final isSelf = json['is_self'];
    final relationship = json['relationship'];
    final allowFriendRequests = json['allow_friend_requests'];
    final allowFollows = json['allow_follows'];
    final showFollowers = json['show_followers'];
    final showFollowing = json['show_following'];
    final showFriends = json['show_friends'];
    final showPosts = json['show_posts'];
    final showMembershipTier = json['show_membership_tier'];
    final levelCopyKey = json['community_level_copy_key'];
    final viewerFollows = json['viewer_follows'] ?? false;
    final followsViewer = json['follows_viewer'] ?? false;

    if (userId is! String ||
        displayName is! String ||
        displayName.trim().isEmpty ||
        displayName.length > 60 ||
        (avatarUrl != null && avatarUrl is! String) ||
        (bio != null && (bio is! String || bio.length > 280)) ||
        (localeCode != null && localeCode is! String) ||
        !validCountry(countryCode) ||
        (handle != null &&
            (handle is! String ||
                !CommunitySocialIdentity.handlePattern.hasMatch(handle))) ||
        isSelf is! bool ||
        relationship is! String ||
        !CommunityRelationshipStatus.values.any(
          (value) => value.name == relationship,
        ) ||
        allowFriendRequests is! bool ||
        allowFollows is! bool ||
        showFollowers is! bool ||
        showFollowing is! bool ||
        showFriends is! bool ||
        showPosts is! bool ||
        showMembershipTier is! bool ||
        viewerFollows is! bool ||
        followsViewer is! bool ||
        (levelCopyKey != null && levelCopyKey is! String)) {
      throw const FormatException('Invalid Community profile overview');
    }

    return CommunityProfileOverview(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl as String?,
      bio: bio as String?,
      localeCode: localeCode as String?,
      countryCode: countryCode as String?,
      handle: handle as String?,
      isSelf: isSelf,
      relationship: CommunityRelationshipStatus.values.byName(relationship),
      allowFriendRequests: allowFriendRequests,
      allowFollows: allowFollows,
      showFollowers: showFollowers,
      showFollowing: showFollowing,
      showFriends: showFriends,
      showPosts: showPosts,
      showMembershipTier: showMembershipTier,
      followerCount: count('follower_count'),
      followingCount: count('following_count'),
      friendCount: count('friend_count'),
      postCount: count('post_count'),
      communityXp: count('community_xp'),
      communityLevel: count('community_level'),
      communityLevelCopyKey: levelCopyKey as String?,
      viewerFollows: viewerFollows,
      followsViewer: followsViewer,
      nextCommunityLevel: count('next_community_level'),
      nextLevelMinXp: count('next_level_min_xp'),
      currentLevelMinXp: count('current_level_min_xp'),
      goldBalance: count('gold_balance'),
    );
  }

  factory CommunityProfileOverview.fromProfile(CommunityProfile profile) =>
      CommunityProfileOverview(
        userId: profile.userId,
        displayName: profile.displayName,
        avatarUrl: profile.avatarUrl,
        bio: profile.bio,
        localeCode: profile.localeCode,
        countryCode: profile.countryCode,
        isSelf: true,
        relationship: CommunityRelationshipStatus.self,
        allowFriendRequests: profile.allowFriendRequests,
        allowFollows: profile.allowFollows,
        showFollowers: profile.showFollowers,
        showFollowing: profile.showFollowing,
        showFriends: profile.showFriends,
        showPosts: profile.showPosts,
        showMembershipTier: profile.showMembershipTier,
      );
}

enum CommunityProfileConnectionKind { followers, following, friends }

class CommunityProfileConnection {
  const CommunityProfileConnection({
    required this.userId,
    required this.displayName,
    required this.relationship,
    required this.connectedAt,
    this.handle,
    this.avatarUrl,
    this.viewerFollows = false,
    this.followsViewer = false,
    this.allowFollows = false,
  });

  final String userId;
  final String? handle;
  final String displayName;
  final String? avatarUrl;
  final CommunityRelationshipStatus relationship;
  final DateTime connectedAt;
  final bool viewerFollows;
  final bool followsViewer;
  final bool allowFollows;

  factory CommunityProfileConnection.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'];
    final handle = json['handle'];
    final displayName = json['display_name'];
    final avatarUrl = json['avatar_url'];
    final relationship = json['relationship'];
    final viewerFollows = json['viewer_follows'] ?? false;
    final followsViewer = json['follows_viewer'] ?? false;
    final allowFollows = json['allow_follows'] ?? false;
    final connectedAt = DateTime.tryParse(
      json['connected_at']?.toString() ?? '',
    );
    if (userId is! String ||
        displayName is! String ||
        displayName.trim().isEmpty ||
        displayName.length > 60 ||
        (handle != null &&
            (handle is! String ||
                !CommunitySocialIdentity.handlePattern.hasMatch(handle))) ||
        (avatarUrl != null && avatarUrl is! String) ||
        relationship is! String ||
        !CommunityRelationshipStatus.values.any(
          (value) => value.name == relationship,
        ) ||
        viewerFollows is! bool ||
        followsViewer is! bool ||
        allowFollows is! bool ||
        connectedAt == null) {
      throw const FormatException('Invalid Community profile connection');
    }
    return CommunityProfileConnection(
      userId: userId,
      handle: handle as String?,
      displayName: displayName,
      avatarUrl: avatarUrl as String?,
      relationship: CommunityRelationshipStatus.values.byName(relationship),
      connectedAt: connectedAt,
      viewerFollows: viewerFollows,
      followsViewer: followsViewer,
      allowFollows: allowFollows,
    );
  }
}

enum CommunityProfileVisibility { public, friends, private }

enum CommunityMessagePermission { friends, nobody }

enum CommunityPostModerationStatus { pending, approved, rejected }

enum CommunityPostModerationVisibility {
  visible,
  hiddenByModerator,
  removedByModerator;

  static CommunityPostModerationVisibility fromWire(Object? value) =>
      switch (value) {
        'hidden_by_moderator' => hiddenByModerator,
        'removed_by_moderator' => removedByModerator,
        _ => visible,
      };
}

enum CommunityPostModerationDecision { approved, rejected }

enum CommunityFriendRequestStatus { pending, incoming, accepted, declined }

enum CommunityRelationshipStatus { none, pending, incoming, accepted, self }

class CommunitySocialIdentity {
  const CommunitySocialIdentity({
    required this.handle,
    required this.chosen,
    required this.discoverable,
  });

  final String handle;
  final bool chosen;
  final bool discoverable;

  static final RegExp handlePattern = RegExp(r'^[a-z][a-z0-9_]{2,29}$');
  static const reservedHandles = <String>{
    'admin',
    'administrator',
    'support',
    'bil',
    'bilhealth',
    'moderator',
    'official',
  };

  static String normalize(String value) =>
      value.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');

  static bool isValidCandidate(String value) {
    final normalized = normalize(value);
    return handlePattern.hasMatch(normalized) &&
        !reservedHandles.contains(normalized);
  }

  factory CommunitySocialIdentity.fromJson(Map<String, dynamic> json) {
    final handle = json['handle'];
    final chosen = json['chosen'];
    final discoverable = json['discoverable'];
    if (handle is! String ||
        !handlePattern.hasMatch(handle) ||
        chosen is! bool ||
        discoverable is! bool) {
      throw const FormatException('Invalid Community identity');
    }
    return CommunitySocialIdentity(
      handle: handle,
      chosen: chosen,
      discoverable: discoverable,
    );
  }
}

class CommunityPostStats {
  const CommunityPostStats({
    required this.postId,
    required this.likeCount,
    required this.liked,
    required this.commentCount,
  });

  final String postId;
  final int likeCount;
  final bool liked;
  final int commentCount;

  factory CommunityPostStats.fromJson(Map<String, dynamic> json) {
    final postId = json['post_id'];
    final likeCount = json['like_count'];
    final liked = json['liked'];
    final commentCount = json['comment_count'];
    if (postId is! String ||
        likeCount is! num ||
        likeCount < 0 ||
        likeCount % 1 != 0 ||
        liked is! bool ||
        commentCount is! num ||
        commentCount < 0 ||
        commentCount % 1 != 0) {
      throw const FormatException('Invalid Community post statistics');
    }
    return CommunityPostStats(
      postId: postId,
      likeCount: likeCount.toInt(),
      liked: liked,
      commentCount: commentCount.toInt(),
    );
  }
}

class CommunitySavedState {
  const CommunitySavedState({required this.postId, required this.saved});

  final String postId;
  final bool saved;

  factory CommunitySavedState.fromJson(Map<String, dynamic> json) {
    final postId = json['post_id'];
    final saved = json['saved'];
    if (postId is! String || saved is! bool) {
      throw const FormatException('Invalid Community saved state');
    }
    return CommunitySavedState(postId: postId, saved: saved);
  }
}

class CommunitySavedPostReference {
  const CommunitySavedPostReference({
    required this.postId,
    required this.savedAt,
  });

  final String postId;
  final DateTime savedAt;

  factory CommunitySavedPostReference.fromJson(Map<String, dynamic> json) {
    final postId = json['post_id'];
    final rawSavedAt = json['saved_at'];
    final savedAt = rawSavedAt is String ? DateTime.tryParse(rawSavedAt) : null;
    if (postId is! String || savedAt == null) {
      throw const FormatException('Invalid Community saved post');
    }
    return CommunitySavedPostReference(postId: postId, savedAt: savedAt);
  }
}

class CommunitySavedPostBatch {
  const CommunitySavedPostBatch({
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

class CommunityFeedBatch {
  const CommunityFeedBatch({
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

class CommunityPublicCode {
  const CommunityPublicCode({
    required this.code,
    required this.uri,
    required this.handle,
  });

  static final RegExp codePattern = RegExp(r'^[a-f0-9]{32}$');

  final String code;
  final Uri uri;
  final String handle;

  factory CommunityPublicCode.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final rawUri = json['uri'];
    final handle = json['handle'];
    final uri = rawUri is String ? Uri.tryParse(rawUri) : null;
    final validUri =
        code is String &&
        uri != null &&
        uri.scheme == 'bil' &&
        uri.host == 'community' &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'member' &&
        uri.pathSegments.last == code &&
        uri.queryParameters.isEmpty &&
        uri.fragment.isEmpty;
    if (!validUri ||
        !codePattern.hasMatch(code) ||
        handle is! String ||
        !CommunitySocialIdentity.handlePattern.hasMatch(handle)) {
      throw const FormatException('Invalid Community public code');
    }
    return CommunityPublicCode(code: code, uri: uri, handle: handle);
  }
}

class CommunityResolvedMember {
  const CommunityResolvedMember({
    required this.userId,
    required this.handle,
    required this.displayName,
    required this.relationship,
    this.avatarUrl,
  });

  final String userId;
  final String handle;
  final String displayName;
  final String? avatarUrl;
  final CommunityRelationshipStatus relationship;

  factory CommunityResolvedMember.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'];
    final handle = json['handle'];
    final displayName = json['display_name'];
    final avatarUrl = json['avatar_url'];
    final relationship = json['relationship'];
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    if (userId is! String ||
        !uuid.hasMatch(userId) ||
        handle is! String ||
        !CommunitySocialIdentity.handlePattern.hasMatch(handle) ||
        displayName is! String ||
        displayName.trim().length < 2 ||
        displayName.length > 60 ||
        (avatarUrl != null && avatarUrl is! String) ||
        relationship is! String ||
        !CommunityRelationshipStatus.values.any(
          (value) => value.name == relationship,
        )) {
      throw const FormatException('Invalid Community public member');
    }
    return CommunityResolvedMember(
      userId: userId,
      handle: handle,
      displayName: displayName,
      avatarUrl: avatarUrl as String?,
      relationship: CommunityRelationshipStatus.values.byName(relationship),
    );
  }
}
