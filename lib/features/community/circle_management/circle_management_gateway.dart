import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/community_repository.dart';
import '../domain/community_circles.dart';
import '../services/community_owner_operation.dart';
import '../services/community_post_image_picker.dart';
import 'circle_management_models.dart';
import 'circle_management_transport.dart';
part 'circle_management_gateway_media.dart';

abstract class CircleManagementGateway extends ChangeNotifier
    implements CircleMembershipReader {
  String get ownerId;
  String? get circleSlug;
  bool get isCurrent;
  Future<T> runForAttempt<T>({
    required bool Function() isCurrentAttempt,
    required Future<T> Function() action,
  });

  Future<CircleCapabilities> loadCapabilities({String? circleSlug});
  Future<ManagedCommunityCircle?> readCircle(String slug);
  Future<ManagedCommunityCircle> hydrateCircle(ManagedCommunityCircle circle);
  Future<CircleSearchPage> search({
    required String query,
    bool mine = false,
    String? afterSlug,
    int limit = 30,
  });
  Future<CircleInvitePage> loadInvites({
    String? circleSlug,
    String? afterId,
    int limit = 30,
  });
  Future<CircleInvitation?> readInvite(String inviteId);
  Future<CircleMutationReceipt> create({
    required String requestId,
    required CircleDraft draft,
  });
  Future<CircleMutationReceipt> sendInvite({
    required String requestId,
    required String circleSlug,
    required String recipientCode,
  });
  Future<CircleMutationReceipt> actOnInvite({
    required String requestId,
    required CircleInvitation invite,
    required CircleInviteAction action,
  });
  Future<CircleMutationReceipt?> readOperation(String requestId);
  Future<CircleMutationReceipt> prepareMedia({
    required String requestId,
    required String circleSlug,
    required CircleMediaKind kind,
    required CommunityPostImageDraft image,
  });
  Future<void> uploadMedia(
    CircleMediaReservation reservation,
    CommunityPostImageDraft image,
  );
  Future<CircleMutationReceipt> finishMedia({
    required String requestId,
    required CircleMediaReservation reservation,
  });
  Future<CircleMutationReceipt> cancelMedia({
    required String requestId,
    required CircleMediaReservation reservation,
  });
  Future<void> removeCancelledMedia(CircleMediaReservation reservation);
}

/// One instance represents one owner/session/repository/circle visit. It can
/// never become current again after any identity change, including A -> B -> A.
class RepositoryCircleManagementGateway extends CircleManagementGateway {
  static final Object _attemptKey = Object();
  RepositoryCircleManagementGateway({
    required CommunityRepository repository,
    required bool Function() isCurrentVisit,
    String? circleSlug,
    Listenable? ownerChanges,
  }) : this.withTransport(
         transport: RepositoryCircleManagementTransport(repository),
         isCurrentVisit: isCurrentVisit,
         circleSlug: circleSlug,
         ownerChanges: ownerChanges,
       );

  @visibleForTesting
  RepositoryCircleManagementGateway.withTransport({
    required CircleManagementTransport transport,
    required this.isCurrentVisit,
    this.circleSlug,
    Listenable? ownerChanges,
  }) : _transport = transport,
       _parentChanges = ownerChanges,
       _repositoryIdentity = transport.repositoryIdentity,
       _owner = transport.owner {
    if (circleSlug != null) circleValidateSlug(circleSlug!);
    var delivered = _owner;
    _auth = transport.ownerEvents.listen((next) {
      final changed = !delivered.sameAs(next);
      delivered = next;
      if (changed || !isCurrent) _invalidate();
    }, onError: (Object _, StackTrace _) => _invalidate());
    _parentChanges?.addListener(_parentChanged);
  }

  final CircleManagementTransport _transport;
  final bool Function() isCurrentVisit;
  final Listenable? _parentChanges;
  final Object _repositoryIdentity;
  final CircleOwnerIdentity _owner;
  StreamSubscription<CircleOwnerIdentity>? _auth;
  bool _cancelled = false;
  bool _disposed = false;

  @override
  final String? circleSlug;

  @override
  String get ownerId => _owner.ownerId ?? '';

  @override
  bool get isCurrent =>
      !_cancelled &&
      !_disposed &&
      _owner.ownerId != null &&
      identical(_repositoryIdentity, _transport.repositoryIdentity) &&
      _owner.sameAs(_transport.owner) &&
      isCurrentVisit();

  void _parentChanged() {
    if (!isCurrent) _invalidate();
  }

  void _invalidate() {
    if (_cancelled || _disposed) return;
    _cancelled = true;
    unawaited(_auth?.cancel());
    _auth = null;
    // A parent can be replaced during build. Checks fence synchronously; UI
    // notifications follow in a microtask, like the existing circle owner scope.
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  void _check([String? target]) {
    if ((Zone.current[_attemptKey] as bool Function()?)?.call() == false) {
      throw const CommunityOwnerOperationCancelled();
    }
    if (!isCurrent ||
        (target != null && circleSlug != null && target != circleSlug)) {
      _invalidate();
      throw const CommunityOwnerOperationCancelled();
    }
  }

  @override
  Future<T> runForAttempt<T>({
    required bool Function() isCurrentAttempt,
    required Future<T> Function() action,
  }) {
    _check();
    final parent = Zone.current[_attemptKey] as bool Function()?;
    var cancelled = false;
    bool current() {
      if (cancelled) return false;
      if (!isCurrent || !isCurrentAttempt() || parent?.call() == false) {
        cancelled = true;
        return false;
      }
      return true;
    }

    return runZoned(
      () => _transport.runForOwner(
        ownerId: ownerId,
        isCurrentOwner: current,
        action: () async {
          if (!current()) throw const CommunityOwnerOperationCancelled();
          final value = await action();
          if (!current()) throw const CommunityOwnerOperationCancelled();
          return value;
        },
      ),
      zoneValues: {_attemptKey: current},
    );
  }

  Future<T> _run<T>(Future<T> Function() action, {String? target}) {
    _check(target);
    return _transport.runForOwner(
      ownerId: ownerId,
      isCurrentOwner: () => isCurrent,
      action: () async {
        _check(target);
        final value = await action();
        _check(target);
        return value;
      },
    );
  }

  Future<Object?> _rpc(String name, Map<String, dynamic> params) async {
    _check();
    final value = await _transport.rpc(name, params);
    _check();
    return value;
  }

  Map<String, dynamic> _ownedMap(Object? value) {
    final json = circleMap(value);
    if (json['owner_id'] != ownerId) {
      throw const FormatException('Circle response owner mismatch');
    }
    return json;
  }

  @override
  Future<CircleCapabilities> loadCapabilities({String? circleSlug}) {
    final slug = circleSlug ?? this.circleSlug;
    if (slug != null) circleValidateSlug(slug);
    return _run(() async {
      try {
        final response = await _rpc('bil_circle_capabilities_v1', {
          'p_slug': slug,
        });
        final capabilities = CircleCapabilities.fromJson(_ownedMap(response));
        if (capabilities.circleSlug != slug ||
            (!capabilities.available &&
                (capabilities.canCreate ||
                    capabilities.canSearch ||
                    capabilities.canReadInvites ||
                    capabilities.canInvite ||
                    capabilities.canManageMedia)) ||
            ((capabilities.canInvite || capabilities.canManageMedia) &&
                (!capabilities.isMember ||
                    capabilities.role !=
                        CommunityCircleMembershipRole.moderator ||
                    slug == null))) {
          throw const FormatException('Invalid circle capability scope');
        }
        return capabilities;
      } on PostgrestException catch (error) {
        if (error.code == 'PGRST202' &&
            error.message.contains('bil_circle_capabilities_v1')) {
          return CircleCapabilities.unavailable(
            ownerId: ownerId,
            circleSlug: slug,
          );
        }
        rethrow;
      }
    }, target: slug);
  }

  @override
  Future<CircleMembershipPermission> readMembership(String circleSlug) async {
    final capabilities = await loadCapabilities(circleSlug: circleSlug);
    if (!capabilities.available) throw const CircleManagementUnavailable();
    return CircleMembershipPermission(
      ownerId: ownerId,
      circleSlug: circleSlug,
      isMember: capabilities.isMember,
      canInvite: capabilities.canInvite,
      canManageMedia: capabilities.canManageMedia,
      role: capabilities.role,
    );
  }

  @override
  Future<ManagedCommunityCircle?> readCircle(String slug) {
    circleValidateSlug(slug);
    return _run(() async {
      try {
        final json = _ownedMap(
          await _rpc('bil_circle_read_v1', {'p_slug': slug}),
        );
        if (json['circle'] == null) return null;
        final circle = ManagedCommunityCircle.fromJson(
          circleMap(json['circle']),
        );
        if (circle.slug != slug) {
          throw const FormatException('Circle target mismatch');
        }
        return _hydrateCircle(circle);
      } on PostgrestException catch (error) {
        if (error.code == 'PGRST202' &&
            error.message.contains('bil_circle_read_v1')) {
          throw const CircleManagementUnavailable();
        }
        rethrow;
      }
    }, target: slug);
  }

  @override
  Future<ManagedCommunityCircle> hydrateCircle(ManagedCommunityCircle circle) =>
      _run(() => _hydrateCircle(circle), target: circle.slug);

  @override
  Future<CircleSearchPage> search({
    required String query,
    bool mine = false,
    String? afterSlug,
    int limit = 30,
  }) {
    final normalized = circleText(query.trim(), maximum: 100);
    if (afterSlug != null) circleValidateSlug(afterSlug);
    _validateLimit(limit);
    return _run(() async {
      final response = _ownedMap(
        await _rpc('bil_circle_search_v1', {
          'p_query': normalized,
          'p_mine': mine,
          'p_after_slug': afterSlug,
          'p_limit': limit,
        }),
      );
      final raw = response['circles'];
      if (raw is! List ||
          raw.length > limit ||
          response['query'] != normalized ||
          response['mine'] != mine) {
        throw const FormatException('Invalid circle search page');
      }
      final rows = raw
          .map((row) => ManagedCommunityCircle.fromJson(circleMap(row)))
          .toList();
      final next = circleNullableString(
        response['next_after_slug'],
        maximum: 48,
      );
      _validatePage(rows.map((row) => row.slug).toList(), afterSlug, next);
      if (mine && rows.any((row) => !row.activeMember && !row.pending)) {
        throw const FormatException('Invalid owned circle search page');
      }
      // The server enforces privacy for every page. Do not widen a failed
      // search by falling back to raw table reads or unfiltered cached rows.
      // A valid pending invitation can authorize a private-circle preview
      // before membership. Do not turn that read into an implicit acceptance.
      final hydrated = <ManagedCommunityCircle>[];
      for (final row in rows) {
        hydrated.add(await _hydrateCircle(row));
        _check();
      }
      return CircleSearchPage(
        circles: List.unmodifiable(hydrated),
        nextAfterSlug: next,
      );
    });
  }

  @override
  Future<CircleInvitePage> loadInvites({
    String? circleSlug,
    String? afterId,
    int limit = 30,
  }) {
    final slug = circleSlug ?? this.circleSlug;
    if (slug != null) circleValidateSlug(slug);
    if (afterId != null) circleUuid(afterId);
    _validateLimit(limit);
    return _run(() async {
      final response = _ownedMap(
        await _rpc('bil_circle_invites_v1', {
          'p_slug': slug,
          'p_after_id': afterId,
          'p_limit': limit,
        }),
      );
      final raw = response['invites'];
      if (raw is! List || raw.length > limit) {
        throw const FormatException('Invalid circle invitation page');
      }
      final rows = raw
          .map((row) => CircleInvitation.fromJson(circleMap(row)))
          .toList();
      final next = response['next_after_id'] == null
          ? null
          : circleUuid(response['next_after_id']);
      _validatePage(rows.map((row) => row.id).toList(), afterId, next);
      if (slug != null && rows.any((row) => row.circleSlug != slug)) {
        throw const FormatException('Circle invitation scope mismatch');
      }
      return CircleInvitePage(
        invites: List.unmodifiable(rows),
        nextAfterId: next,
      );
    }, target: slug);
  }

  @override
  Future<CircleInvitation?> readInvite(String inviteId) {
    circleUuid(inviteId);
    return _run(() async {
      final json = _ownedMap(
        await _rpc('bil_circle_invite_v1', {'p_invite_id': inviteId}),
      );
      if (json['invite'] == null) return null;
      final invite = CircleInvitation.fromJson(circleMap(json['invite']));
      if (invite.id != inviteId) {
        throw const FormatException('Circle invite identity mismatch');
      }
      _check(invite.circleSlug);
      return invite;
    });
  }

  @override
  Future<CircleMutationReceipt> create({
    required String requestId,
    required CircleDraft draft,
  }) {
    circleUuid(requestId);
    final params = draft.toRpc();
    return _run(() async {
      final capabilities = await loadCapabilities();
      if (!capabilities.available) throw const CircleManagementUnavailable();
      if (!capabilities.canCreate) throw const CirclePermissionDenied();
      return _mutation('bil_circle_create_v1', requestId, 'create', {
        'p_request_id': requestId,
        ...params,
      });
    });
  }

  @override
  Future<CircleMutationReceipt> sendInvite({
    required String requestId,
    required String circleSlug,
    required String recipientCode,
  }) {
    circleUuid(requestId);
    circleValidateSlug(circleSlug);
    final code = circleRecipientCode(recipientCode);
    return _run(() async {
      final capabilities = await loadCapabilities(circleSlug: circleSlug);
      if (!capabilities.available) throw const CircleManagementUnavailable();
      if (!capabilities.canInvite) throw const CirclePermissionDenied();
      return _mutation('bil_circle_invite_send_v1', requestId, 'invite_send', {
        'p_request_id': requestId,
        'p_slug': circleSlug,
        'p_invitee_code': code,
      }, target: circleSlug);
    }, target: circleSlug);
  }

  @override
  Future<CircleMutationReceipt> actOnInvite({
    required String requestId,
    required CircleInvitation invite,
    required CircleInviteAction action,
  }) {
    circleUuid(requestId);
    return _run(() async {
      final fresh = await readInvite(invite.id);
      if (fresh == null ||
          fresh.circleSlug != invite.circleSlug ||
          !fresh.permits(action, ownerId)) {
        throw const CirclePermissionDenied();
      }
      if (action == CircleInviteAction.cancel) {
        final capabilities = await loadCapabilities(
          circleSlug: invite.circleSlug,
        );
        if (!capabilities.canInvite) throw const CirclePermissionDenied();
      }
      return _mutation(
        'bil_circle_invite_action_v1',
        requestId,
        'invite_${action.name}',
        {
          'p_request_id': requestId,
          'p_invite_id': invite.id,
          'p_action': action.name,
        },
        target: invite.circleSlug,
      );
    }, target: invite.circleSlug);
  }

  @override
  Future<CircleMutationReceipt?> readOperation(String requestId) {
    circleUuid(requestId);
    return _run(() async {
      final value = await _rpc('bil_circle_operation_v1', {
        'p_request_id': requestId,
      });
      if (value == null) return null;
      final receipt = CircleMutationReceipt.fromJson(_ownedMap(value));
      if (receipt.requestId != requestId) {
        throw const FormatException('Circle request identity mismatch');
      }
      _check(receipt.circleSlug);
      return _hydrateReceipt(receipt);
    });
  }

  Future<CircleMutationReceipt> _mutation(
    String rpc,
    String requestId,
    String operation,
    Map<String, dynamic> params, {
    String? target,
  }) async {
    _check(target);
    final receipt = CircleMutationReceipt.fromJson(
      _ownedMap(await _rpc(rpc, params)),
    );
    if (receipt.requestId != requestId ||
        receipt.operation != operation ||
        (target != null && receipt.circleSlug != target)) {
      throw const FormatException('Circle mutation identity mismatch');
    }
    return receipt;
  }

  @override
  Future<CircleMutationReceipt> prepareMedia({
    required String requestId,
    required String circleSlug,
    required CircleMediaKind kind,
    required CommunityPostImageDraft image,
  }) {
    circleUuid(requestId);
    circleValidateSlug(circleSlug);
    return _run(() async {
      final actual = await validateCommunityPostImageAsync(
        Uint8List.fromList(image.bytes),
      );
      _check(circleSlug);
      _checkImageMetadata(image, actual);
      final capabilities = await loadCapabilities(circleSlug: circleSlug);
      if (!capabilities.canManageMedia) throw const CirclePermissionDenied();
      return _mutation(
        'bil_circle_media_prepare_v1',
        requestId,
        'media_prepare',
        {
          'p_request_id': requestId,
          'p_slug': circleSlug,
          'p_slot': kind.name,
          'p_mime_type': actual.mimeType,
          'p_bytes': actual.byteLength,
          'p_width': actual.width,
          'p_height': actual.height,
        },
        target: circleSlug,
      );
    }, target: circleSlug);
  }

  @override
  Future<void> uploadMedia(
    CircleMediaReservation reservation,
    CommunityPostImageDraft image,
  ) => _run(() async {
    _checkReservation(reservation);
    if (reservation.status != 'reserved') throw const CirclePermissionDenied();
    final actual = await validateCommunityPostImageAsync(
      Uint8List.fromList(image.bytes),
    );
    _check(reservation.circleSlug);
    _checkImageMetadata(image, actual);
    final media = reservation.media;
    if (actual.mimeType != media.mimeType ||
        actual.byteLength != media.byteLength ||
        actual.width != media.width ||
        actual.height != media.height ||
        !media.objectPath.endsWith('.${actual.extension}')) {
      throw const FormatException('Circle upload does not match reservation');
    }
    final capabilities = await loadCapabilities(
      circleSlug: reservation.circleSlug,
    );
    if (!capabilities.canManageMedia) throw const CirclePermissionDenied();
    _check(reservation.circleSlug);
    await _transport.upload(media, actual.bytes);
    _check(reservation.circleSlug);
  }, target: reservation.circleSlug);

  @override
  Future<CircleMutationReceipt> finishMedia({
    required String requestId,
    required CircleMediaReservation reservation,
  }) => _run(() async {
    circleUuid(requestId);
    _checkReservation(reservation);
    final capabilities = await loadCapabilities(
      circleSlug: reservation.circleSlug,
    );
    if (!capabilities.canManageMedia) throw const CirclePermissionDenied();
    return _mutation(
      'bil_circle_media_finish_v1',
      requestId,
      'media_finish',
      {'p_request_id': requestId, 'p_media_id': reservation.id},
      target: reservation.circleSlug,
    );
  }, target: reservation.circleSlug);

  @override
  Future<CircleMutationReceipt> cancelMedia({
    required String requestId,
    required CircleMediaReservation reservation,
  }) => _run(() async {
    circleUuid(requestId);
    _checkReservation(reservation);
    // Reservation owners can explicitly discard their own unpublished upload
    // even if their manager permission was revoked in the meantime.
    return _mutation(
      'bil_circle_media_cancel_v1',
      requestId,
      'media_cancel',
      {'p_request_id': requestId, 'p_media_id': reservation.id},
      target: reservation.circleSlug,
    );
  }, target: reservation.circleSlug);

  @override
  Future<void> removeCancelledMedia(CircleMediaReservation reservation) =>
      _run(() async {
        _checkReservation(reservation);
        if (reservation.status != 'cancelled') {
          throw const CirclePermissionDenied();
        }
        await _transport.remove(reservation.media);
      }, target: reservation.circleSlug);

  void _checkReservation(CircleMediaReservation reservation) {
    circleUuid(reservation.id);
    circleValidateSlug(reservation.circleSlug);
    final expected =
        '$ownerId/${reservation.circleSlug}/${reservation.kind.name}/${reservation.id}.';
    if (reservation.media.bucket != circleMediaBucket ||
        reservation.ownerId != ownerId ||
        !reservation.media.objectPath.startsWith(expected) ||
        !circleMediaPathPattern.hasMatch(reservation.media.objectPath)) {
      throw const FormatException('Circle upload owner or target mismatch');
    }
  }

  void _checkImageMetadata(
    CommunityPostImageDraft supplied,
    CommunityPostImageDraft actual,
  ) {
    if (supplied.mimeType != actual.mimeType ||
        supplied.extension != actual.extension ||
        supplied.width != actual.width ||
        supplied.height != actual.height ||
        supplied.byteLength != actual.byteLength) {
      throw const FormatException('Unverified circle image metadata');
    }
  }

  static void _validateLimit(int limit) {
    if (limit < 1 || limit > 60) throw ArgumentError.value(limit, 'limit');
  }

  static void _validatePage(List<String> ids, String? after, String? next) {
    String? previous = after;
    for (final id in ids) {
      if (previous != null && id.compareTo(previous) <= 0) {
        throw const FormatException('Circle pagination did not advance');
      }
      previous = id;
    }
    if (next != null && (ids.isEmpty || next != ids.last)) {
      throw const FormatException('Invalid circle pagination cursor');
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelled = true;
    unawaited(_auth?.cancel());
    _auth = null;
    _parentChanges?.removeListener(_parentChanged);
    super.dispose();
  }
}
