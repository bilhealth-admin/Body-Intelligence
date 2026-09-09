import '../../nutrition/domain/product_identity.dart';

part 'community_post_author_social.dart';

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
      );
}

enum CommunityProfileVisibility { public, friends, private }

enum CommunityMessagePermission { friends, nobody }

enum CommunityPostModerationStatus { pending, approved, rejected }

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

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.likeCount,
    required this.liked,
    this.parentId,
    this.authorName,
    this.authorAvatarUrl,
    this.authorHandle,
  });

  final String id;
  final String authorId;
  final String? parentId;
  final String body;
  final DateTime createdAt;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorHandle;
  final int likeCount;
  final bool liked;

  CommunityComment copyWith({int? likeCount, bool? liked}) => CommunityComment(
    id: id,
    authorId: authorId,
    parentId: parentId,
    body: body,
    createdAt: createdAt,
    authorName: authorName,
    authorAvatarUrl: authorAvatarUrl,
    authorHandle: authorHandle,
    likeCount: likeCount ?? this.likeCount,
    liked: liked ?? this.liked,
  );

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final authorId = json['author_id'];
    final parentId = json['parent_id'];
    final body = json['body'];
    final createdAt = json['created_at'];
    final authorName = json['author_name'];
    final avatarUrl = json['avatar_url'];
    final handle = json['handle'];
    final likeCount = json['like_count'];
    final liked = json['liked'];
    final parsedAt = createdAt is String ? DateTime.tryParse(createdAt) : null;
    if (id is! String ||
        authorId is! String ||
        (parentId != null && parentId is! String) ||
        body is! String ||
        body.trim().isEmpty ||
        body.length > 1200 ||
        parsedAt == null ||
        (authorName != null && authorName is! String) ||
        (avatarUrl != null && avatarUrl is! String) ||
        (handle != null && handle is! String) ||
        likeCount is! num ||
        likeCount < 0 ||
        likeCount % 1 != 0 ||
        liked is! bool) {
      throw const FormatException('Invalid Community comment');
    }
    return CommunityComment(
      id: id,
      authorId: authorId,
      parentId: parentId as String?,
      body: body,
      createdAt: parsedAt,
      authorName: authorName as String?,
      authorAvatarUrl: avatarUrl as String?,
      authorHandle: handle as String?,
      likeCount: likeCount.toInt(),
      liked: liked,
    );
  }
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.authorName,
    this.authorAvatarUrl,
    this.mediaObjectPath,
    this.mediaUrl,
    this.mediaMimeType,
    this.mediaBytes,
    this.mediaWidth,
    this.mediaHeight,
    this.moderationStatus = CommunityPostModerationStatus.approved,
    this.reviewedAt,
    this.likeCount = 0,
    this.liked = false,
    this.commentCount = 0,
    this.saved = false,
    this.authorHandle,
    this.authorRelationship,
    this.authorCanRequest = false,
  });

  final String id;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? mediaObjectPath;
  final String? mediaUrl;
  final String? mediaMimeType;
  final int? mediaBytes;
  final int? mediaWidth;
  final int? mediaHeight;
  final CommunityPostModerationStatus moderationStatus;
  final DateTime? reviewedAt;
  final int likeCount;
  final bool liked;
  final int commentCount;
  final bool saved;
  final String? authorHandle;
  final CommunityRelationshipStatus? authorRelationship;
  final bool authorCanRequest;

  CommunityPost withStats(CommunityPostStats stats) {
    if (stats.postId != id) {
      throw const FormatException('Community post statistics did not match');
    }
    return CommunityPost(
      id: id,
      authorId: authorId,
      body: body,
      createdAt: createdAt,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      mediaObjectPath: mediaObjectPath,
      mediaUrl: mediaUrl,
      mediaMimeType: mediaMimeType,
      mediaBytes: mediaBytes,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      moderationStatus: moderationStatus,
      reviewedAt: reviewedAt,
      likeCount: stats.likeCount,
      liked: stats.liked,
      commentCount: stats.commentCount,
      saved: saved,
      authorHandle: authorHandle,
      authorRelationship: authorRelationship,
      authorCanRequest: authorCanRequest,
    );
  }

  CommunityPost withSaved(bool value) => CommunityPost(
    id: id,
    authorId: authorId,
    body: body,
    createdAt: createdAt,
    authorName: authorName,
    authorAvatarUrl: authorAvatarUrl,
    mediaObjectPath: mediaObjectPath,
    mediaUrl: mediaUrl,
    mediaMimeType: mediaMimeType,
    mediaBytes: mediaBytes,
    mediaWidth: mediaWidth,
    mediaHeight: mediaHeight,
    moderationStatus: moderationStatus,
    reviewedAt: reviewedAt,
    likeCount: likeCount,
    liked: liked,
    commentCount: commentCount,
    saved: value,
    authorHandle: authorHandle,
    authorRelationship: authorRelationship,
    authorCanRequest: authorCanRequest,
  );

  CommunityPost withAuthorSocial(CommunityPostAuthorSocial author) {
    if (author.userId != authorId) {
      throw const FormatException('Community post author did not match');
    }
    return CommunityPost(
      id: id,
      authorId: authorId,
      body: body,
      createdAt: createdAt,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      mediaObjectPath: mediaObjectPath,
      mediaUrl: mediaUrl,
      mediaMimeType: mediaMimeType,
      mediaBytes: mediaBytes,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      moderationStatus: moderationStatus,
      reviewedAt: reviewedAt,
      likeCount: likeCount,
      liked: liked,
      commentCount: commentCount,
      saved: saved,
      authorHandle: author.handle,
      authorRelationship: author.relationship,
      authorCanRequest: author.canRequest,
    );
  }

  bool get hasImage =>
      mediaObjectPath != null &&
      mediaMimeType != null &&
      mediaBytes != null &&
      mediaWidth != null &&
      mediaHeight != null;

  double? get mediaAspectRatio {
    final width = mediaWidth;
    final height = mediaHeight;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  factory CommunityPost.fromJson(Map<String, dynamic> json) => CommunityPost(
    id: json['id'] as String,
    authorId: json['author_id'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    authorName: json['author_name'] as String?,
    authorAvatarUrl: json['author_avatar_url'] as String?,
    mediaObjectPath: json['media_object_path'] as String?,
    mediaUrl: json['media_url'] as String?,
    mediaMimeType: json['media_mime_type'] as String?,
    mediaBytes: json['media_bytes'] as int?,
    mediaWidth: json['media_width'] as int?,
    mediaHeight: json['media_height'] as int?,
    moderationStatus: CommunityPostModerationStatus.values.firstWhere(
      (value) => value.name == json['moderation_status'],
      orElse: () => CommunityPostModerationStatus.approved,
    ),
    reviewedAt: json['reviewed_at'] == null
        ? null
        : DateTime.parse(json['reviewed_at'] as String),
    likeCount: json['like_count'] as int? ?? 0,
    liked: json['liked'] as bool? ?? false,
    commentCount: json['comment_count'] as int? ?? 0,
    saved: json['saved'] as bool? ?? false,
    authorHandle: json['author_handle'] as String?,
    authorRelationship: json['author_relationship'] == null
        ? null
        : CommunityRelationshipStatus.values.byName(
            json['author_relationship'] as String,
          ),
    authorCanRequest: json['author_can_request'] as bool? ?? false,
  );
}

class CommunityPostModerationResult {
  const CommunityPostModerationResult({
    required this.postId,
    required this.decision,
    required this.duplicate,
    required this.tokensGranted,
  });

  final String postId;
  final CommunityPostModerationDecision decision;
  final bool duplicate;
  final int tokensGranted;

  factory CommunityPostModerationResult.fromJson(Map<String, dynamic> json) {
    final postId = json['post_id'];
    final decision = json['decision'];
    final duplicate = json['duplicate'];
    final tokensGranted = json['tokens_granted'];
    if (postId is! String ||
        decision is! String ||
        duplicate is! bool ||
        tokensGranted is! int ||
        !const {'approved', 'rejected'}.contains(decision) ||
        !const {0, 5}.contains(tokensGranted) ||
        (decision == 'rejected' && tokensGranted != 0) ||
        (duplicate && tokensGranted != 0)) {
      throw const FormatException('Invalid community moderation result');
    }
    return CommunityPostModerationResult(
      postId: postId,
      decision: CommunityPostModerationDecision.values.byName(decision),
      duplicate: duplicate,
      tokensGranted: tokensGranted,
    );
  }
}

class CommunityMessage {
  const CommunityMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String recipientId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory CommunityMessage.fromJson(Map<String, dynamic> json) =>
      CommunityMessage(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        recipientId: json['recipient_id'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: json['read_at'] == null
            ? null
            : DateTime.parse(json['read_at'] as String),
      );
}

class CommunityFoodDraft {
  const CommunityFoodDraft({
    required this.name,
    required this.servingGrams,
    required this.calories,
    required this.protein,
    required this.carbohydrate,
    required this.fat,
    this.barcode,
    this.countryCode,
    this.evidenceUrl,
  });

  final String name;
  final double servingGrams;
  final double calories;
  final double protein;
  final double carbohydrate;
  final double fat;
  final String? barcode;
  final String? countryCode;
  final String? evidenceUrl;
}

class ProductReviewDraft {
  const ProductReviewDraft({
    required this.name,
    required this.barcode,
    required this.kind,
    this.brand,
    this.countryCode,
    this.evidenceUrl,
    this.note,
    this.observedSource,
    this.observedConfidence,
  });

  final String name;
  final String barcode;
  final ProductKind kind;
  final String? brand;
  final String? countryCode;
  final String? evidenceUrl;
  final String? note;
  final String? observedSource;
  final ProductIdentityConfidence? observedConfidence;
}

String productKindWireValue(ProductKind kind) => switch (kind) {
  ProductKind.personalCare => 'personal_care',
  ProductKind.petFood => 'pet_food',
  ProductKind.generalProduct => 'general_product',
  _ => kind.name,
};

String productConfidenceWireValue(ProductIdentityConfidence confidence) =>
    confidence.name;
