enum CommunityCreatorCertificationStatus {
  notCertified('not_certified'),
  approved('approved'),
  revoked('revoked');

  const CommunityCreatorCertificationStatus(this.wireValue);
  final String wireValue;

  static CommunityCreatorCertificationStatus fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const FormatException(
          'Invalid Community creator certification status',
        ),
      );
}

class CommunityCreatorBadge {
  const CommunityCreatorBadge({
    required this.badgeKey,
    required this.earned,
  });

  static const allowedKeys = <String>{
    'profile_complete',
    'first_moment',
    'contributor',
    'conversation_starter',
    'appreciated',
    'connector',
    'referral_builder',
  };

  final String badgeKey;
  final bool earned;

  factory CommunityCreatorBadge.fromJson(Map<String, dynamic> json) {
    final badgeKey = json['badge_key'];
    final earned = json['earned'];
    if (badgeKey is! String ||
        !allowedKeys.contains(badgeKey) ||
        earned is! bool) {
      throw const FormatException('Invalid Community creator badge');
    }
    return CommunityCreatorBadge(badgeKey: badgeKey, earned: earned);
  }
}

int _communityReferenceInt(Object? value, String field) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0 && value % 1 == 0) return value.toInt();
  throw FormatException('Invalid Community reference field: $field');
}

class CommunityCreatorProfile {
  const CommunityCreatorProfile({
    required this.userId,
    required this.contributor,
    required this.approvedPosts,
    required this.followers,
    required this.likesReceived,
    required this.commentsReceived,
    required this.qualifiedReferrals,
    required this.communityXp,
    required this.communityLevel,
    required this.currentLevelMinXp,
    required this.earnedBadgeCount,
    required this.totalBadgeCount,
    required this.badges,
    required this.certificationStatus,
    this.nextCommunityLevel,
    this.nextLevelMinXp,
  });

  final String userId;
  final bool contributor;
  final int approvedPosts;
  final int followers;
  final int likesReceived;
  final int commentsReceived;
  final int qualifiedReferrals;
  final int communityXp;
  final int communityLevel;
  final int currentLevelMinXp;
  final int? nextCommunityLevel;
  final int? nextLevelMinXp;
  final int earnedBadgeCount;
  final int totalBadgeCount;
  final List<CommunityCreatorBadge> badges;
  final CommunityCreatorCertificationStatus certificationStatus;

  double get levelProgress {
    final next = nextLevelMinXp;
    if (next == null || next <= currentLevelMinXp) return 1;
    final earnedInLevel = communityXp - currentLevelMinXp;
    final requiredInLevel = next - currentLevelMinXp;
    return (earnedInLevel / requiredInLevel).clamp(0, 1).toDouble();
  }

  factory CommunityCreatorProfile.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'];
    final contributor = json['contributor'];
    final rawBadges = json['badges'];
    if (userId is! String || contributor is! bool || rawBadges is! List) {
      throw const FormatException('Invalid Community creator projection');
    }
    final badges = List<CommunityCreatorBadge>.unmodifiable(
      rawBadges.map((raw) {
        if (raw is! Map) {
          throw const FormatException('Invalid Community creator badge row');
        }
        return CommunityCreatorBadge.fromJson(Map<String, dynamic>.from(raw));
      }),
    );
    final earned = _communityReferenceInt(
      json['earned_badge_count'],
      'earned_badge_count',
    );
    final total = _communityReferenceInt(
      json['total_badge_count'],
      'total_badge_count',
    );
    if (badges.length != total ||
        badges.where((badge) => badge.earned).length != earned) {
      throw const FormatException('Community creator badge totals mismatch');
    }

    int? optionalInt(String key) {
      final value = json[key];
      if (value == null) return null;
      return _communityReferenceInt(value, key);
    }

    return CommunityCreatorProfile(
      userId: userId,
      contributor: contributor,
      approvedPosts: _communityReferenceInt(
        json['approved_posts'],
        'approved_posts',
      ),
      followers: _communityReferenceInt(json['followers'], 'followers'),
      likesReceived: _communityReferenceInt(
        json['likes_received'],
        'likes_received',
      ),
      commentsReceived: _communityReferenceInt(
        json['comments_received'],
        'comments_received',
      ),
      qualifiedReferrals: _communityReferenceInt(
        json['qualified_referrals'],
        'qualified_referrals',
      ),
      communityXp: _communityReferenceInt(json['community_xp'], 'community_xp'),
      communityLevel: _communityReferenceInt(
        json['community_level'],
        'community_level',
      ),
      currentLevelMinXp: _communityReferenceInt(
        json['current_level_min_xp'],
        'current_level_min_xp',
      ),
      nextCommunityLevel: optionalInt('next_community_level'),
      nextLevelMinXp: optionalInt('next_level_min_xp'),
      earnedBadgeCount: earned,
      totalBadgeCount: total,
      badges: badges,
      certificationStatus: CommunityCreatorCertificationStatus.fromWire(
        json['certification_status'],
      ),
    );
  }
}

class CommunityProfileReview {
  const CommunityProfileReview({
    required this.reviewId,
    required this.productKind,
    required this.canonicalName,
    required this.createdAt,
    this.brand,
    this.reviewNote,
  });

  final String reviewId;
  final String productKind;
  final String canonicalName;
  final String? brand;
  final String? reviewNote;
  final DateTime createdAt;

  factory CommunityProfileReview.fromJson(Map<String, dynamic> json) {
    final reviewId = json['review_id'];
    final productKind = json['product_kind'];
    final canonicalName = json['canonical_name'];
    final brand = json['brand'];
    final reviewNote = json['review_note'];
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    if (reviewId is! String ||
        productKind is! String ||
        productKind.isEmpty ||
        canonicalName is! String ||
        canonicalName.trim().isEmpty ||
        (brand != null && brand is! String) ||
        (reviewNote != null && reviewNote is! String) ||
        createdAt == null) {
      throw const FormatException('Invalid Community profile review');
    }
    return CommunityProfileReview(
      reviewId: reviewId,
      productKind: productKind,
      canonicalName: canonicalName,
      brand: brand as String?,
      reviewNote: reviewNote as String?,
      createdAt: createdAt,
    );
  }
}
