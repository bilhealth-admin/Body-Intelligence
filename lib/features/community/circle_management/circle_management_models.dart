import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/community_circles.dart';
import '../domain/community_models.dart';

const circleMediaBucket = 'community-circle-media';
const circleNativeTitleCopyKey = 'community_circle_custom_title';

enum CircleInviteStatus { pending, accepted, declined, cancelled, expired }

enum CircleInviteAction { accept, decline, cancel }

enum CircleMediaKind { avatar, cover }

enum CircleMutationPhase {
  submitting,
  readingBack,
  succeeded,
  failed,
  readbackRequired,
  awaitingUpload,
  cancelled,
}

/// Presentation affordances come from this owner-bound server response. An
/// unavailable RPC or a failed read never grants a capability optimistically.
class CircleCapabilities {
  const CircleCapabilities({
    required this.ownerId,
    required this.available,
    required this.canCreate,
    required this.canSearch,
    required this.canReadInvites,
    required this.canInvite,
    required this.canManageMedia,
    required this.isMember,
    this.circleSlug,
    this.role,
  });

  const CircleCapabilities.unavailable({required this.ownerId, this.circleSlug})
    : available = false,
      canCreate = false,
      canSearch = false,
      canReadInvites = false,
      canInvite = false,
      canManageMedia = false,
      isMember = false,
      role = null;

  final String ownerId;
  final String? circleSlug;
  final bool available;
  final bool canCreate;
  final bool canSearch;
  final bool canReadInvites;
  final bool canInvite;
  final bool canManageMedia;
  final bool isMember;
  final CommunityCircleMembershipRole? role;

  factory CircleCapabilities.fromJson(Map<String, dynamic> json) {
    final slug = circleNullableString(json['circle_slug'], maximum: 48);
    if (slug != null) circleValidateSlug(slug);
    return CircleCapabilities(
      ownerId: circleUuid(json['owner_id']),
      circleSlug: slug,
      available: circleBool(json['available']),
      canCreate: circleBool(json['can_create']),
      canSearch: circleBool(json['can_search']),
      canReadInvites: circleBool(json['can_read_invites']),
      canInvite: circleBool(json['can_invite']),
      canManageMedia: circleBool(json['can_manage_media']),
      isMember: circleBool(json['is_member']),
      role: circleNullableEnum(
        json['role'],
        CommunityCircleMembershipRole.values,
      ),
    );
  }
}

/// This small read contract is sufficient for BIL-07. It neither subscribes to
/// another person nor authorizes any future mutation on its own.
class CircleMembershipPermission {
  const CircleMembershipPermission({
    required this.ownerId,
    required this.circleSlug,
    required this.isMember,
    required this.canInvite,
    required this.canManageMedia,
    this.role,
  });

  final String ownerId;
  final String circleSlug;
  final bool isMember;
  final bool canInvite;
  final bool canManageMedia;
  final CommunityCircleMembershipRole? role;
}

abstract interface class CircleMembershipReader {
  Future<CircleMembershipPermission> readMembership(String circleSlug);
}

class CircleDraft {
  const CircleDraft({
    required this.displayName,
    required this.description,
    required this.rules,
    required this.access,
    required this.joinPolicy,
  });

  final String displayName;
  final String description;
  final String rules;
  final CommunityCircleAccess access;
  final CommunityCircleJoinPolicy joinPolicy;

  void validate() {
    circleText(displayName.trim(), maximum: 80, allowEmpty: false);
    if (displayName.trim().runes.length < 2 ||
        RegExp(r'[\r\n\t]').hasMatch(displayName)) {
      throw ArgumentError('Invalid circle name');
    }
    circleText(description.trim(), maximum: 1000);
    circleText(rules.trim(), maximum: 2000);
    if (access == CommunityCircleAccess.private &&
        joinPolicy == CommunityCircleJoinPolicy.open) {
      throw ArgumentError('Private circles require requests or invitations');
    }
  }

  Map<String, dynamic> toRpc() {
    validate();
    return {
      'p_display_name': displayName.trim(),
      'p_description': description.trim(),
      'p_rules': rules.trim(),
      'p_access': access.name,
      'p_join_policy': joinPolicy.name,
    };
  }
}

/// A reference is data, not proof the image can currently be downloaded. Only
/// the storage adapter can attach a short-lived, authorized signed URL.
class CircleMediaReference {
  const CircleMediaReference({
    required this.bucket,
    required this.objectPath,
    required this.mimeType,
    required this.byteLength,
    required this.width,
    required this.height,
    this.signedUrl,
  });

  final String bucket;
  final String objectPath;
  final String mimeType;
  final int byteLength;
  final int width;
  final int height;
  final String? signedUrl;

  CircleMediaReference withSignedUrl(String? value) => CircleMediaReference(
    bucket: bucket,
    objectPath: objectPath,
    mimeType: mimeType,
    byteLength: byteLength,
    width: width,
    height: height,
    signedUrl: value,
  );

  factory CircleMediaReference.fromJson(Map<String, dynamic> json) {
    final bucket = json['bucket'] ?? circleMediaBucket;
    final path = circleText(
      json['object_path'],
      maximum: 180,
      allowEmpty: false,
    );
    final mime = json['mime_type'];
    if (bucket != circleMediaBucket ||
        !circleMediaPathPattern.hasMatch(path) ||
        !const ['image/jpeg', 'image/png', 'image/webp'].contains(mime)) {
      throw const FormatException('Invalid circle media reference');
    }
    final ownerId = circleUuid(json['owner_id']);
    final id = circleUuid(json['id']);
    final slug = circleText(
      json['circle_slug'],
      maximum: 48,
      allowEmpty: false,
    );
    circleValidateSlug(slug);
    final kind = circleEnum(json['slot'], CircleMediaKind.values);
    final extension = switch (mime) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => throw const FormatException('Invalid circle media MIME'),
    };
    if (path != '$ownerId/$slug/${kind.name}/$id.$extension') {
      throw const FormatException('Circle media ownership mismatch');
    }
    final bytes = circlePositiveInt(json['bytes'], maximum: 5 * 1024 * 1024);
    final width = circlePositiveInt(json['width'], maximum: 8192);
    final height = circlePositiveInt(json['height'], maximum: 8192);
    if (width * height > 40000000) {
      throw const FormatException('Invalid circle media dimensions');
    }
    return CircleMediaReference(
      bucket: circleMediaBucket,
      objectPath: path,
      mimeType: mime as String,
      byteLength: bytes,
      width: width,
      height: height,
    );
  }
}

/// Preserve the BASE circle contract, counts, enums and serialization. Native
/// metadata extends that contract without replacing copy keys for seeded rows.
class ManagedCommunityCircle extends CommunityCircle {
  ManagedCommunityCircle({
    required CommunityCircle circle,
    this.displayName,
    this.description,
    this.rules,
    this.avatar,
    this.cover,
  }) : super(
         slug: circle.slug,
         titleCopyKey: circle.titleCopyKey,
         descriptionCopyKey: circle.descriptionCopyKey,
         rulesCopyKey: circle.rulesCopyKey,
         access: circle.access,
         joinPolicy: circle.joinPolicy,
         featured: circle.featured,
         memberCount: circle.memberCount,
         postCount: circle.postCount,
         membershipStatus: circle.membershipStatus,
         membershipRole: circle.membershipRole,
       );

  final String? displayName;
  final String? description;
  final String? rules;
  final CircleMediaReference? avatar;
  final CircleMediaReference? cover;

  factory ManagedCommunityCircle.fromJson(Map<String, dynamic> json) {
    final circle = CommunityCircle.fromJson(json);
    CircleMediaReference? media(Object? value, CircleMediaKind kind) {
      if (value == null) return null;
      final record = CircleMediaReservation.fromJson(circleMap(value));
      if (record.circleSlug != circle.slug ||
          record.kind != kind ||
          record.status != 'published') {
        throw const FormatException('Unpublished or mismatched circle media');
      }
      return record.media;
    }

    final name = circleNullableString(json['display_name'], maximum: 80);
    if (circle.titleCopyKey == circleNativeTitleCopyKey &&
        (name == null || name.trim().runes.length < 2)) {
      throw const FormatException('Native circle has no verified name');
    }
    return ManagedCommunityCircle(
      circle: circle,
      displayName: name,
      description: circleNullableString(json['description'], maximum: 1000),
      rules: circleNullableString(json['rules'], maximum: 2000),
      avatar: media(json['avatar'], CircleMediaKind.avatar),
      cover: media(json['cover'], CircleMediaKind.cover),
    );
  }

  ManagedCommunityCircle withMedia({
    required CircleMediaReference? avatar,
    required CircleMediaReference? cover,
  }) => ManagedCommunityCircle(
    circle: this,
    displayName: displayName,
    description: description,
    rules: rules,
    avatar: avatar,
    cover: cover,
  );

  ManagedCommunityCircle onBaseCircle(CommunityCircle base) {
    if (base.slug != slug) {
      throw const FormatException('Circle metadata target mismatch');
    }
    return ManagedCommunityCircle(
      circle: base,
      displayName: displayName,
      description: description,
      rules: rules,
      avatar: avatar,
      cover: cover,
    );
  }

  @override
  ManagedCommunityCircle copyWith({
    int? memberCount,
    int? postCount,
    CommunityCircleMembershipStatus? membershipStatus,
    bool clearMembership = false,
  }) => ManagedCommunityCircle(
    circle: super.copyWith(
      memberCount: memberCount,
      postCount: postCount,
      membershipStatus: membershipStatus,
      clearMembership: clearMembership,
    ),
    displayName: displayName,
    description: description,
    rules: rules,
    avatar: avatar,
    cover: cover,
  );
}

class CircleSearchPage {
  const CircleSearchPage({required this.circles, this.nextAfterSlug});

  final List<ManagedCommunityCircle> circles;
  final String? nextAfterSlug;
  bool get hasMore => nextAfterSlug != null;
}

class CircleInvitation {
  const CircleInvitation({
    required this.id,
    required this.circleSlug,
    required this.inviterId,
    required this.inviteeId,
    required this.status,
    required this.canAccept,
    required this.canDecline,
    required this.canCancel,
    this.circleName,
    this.recipientCode,
    this.inviterName,
    this.inviteeName,
  });

  final String id;
  final String circleSlug;
  final String? circleName;
  final String inviterId;
  final String inviteeId;
  final String? recipientCode;
  final String? inviterName;
  final String? inviteeName;
  final CircleInviteStatus status;
  final bool canAccept;
  final bool canDecline;
  final bool canCancel;

  bool permits(CircleInviteAction action, String ownerId) {
    if (status != CircleInviteStatus.pending) return false;
    return switch (action) {
      CircleInviteAction.accept => canAccept && inviteeId == ownerId,
      CircleInviteAction.decline => canDecline && inviteeId == ownerId,
      // A fresh server response supplies canCancel for current managers; a
      // previous inviter who lost management is not privileged by identity.
      CircleInviteAction.cancel => canCancel,
    };
  }

  factory CircleInvitation.fromJson(Map<String, dynamic> json) {
    final slug = circleText(
      json['circle_slug'],
      maximum: 48,
      allowEmpty: false,
    );
    circleValidateSlug(slug);
    final code = circleNullableString(json['recipient_code'], maximum: 32);
    if (code != null && !CommunityPublicCode.codePattern.hasMatch(code)) {
      throw const FormatException('Invalid circle invitation code');
    }
    return CircleInvitation(
      id: circleUuid(json['id']),
      circleSlug: slug,
      circleName: circleNullableString(json['circle_name'], maximum: 80),
      inviterId: circleUuid(json['inviter_id']),
      inviteeId: circleUuid(json['invitee_id']),
      recipientCode: code,
      inviterName: circleNullableString(json['inviter_name'], maximum: 60),
      inviteeName: circleNullableString(json['invitee_name'], maximum: 60),
      status: circleEnum(json['status'], CircleInviteStatus.values),
      canAccept: circleBool(json['can_accept']),
      canDecline: circleBool(json['can_decline']),
      canCancel: circleBool(json['can_cancel']),
    );
  }
}

class CircleInvitePage {
  const CircleInvitePage({required this.invites, this.nextAfterId});

  final List<CircleInvitation> invites;
  final String? nextAfterId;
  bool get hasMore => nextAfterId != null;
}

class CircleMediaReservation {
  const CircleMediaReservation({
    required this.id,
    required this.ownerId,
    required this.circleSlug,
    required this.kind,
    required this.media,
    required this.status,
  });

  final String id;
  final String ownerId;
  final String circleSlug;
  final CircleMediaKind kind;
  final CircleMediaReference media;
  final String status;

  factory CircleMediaReservation.fromJson(Map<String, dynamic> json) {
    final slug = circleText(
      json['circle_slug'],
      maximum: 48,
      allowEmpty: false,
    );
    circleValidateSlug(slug);
    final status = json['status'];
    if (!const [
      'reserved',
      'published',
      'cancelled',
      'superseded',
    ].contains(status)) {
      throw const FormatException('Invalid circle media status');
    }
    return CircleMediaReservation(
      id: circleUuid(json['id']),
      ownerId: circleUuid(json['owner_id']),
      circleSlug: slug,
      kind: circleEnum(json['slot'], CircleMediaKind.values),
      media: CircleMediaReference.fromJson(json),
      status: status as String,
    );
  }
}

class CircleMutationReceipt {
  const CircleMutationReceipt({
    required this.ownerId,
    required this.requestId,
    required this.operation,
    required this.circleSlug,
    this.inviteId,
    this.mediaId,
    this.circle,
    this.invite,
    this.media,
  });

  final String ownerId;
  final String requestId;
  final String operation;
  final String circleSlug;
  final String? inviteId;
  final String? mediaId;
  final ManagedCommunityCircle? circle;
  final CircleInvitation? invite;
  final CircleMediaReservation? media;

  factory CircleMutationReceipt.fromJson(Map<String, dynamic> json) {
    if (json['committed'] != true) {
      throw const FormatException('Uncommitted circle receipt');
    }
    final operation = json['operation'];
    if (!const [
      'create',
      'invite_send',
      'invite_accept',
      'invite_decline',
      'invite_cancel',
      'media_prepare',
      'media_finish',
      'media_cancel',
    ].contains(operation)) {
      throw const FormatException('Invalid circle mutation operation');
    }
    final slug = circleText(
      json['circle_slug'],
      maximum: 48,
      allowEmpty: false,
    );
    circleValidateSlug(slug);
    final inviteId = json['invite_id'] == null
        ? null
        : circleUuid(json['invite_id']);
    final mediaId = json['media_id'] == null
        ? null
        : circleUuid(json['media_id']);
    final circle = json['circle'] == null
        ? null
        : ManagedCommunityCircle.fromJson(circleMap(json['circle']));
    final invite = json['invite'] == null
        ? null
        : CircleInvitation.fromJson(circleMap(json['invite']));
    final media = json['media'] == null
        ? null
        : CircleMediaReservation.fromJson(circleMap(json['media']));
    if ((circle != null && circle.slug != slug) ||
        (invite != null && invite.circleSlug != slug) ||
        (media != null && media.circleSlug != slug) ||
        (invite != null && inviteId != invite.id) ||
        (media != null && mediaId != media.id)) {
      throw const FormatException('Circle mutation identity mismatch');
    }
    return CircleMutationReceipt(
      ownerId: circleUuid(json['owner_id']),
      requestId: circleUuid(json['request_id']),
      operation: operation as String,
      circleSlug: slug,
      inviteId: inviteId,
      mediaId: mediaId,
      circle: circle,
      invite: invite,
      media: media,
    );
  }
}

class CircleOperationKeys {
  static const create = 'create';
  static String inviteSend(String slug, String code) =>
      'invite:send:$slug:${circleOperationDigest(code.trim().toLowerCase())}';
  static String inviteAction(String id) => 'invite:action:$id';
  static String media(String slug, CircleMediaKind kind) =>
      'media:$slug:${kind.name}';
}

class CircleOperationState {
  const CircleOperationState({
    required this.key,
    required this.requestId,
    required this.operation,
    required this.phase,
    this.receipt,
    this.error,
    this.draft,
  });

  final String key;
  final String requestId;
  final String operation;
  final CircleMutationPhase phase;
  final CircleMutationReceipt? receipt;
  final Object? error;
  final CircleDraft? draft;

  bool get busy =>
      phase == CircleMutationPhase.submitting ||
      phase == CircleMutationPhase.readingBack;
  bool get needsReadback => phase == CircleMutationPhase.readbackRequired;
  bool get succeeded => phase == CircleMutationPhase.succeeded;
}

class CirclePermissionDenied implements Exception {
  const CirclePermissionDenied();
}

class CircleManagementUnavailable implements Exception {
  const CircleManagementUnavailable();
}

class CircleReadbackPending implements Exception {
  const CircleReadbackPending();
}

class CircleOperationJournalUnavailable implements Exception {
  const CircleOperationJournalUnavailable([this.cause]);

  final Object? cause;
}

String circleOperationDigest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

String circleOperationBytesDigest(List<int> bytes) =>
    sha256.convert(bytes).toString();

final circleUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final circleMediaPathPattern = RegExp(
  r'^[0-9a-f-]{36}/[a-z0-9-]{1,48}/(?:avatar|cover)/[0-9a-f-]{36}\.(?:jpg|png|webp)$',
);
final _unsafeCircleText = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

Map<String, dynamic> circleMap(Object? value) {
  if (value is! Map) throw const FormatException('Invalid circle response');
  return Map<String, dynamic>.from(value);
}

String circleText(
  Object? value, {
  required int maximum,
  bool allowEmpty = true,
}) {
  if (value is! String ||
      value.runes.length > maximum ||
      (!allowEmpty && value.trim().isEmpty) ||
      _unsafeCircleText.hasMatch(value)) {
    throw const FormatException('Invalid circle text');
  }
  return value;
}

String? circleNullableString(Object? value, {required int maximum}) =>
    value == null ? null : circleText(value, maximum: maximum);

String circleUuid(Object? value) {
  if (value is! String || !circleUuidPattern.hasMatch(value)) {
    throw const FormatException('Invalid circle identifier');
  }
  return value;
}

void circleValidateSlug(String slug) {
  if (slug.length > 48 || !CommunityCircle.slugPattern.hasMatch(slug)) {
    throw ArgumentError.value(slug, 'slug');
  }
}

String circleRecipientCode(String code) {
  final normalized = code.trim().toLowerCase();
  if (!CommunityPublicCode.codePattern.hasMatch(normalized)) {
    throw ArgumentError('Invalid BIL Code');
  }
  return normalized;
}

bool circleBool(Object? value) {
  if (value is! bool) throw const FormatException('Invalid circle capability');
  return value;
}

int circlePositiveInt(Object? value, {required int maximum}) {
  if (value is! num || value < 1 || value > maximum || value % 1 != 0) {
    throw const FormatException('Invalid circle media measurement');
  }
  return value.toInt();
}

T circleEnum<T extends Enum>(Object? value, List<T> values) {
  for (final entry in values) {
    if (entry.name == value) return entry;
  }
  throw const FormatException('Invalid circle enum');
}

T? circleNullableEnum<T extends Enum>(Object? value, List<T> values) =>
    value == null ? null : circleEnum(value, values);
