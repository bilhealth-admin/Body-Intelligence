part of 'community_models.dart';

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.likeCount,
    required this.liked,
    this.replyCount = 0,
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
  final int replyCount;

  CommunityComment copyWith({int? likeCount, bool? liked, int? replyCount}) =>
      CommunityComment(
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
        replyCount: replyCount ?? this.replyCount,
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
    final replyCount = json['reply_count'] ?? 0;
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
        liked is! bool ||
        replyCount is! num ||
        replyCount < 0 ||
        replyCount % 1 != 0) {
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
      replyCount: replyCount.toInt(),
    );
  }
}

class CommunityPostMedia {
  const CommunityPostMedia({
    required this.position,
    required this.objectPath,
    required this.mimeType,
    required this.bytes,
    required this.width,
    required this.height,
    this.url,
  });

  final int position;
  final String objectPath;
  final String mimeType;
  final int bytes;
  final int width;
  final int height;
  final String? url;

  double get aspectRatio => width / height;

  CommunityPostMedia withUrl(String? value) => CommunityPostMedia(
    position: position,
    objectPath: objectPath,
    mimeType: mimeType,
    bytes: bytes,
    width: width,
    height: height,
    url: value,
  );

  factory CommunityPostMedia.fromJson(Map<String, dynamic> json) {
    final position = json['media_position'];
    final objectPath = json['object_path'];
    final mimeType = json['mime_type'];
    final bytes = json['bytes'];
    final width = json['width'];
    final height = json['height'];
    final url = json['url'];
    if (position is! num ||
        position % 1 != 0 ||
        position < 0 ||
        position > 3 ||
        objectPath is! String ||
        objectPath.isEmpty ||
        mimeType is! String ||
        !const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType) ||
        bytes is! num ||
        bytes % 1 != 0 ||
        bytes < 1 ||
        bytes > 5 * 1024 * 1024 ||
        width is! num ||
        width % 1 != 0 ||
        width < 1 ||
        width > 8192 ||
        height is! num ||
        height % 1 != 0 ||
        height < 1 ||
        height > 8192 ||
        width.toInt() * height.toInt() > 40000000 ||
        (url != null && url is! String)) {
      throw const FormatException('Invalid Community post media');
    }
    return CommunityPostMedia(
      position: position.toInt(),
      objectPath: objectPath,
      mimeType: mimeType,
      bytes: bytes.toInt(),
      width: width.toInt(),
      height: height.toInt(),
      url: url as String?,
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
    this.moderationVisibility = CommunityPostModerationVisibility.visible,
    this.reviewedAt,
    this.likeCount = 0,
    this.liked = false,
    this.commentCount = 0,
    this.saved = false,
    this.authorHandle,
    this.authorRelationship,
    this.authorCanRequest = false,
    this.poll,
    this.media = const <CommunityPostMedia>[],
    this.locationLabel,
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
  final CommunityPostModerationVisibility moderationVisibility;
  final DateTime? reviewedAt;
  final int likeCount;
  final bool liked;
  final int commentCount;
  final bool saved;
  final String? authorHandle;
  final CommunityRelationshipStatus? authorRelationship;
  final bool authorCanRequest;
  final CommunityPoll? poll;
  final List<CommunityPostMedia> media;
  final String? locationLabel;

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
      moderationVisibility: moderationVisibility,
      reviewedAt: reviewedAt,
      likeCount: stats.likeCount,
      liked: stats.liked,
      commentCount: stats.commentCount,
      saved: saved,
      authorHandle: authorHandle,
      authorRelationship: authorRelationship,
      authorCanRequest: authorCanRequest,
      poll: poll,
      media: media,
      locationLabel: locationLabel,
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
    moderationVisibility: moderationVisibility,
    reviewedAt: reviewedAt,
    likeCount: likeCount,
    liked: liked,
    commentCount: commentCount,
    saved: value,
    authorHandle: authorHandle,
    authorRelationship: authorRelationship,
    authorCanRequest: authorCanRequest,
    poll: poll,
    media: media,
    locationLabel: locationLabel,
  );

  CommunityPost withPoll(CommunityPoll? value) => CommunityPost(
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
    moderationVisibility: moderationVisibility,
    reviewedAt: reviewedAt,
    likeCount: likeCount,
    liked: liked,
    commentCount: commentCount,
    saved: saved,
    authorHandle: authorHandle,
    authorRelationship: authorRelationship,
    authorCanRequest: authorCanRequest,
    poll: value,
    media: media,
    locationLabel: locationLabel,
  );

  CommunityPost withMedia(List<CommunityPostMedia> value) => CommunityPost(
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
    moderationVisibility: moderationVisibility,
    reviewedAt: reviewedAt,
    likeCount: likeCount,
    liked: liked,
    commentCount: commentCount,
    saved: saved,
    authorHandle: authorHandle,
    authorRelationship: authorRelationship,
    authorCanRequest: authorCanRequest,
    poll: poll,
    media: List<CommunityPostMedia>.unmodifiable(value),
    locationLabel: locationLabel,
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
      moderationVisibility: moderationVisibility,
      reviewedAt: reviewedAt,
      likeCount: likeCount,
      liked: liked,
      commentCount: commentCount,
      saved: saved,
      authorHandle: author.handle,
      authorRelationship: author.relationship,
      authorCanRequest: author.canRequest,
      poll: poll,
      media: media,
      locationLabel: locationLabel,
    );
  }

  List<CommunityPostMedia> get mediaItems {
    if (media.isNotEmpty) return media;
    final path = mediaObjectPath;
    final mime = mediaMimeType;
    final byteCount = mediaBytes;
    final width = mediaWidth;
    final height = mediaHeight;
    if (path == null ||
        mime == null ||
        byteCount == null ||
        width == null ||
        height == null) {
      return const <CommunityPostMedia>[];
    }
    return <CommunityPostMedia>[
      CommunityPostMedia(
        position: 0,
        objectPath: path,
        mimeType: mime,
        bytes: byteCount,
        width: width,
        height: height,
        url: mediaUrl,
      ),
    ];
  }

  bool get hasImage => mediaItems.isNotEmpty;

  double? get mediaAspectRatio =>
      mediaItems.isEmpty ? null : mediaItems.first.aspectRatio;

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
    moderationVisibility: CommunityPostModerationVisibility.fromWire(
      json['moderation_visibility'],
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
    locationLabel: json['location_label'] as String?,
    poll: json['poll'] == null
        ? null
        : CommunityPoll.fromJson(
            Map<String, dynamic>.from(json['poll'] as Map),
          ),
    media: json['media'] is! List
        ? const <CommunityPostMedia>[]
        : List<CommunityPostMedia>.unmodifiable(
            (json['media'] as List).map((item) {
              if (item is! Map) {
                throw const FormatException('Invalid Community post media');
              }
              return CommunityPostMedia.fromJson(
                Map<String, dynamic>.from(item),
              );
            }),
          ),
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
