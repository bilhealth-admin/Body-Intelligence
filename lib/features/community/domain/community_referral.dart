enum CommunityInviteCreateStatus {
  active('active'),
  disabled('disabled'),
  rateLimited('rate_limited');

  const CommunityInviteCreateStatus(this.wireValue);
  final String wireValue;

  static CommunityInviteCreateStatus fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () =>
            throw const FormatException('Invalid Community invite status'),
      );
}

class CommunityInviteCreateResult {
  const CommunityInviteCreateResult({
    required this.status,
    this.inviteId,
    this.token,
    this.url,
    this.expiresAt,
  });

  static final RegExp tokenPattern = RegExp(r'^[0-9a-f]{48}$');

  final CommunityInviteCreateStatus status;
  final String? inviteId;
  final String? token;
  final Uri? url;
  final DateTime? expiresAt;

  bool get active => status == CommunityInviteCreateStatus.active;

  factory CommunityInviteCreateResult.fromJson(Map<String, dynamic> json) {
    final status = CommunityInviteCreateStatus.fromWire(json['status']);
    if (status != CommunityInviteCreateStatus.active) {
      return CommunityInviteCreateResult(status: status);
    }

    final inviteId = json['invite_id'];
    final token = json['token'];
    final rawUrl = json['url'];
    final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    final expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '');
    if (inviteId is! String ||
        token is! String ||
        !tokenPattern.hasMatch(token) ||
        url == null ||
        url.scheme != 'https' ||
        url.host != 'www.bilhealth.com' ||
        url.pathSegments.length != 2 ||
        url.pathSegments.first != 'invite' ||
        url.pathSegments.last != token ||
        expiresAt == null) {
      throw const FormatException('Invalid Community invite payload');
    }
    return CommunityInviteCreateResult(
      status: status,
      inviteId: inviteId,
      token: token,
      url: url,
      expiresAt: expiresAt,
    );
  }
}

enum CommunityInvitePreviewStatus {
  active('active'),
  disabled('disabled'),
  invalid('invalid');

  const CommunityInvitePreviewStatus(this.wireValue);
  final String wireValue;

  static CommunityInvitePreviewStatus fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const FormatException(
          'Invalid Community invite preview status',
        ),
      );
}

class CommunityInvitePreview {
  const CommunityInvitePreview({
    required this.status,
    this.inviterId,
    this.displayName,
    this.avatarUrl,
    this.handle,
    this.expiresAt,
  });

  final CommunityInvitePreviewStatus status;
  final String? inviterId;
  final String? displayName;
  final String? avatarUrl;
  final String? handle;
  final DateTime? expiresAt;

  bool get active => status == CommunityInvitePreviewStatus.active;

  factory CommunityInvitePreview.fromJson(Map<String, dynamic> json) {
    final status = CommunityInvitePreviewStatus.fromWire(json['status']);
    if (status != CommunityInvitePreviewStatus.active) {
      return CommunityInvitePreview(status: status);
    }

    final inviterId = json['inviter_id'];
    final displayName = json['display_name'];
    final avatarUrl = json['avatar_url'];
    final handle = json['handle'];
    final expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '');
    if (inviterId is! String ||
        displayName is! String ||
        displayName.trim().isEmpty ||
        (avatarUrl != null && avatarUrl is! String) ||
        (handle != null && handle is! String) ||
        expiresAt == null) {
      throw const FormatException('Invalid Community invite preview');
    }

    return CommunityInvitePreview(
      status: status,
      inviterId: inviterId,
      displayName: displayName,
      avatarUrl: avatarUrl as String?,
      handle: handle as String?,
      expiresAt: expiresAt,
    );
  }
}

enum CommunityInviteAcceptStatus {
  attributed('attributed'),
  disabled('disabled'),
  invalid('invalid'),
  selfInvite('self_invite'),
  unavailable('unavailable'),
  alreadyAttributed('already_attributed'),
  consumed('consumed');

  const CommunityInviteAcceptStatus(this.wireValue);
  final String wireValue;

  static CommunityInviteAcceptStatus fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const FormatException(
          'Invalid Community invite acceptance status',
        ),
      );
}

class CommunityInviteAcceptance {
  const CommunityInviteAcceptance({
    required this.status,
    this.duplicate = false,
    this.attributionId,
    this.inviterId,
    this.displayName,
    this.avatarUrl,
    this.handle,
    this.friendshipId,
    this.relationship,
    this.newAccountEligible,
  });

  static final RegExp uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final CommunityInviteAcceptStatus status;
  final bool duplicate;
  final String? attributionId;
  final String? inviterId;
  final String? displayName;
  final String? avatarUrl;
  final String? handle;
  final String? friendshipId;
  final String? relationship;
  final bool? newAccountEligible;

  bool get attributed => status == CommunityInviteAcceptStatus.attributed;
  bool get relationshipAccepted =>
      attributed && friendshipId != null && relationship == 'accepted';

  factory CommunityInviteAcceptance.fromJson(Map<String, dynamic> json) {
    final status = CommunityInviteAcceptStatus.fromWire(json['status']);
    final duplicate = json['duplicate'];
    if (duplicate != null && duplicate is! bool) {
      throw const FormatException('Invalid Community invite duplicate flag');
    }
    if (status != CommunityInviteAcceptStatus.attributed) {
      return CommunityInviteAcceptance(
        status: status,
        duplicate: duplicate as bool? ?? false,
      );
    }

    final attributionId = json['attribution_id'];
    final inviterId = json['inviter_id'];
    final displayName = json['display_name'];
    final avatarUrl = json['avatar_url'];
    final handle = json['handle'];
    final friendshipId = json['friendship_id'];
    final relationship = json['relationship'];
    final newAccountEligible = json['new_account_eligible'];

    if (attributionId is! String ||
        !uuidPattern.hasMatch(attributionId) ||
        inviterId is! String ||
        !uuidPattern.hasMatch(inviterId) ||
        (displayName != null && displayName is! String) ||
        (avatarUrl != null && avatarUrl is! String) ||
        (handle != null && handle is! String) ||
        friendshipId is! String ||
        !uuidPattern.hasMatch(friendshipId) ||
        relationship != 'accepted' ||
        (newAccountEligible != null && newAccountEligible is! bool)) {
      throw const FormatException('Invalid Community invite acceptance');
    }

    return CommunityInviteAcceptance(
      status: status,
      duplicate: duplicate as bool? ?? false,
      attributionId: attributionId,
      inviterId: inviterId,
      displayName: displayName as String?,
      avatarUrl: avatarUrl as String?,
      handle: handle as String?,
      friendshipId: friendshipId,
      relationship: relationship as String,
      newAccountEligible: newAccountEligible as bool?,
    );
  }
}

class CommunityReferralAttribution {
  const CommunityReferralAttribution({
    required this.attributionId,
    required this.inviterId,
    required this.displayName,
    required this.relationshipQualified,
    required this.integrityState,
    required this.rewardRecorded,
    required this.attributedAt,
    this.avatarUrl,
    this.handle,
  });

  final String attributionId;
  final String inviterId;
  final String displayName;
  final String? avatarUrl;
  final String? handle;
  final bool relationshipQualified;
  final String integrityState;
  final bool rewardRecorded;
  final DateTime attributedAt;

  factory CommunityReferralAttribution.fromJson(Map<String, dynamic> json) {
    final attributionId = json['attribution_id'];
    final inviterId = json['inviter_id'];
    final displayName = json['display_name'];
    final avatarUrl = json['avatar_url'];
    final handle = json['handle'];
    final relationshipQualified = json['relationship_qualified'];
    final integrityState = json['integrity_state'];
    final rewardRecorded = json['reward_recorded'];
    final attributedAt = DateTime.tryParse(
      json['attributed_at']?.toString() ?? '',
    );

    if (attributionId is! String ||
        !CommunityInviteAcceptance.uuidPattern.hasMatch(attributionId) ||
        inviterId is! String ||
        !CommunityInviteAcceptance.uuidPattern.hasMatch(inviterId) ||
        displayName is! String ||
        displayName.trim().isEmpty ||
        (avatarUrl != null && avatarUrl is! String) ||
        (handle != null && handle is! String) ||
        relationshipQualified is! bool ||
        integrityState is! String ||
        !const {'pending', 'verified', 'rejected'}.contains(integrityState) ||
        rewardRecorded is! bool ||
        attributedAt == null) {
      throw const FormatException('Invalid Community referral attribution');
    }

    return CommunityReferralAttribution(
      attributionId: attributionId,
      inviterId: inviterId,
      displayName: displayName,
      avatarUrl: avatarUrl as String?,
      handle: handle as String?,
      relationshipQualified: relationshipQualified,
      integrityState: integrityState,
      rewardRecorded: rewardRecorded,
      attributedAt: attributedAt,
    );
  }
}
