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

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.authorName,
    this.authorAvatarUrl,
  });

  final String id;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final String? authorName;
  final String? authorAvatarUrl;

  factory CommunityPost.fromJson(Map<String, dynamic> json) => CommunityPost(
    id: json['id'] as String,
    authorId: json['author_id'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    authorName: json['author_name'] as String?,
    authorAvatarUrl: json['author_avatar_url'] as String?,
  );
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
