import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:body_intelligence_log/features/community/circle_management/circle_management.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';

const bil06OwnerA = '11111111-1111-4111-8111-111111111111';
const bil06OwnerB = '22222222-2222-4222-8222-222222222222';
const bil06OwnerC = '33333333-3333-4333-8333-333333333333';
const bil06InviteId = '44444444-4444-4444-8444-444444444444';
const bil06MediaId = '55555555-5555-4555-8555-555555555555';
const bil06RecipientCode = 'abcdef0123456789abcdef0123456789';

CircleCapabilities bil06Capabilities({
  String owner = bil06OwnerA,
  String? slug,
  bool create = true,
  bool manage = true,
}) => CircleCapabilities(
  ownerId: owner,
  circleSlug: slug,
  available: true,
  canCreate: create,
  canSearch: true,
  canReadInvites: true,
  canInvite: manage,
  canManageMedia: manage,
  isMember: manage,
  role: manage ? CommunityCircleMembershipRole.moderator : null,
);

CircleDraft bil06Draft({String name = 'Synthetic circle'}) => CircleDraft(
  displayName: name,
  description: 'Synthetic description for a local test.',
  rules: 'Respect other members.',
  access: CommunityCircleAccess.public,
  joinPolicy: CommunityCircleJoinPolicy.request,
);

ManagedCommunityCircle bil06Circle({
  String slug = 'synthetic-circle',
  String name = 'Synthetic circle',
}) => ManagedCommunityCircle(
  circle: CommunityCircle(
    slug: slug,
    titleCopyKey: circleNativeTitleCopyKey,
    descriptionCopyKey: 'community_circle_custom_description',
    rulesCopyKey: 'community_circle_custom_rules',
    access: CommunityCircleAccess.public,
    joinPolicy: CommunityCircleJoinPolicy.request,
    featured: false,
    memberCount: 1,
    postCount: 0,
    membershipStatus: CommunityCircleMembershipStatus.active,
    membershipRole: CommunityCircleMembershipRole.moderator,
  ),
  displayName: name,
  description: 'Synthetic description for a local test.',
  rules: 'Respect other members.',
);

CircleInvitation bil06Invite({
  String invitee = bil06OwnerA,
  String inviter = bil06OwnerB,
  CircleInviteStatus status = CircleInviteStatus.pending,
  bool canAccept = true,
  bool canDecline = true,
  bool canCancel = false,
  String? inviterName,
  String? inviteeName,
}) => CircleInvitation(
  id: bil06InviteId,
  circleSlug: 'synthetic-circle',
  circleName: 'Synthetic circle',
  inviterId: inviter,
  inviteeId: invitee,
  recipientCode: bil06RecipientCode,
  status: status,
  canAccept: canAccept,
  canDecline: canDecline,
  canCancel: canCancel,
  inviterName: inviterName,
  inviteeName: inviteeName,
);

/// A declared synthetic test double, not a provider or database E2E fixture.
class Bil06FakeGateway extends CircleManagementGateway {
  static final _attemptKey = Object();
  Bil06FakeGateway({this.ownerId = bil06OwnerA, this.circleSlug}) {
    capabilities = bil06Capabilities(owner: ownerId, slug: circleSlug);
  }

  @override
  final String ownerId;
  @override
  final String? circleSlug;
  bool current = true;
  @override
  bool get isCurrent => current;
  @override
  Future<T> runForAttempt<T>({
    required bool Function() isCurrentAttempt,
    required Future<T> Function() action,
  }) {
    final parent = Zone.current[_attemptKey] as bool Function()?;
    bool active() => isCurrentAttempt() && (parent?.call() ?? true);
    return runZoned(() async {
      check();
      if (!active()) throw const CommunityOwnerOperationCancelled();
      final value = await action();
      check();
      if (!active()) throw const CommunityOwnerOperationCancelled();
      return value;
    }, zoneValues: {_attemptKey: active});
  }

  late CircleCapabilities capabilities;
  Object? capabilityFailure;
  Object? readbackFailure;
  Object? uploadFailure;
  int readCircleCalls = 0;
  int createCalls = 0;
  int sendCalls = 0;
  int actionCalls = 0;
  int readbackCalls = 0;
  int prepareCalls = 0;
  int uploadCalls = 0;
  int finishCalls = 0;
  int cancelCalls = 0;
  int removeCalls = 0;
  final List<String> submittedRequestIds = [];
  final Map<String, CircleMutationReceipt> receipts = {};
  List<CircleInvitation> invitationRows = [];
  Future<ManagedCommunityCircle?> Function(String)? onReadCircle;
  Future<CircleMutationReceipt> Function(String, CircleDraft)? onCreate;
  Future<CircleMutationReceipt?> Function(String)? onReadOperation;
  Future<CircleSearchPage> Function(String, bool, String?)? onSearch;
  Future<void> Function()? onUpload;
  Future<CircleMutationReceipt> Function(String, CircleMediaReservation)?
  onFinish;
  Future<CircleMutationReceipt> Function(String, CircleMediaReservation)?
  onCancel;
  CircleMediaReservation? reservation;

  void invalidate() {
    current = false;
    notifyListeners();
  }

  void check() {
    if (!current ||
        (Zone.current[_attemptKey] as bool Function()?)?.call() == false) {
      throw const CommunityOwnerOperationCancelled();
    }
  }

  @override
  Future<CircleCapabilities> loadCapabilities({String? circleSlug}) async {
    check();
    if (capabilityFailure != null) throw capabilityFailure!;
    return capabilities;
  }

  @override
  Future<CircleMembershipPermission> readMembership(String circleSlug) async =>
      CircleMembershipPermission(
        ownerId: ownerId,
        circleSlug: circleSlug,
        isMember: capabilities.isMember,
        canInvite: capabilities.canInvite,
        canManageMedia: capabilities.canManageMedia,
        role: capabilities.role,
      );

  @override
  Future<ManagedCommunityCircle?> readCircle(String slug) async {
    check();
    readCircleCalls++;
    return onReadCircle == null ? bil06Circle(slug: slug) : onReadCircle!(slug);
  }

  @override
  Future<ManagedCommunityCircle> hydrateCircle(
    ManagedCommunityCircle circle,
  ) async => circle;

  @override
  Future<CircleSearchPage> search({
    required String query,
    bool mine = false,
    String? afterSlug,
    int limit = 30,
  }) async {
    check();
    return onSearch == null
        ? CircleSearchPage(circles: [bil06Circle()])
        : onSearch!(query, mine, afterSlug);
  }

  @override
  Future<CircleInvitePage> loadInvites({
    String? circleSlug,
    String? afterId,
    int limit = 30,
  }) async {
    check();
    return CircleInvitePage(invites: List.unmodifiable(invitationRows));
  }

  @override
  Future<CircleInvitation?> readInvite(String inviteId) async {
    for (final row in invitationRows) {
      if (row.id == inviteId) return row;
    }
    return null;
  }

  CircleMutationReceipt save(
    String requestId,
    String operation, {
    CircleInvitation? invite,
    CircleMediaReservation? media,
  }) {
    final receipt = CircleMutationReceipt(
      ownerId: ownerId,
      requestId: requestId,
      operation: operation,
      circleSlug: 'synthetic-circle',
      inviteId: invite?.id,
      mediaId: media?.id,
      circle: bil06Circle(),
      invite: invite,
      media: media,
    );
    receipts[requestId] = receipt;
    return receipt;
  }

  @override
  Future<CircleMutationReceipt> create({
    required String requestId,
    required CircleDraft draft,
  }) async {
    check();
    if (!capabilities.canCreate) throw const CirclePermissionDenied();
    createCalls++;
    submittedRequestIds.add(requestId);
    if (onCreate != null) return onCreate!(requestId, draft);
    return save(requestId, 'create');
  }

  @override
  Future<CircleMutationReceipt> sendInvite({
    required String requestId,
    required String circleSlug,
    required String recipientCode,
  }) async {
    check();
    if (!capabilities.canInvite) throw const CirclePermissionDenied();
    sendCalls++;
    submittedRequestIds.add(requestId);
    final invite = bil06Invite(
      inviter: ownerId,
      invitee: bil06OwnerB,
      canAccept: false,
      canDecline: false,
      canCancel: true,
    );
    invitationRows = [invite];
    return save(requestId, 'invite_send', invite: invite);
  }

  @override
  Future<CircleMutationReceipt> actOnInvite({
    required String requestId,
    required CircleInvitation invite,
    required CircleInviteAction action,
  }) async {
    check();
    if (!invite.permits(action, ownerId)) throw const CirclePermissionDenied();
    actionCalls++;
    submittedRequestIds.add(requestId);
    final updated = bil06Invite(
      invitee: invite.inviteeId,
      inviter: invite.inviterId,
      status: switch (action) {
        CircleInviteAction.accept => CircleInviteStatus.accepted,
        CircleInviteAction.decline => CircleInviteStatus.declined,
        CircleInviteAction.cancel => CircleInviteStatus.cancelled,
      },
      canAccept: false,
      canDecline: false,
    );
    invitationRows = [updated];
    return save(requestId, 'invite_${action.name}', invite: updated);
  }

  @override
  Future<CircleMutationReceipt?> readOperation(String requestId) async {
    check();
    readbackCalls++;
    if (readbackFailure != null) throw readbackFailure!;
    return onReadOperation == null
        ? receipts[requestId]
        : onReadOperation!(requestId);
  }

  @override
  Future<CircleMutationReceipt> prepareMedia({
    required String requestId,
    required String circleSlug,
    required CircleMediaKind kind,
    required CommunityPostImageDraft image,
  }) async {
    check();
    if (!capabilities.canManageMedia) throw const CirclePermissionDenied();
    prepareCalls++;
    reservation = CircleMediaReservation(
      id: bil06MediaId,
      ownerId: ownerId,
      circleSlug: circleSlug,
      kind: kind,
      media: CircleMediaReference(
        bucket: circleMediaBucket,
        objectPath:
            '$ownerId/$circleSlug/${kind.name}/$bil06MediaId.${image.extension}',
        mimeType: image.mimeType,
        byteLength: image.byteLength,
        width: image.width,
        height: image.height,
      ),
      status: 'reserved',
    );
    return save(requestId, 'media_prepare', media: reservation);
  }

  @override
  Future<void> uploadMedia(
    CircleMediaReservation reservation,
    CommunityPostImageDraft image,
  ) async {
    check();
    uploadCalls++;
    if (onUpload != null) await onUpload!();
    if (uploadFailure != null) throw uploadFailure!;
  }

  CircleMediaReservation _withStatus(
    CircleMediaReservation input,
    String status,
  ) => CircleMediaReservation(
    id: input.id,
    ownerId: input.ownerId,
    circleSlug: input.circleSlug,
    kind: input.kind,
    media: input.media,
    status: status,
  );

  @override
  Future<CircleMutationReceipt> finishMedia({
    required String requestId,
    required CircleMediaReservation reservation,
  }) async {
    check();
    finishCalls++;
    if (onFinish != null) return onFinish!(requestId, reservation);
    return save(
      requestId,
      'media_finish',
      media: _withStatus(reservation, 'published'),
    );
  }

  @override
  Future<CircleMutationReceipt> cancelMedia({
    required String requestId,
    required CircleMediaReservation reservation,
  }) async {
    check();
    cancelCalls++;
    if (onCancel != null) return onCancel!(requestId, reservation);
    return save(
      requestId,
      'media_cancel',
      media: _withStatus(reservation, 'cancelled'),
    );
  }

  @override
  Future<void> removeCancelledMedia(CircleMediaReservation reservation) async {
    check();
    removeCalls++;
  }
}

class Bil06MemoryTransport implements CircleManagementTransport {
  static final _guardKey = Object();
  Object identity = Object();
  CircleOwnerIdentity current = const CircleOwnerIdentity(
    bil06OwnerA,
    'session-a',
  );
  final events = StreamController<CircleOwnerIdentity>.broadcast(sync: true);
  final List<({String name, Map<String, dynamic> params})> calls = [];
  Future<Object?> Function(String, Map<String, dynamic>)? handler;
  Future<String> Function(CircleMediaReference)? signHandler;
  int uploadCalls = 0;
  int removeCalls = 0;

  @override
  Object get repositoryIdentity => identity;
  @override
  CircleOwnerIdentity get owner => current;
  @override
  Stream<CircleOwnerIdentity> get ownerEvents => events.stream;

  void changeOwner(CircleOwnerIdentity value) {
    current = value;
    events.add(value);
  }

  @override
  Future<T> runForOwner<T>({
    required String ownerId,
    required bool Function() isCurrentOwner,
    required Future<T> Function() action,
  }) {
    final parent = Zone.current[_guardKey] as bool Function()?;
    bool active() =>
        isCurrentOwner() &&
        current.ownerId == ownerId &&
        (parent?.call() ?? true);
    return runZoned(() async {
      if (!active()) throw const CommunityOwnerOperationCancelled();
      final value = await action();
      if (!active()) throw const CommunityOwnerOperationCancelled();
      return value;
    }, zoneValues: {_guardKey: active});
  }

  @override
  Future<Object?> rpc(String name, Map<String, dynamic> params) async {
    if ((Zone.current[_guardKey] as bool Function()?)?.call() == false) {
      throw const CommunityOwnerOperationCancelled();
    }
    calls.add((name: name, params: Map.of(params)));
    if (handler == null) throw StateError('No synthetic response for $name');
    return handler!(name, params);
  }

  @override
  Future<void> upload(CircleMediaReference media, Uint8List bytes) async {
    uploadCalls++;
  }

  @override
  Future<void> remove(CircleMediaReference media) async {
    removeCalls++;
  }

  @override
  Future<String> sign(CircleMediaReference media) async => signHandler == null
      ? 'https://images.example.test/storage/v1/object/sign/${media.bucket}/${media.objectPath}'
      : signHandler!(media);
}
