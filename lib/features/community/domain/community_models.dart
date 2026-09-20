import '../../nutrition/domain/product_identity.dart';

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
