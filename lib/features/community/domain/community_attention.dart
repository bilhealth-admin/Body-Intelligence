import 'dart:async';

import 'package:flutter/foundation.dart';

/// An authoritative snapshot. A badge is never incremented from a push payload.
@immutable
class CommunityAttention {
  const CommunityAttention({
    this.unreadMessages = 0,
    this.incomingRequests = 0,
    this.communityUpdates = 0,
    this.unreadBySender = const {},
    this.activityUnseenByKind = const {},
  });

  final int unreadMessages;
  final int incomingRequests;
  final int communityUpdates;
  final Map<String, int> unreadBySender;
  final Map<String, int> activityUnseenByKind;
  int get total => unreadMessages + incomingRequests + communityUpdates;

  factory CommunityAttention.fromJson(Map<String, dynamic> json) {
    int count(Object? value) {
      if (value is! int || value < 0 || value > 2147483647) {
        throw const FormatException('Invalid Community attention count');
      }
      return value;
    }

    final rawSenders = json['unread_by_sender'];
    if (rawSenders is! Map) {
      throw const FormatException('Invalid Community attention snapshot');
    }
    final senders = <String, int>{};
    for (final entry in rawSenders.entries) {
      if (entry.key is! String) {
        throw const FormatException('Invalid Community attention sender');
      }
      senders[entry.key as String] = count(entry.value);
    }
    final rawActivity = json['activity_unseen_by_kind'];
    final activity = <String, int>{};
    if (rawActivity != null) {
      if (rawActivity is! Map) {
        throw const FormatException('Invalid Community activity counts');
      }
      for (final entry in rawActivity.entries) {
        if (entry.key is! String ||
            CommunityNotificationKind.fromWire(entry.key as String) == null) {
          throw const FormatException('Invalid Community activity kind');
        }
        activity[entry.key as String] = count(entry.value);
      }
    }
    final unread = count(json['unread_messages']);
    if (senders.values.fold<int>(0, (sum, value) => sum + value) != unread) {
      throw const FormatException('Inconsistent Community unread totals');
    }
    return CommunityAttention(
      unreadMessages: unread,
      incomingRequests: count(json['incoming_requests']),
      communityUpdates: json['community_updates'] == null
          ? 0
          : count(json['community_updates']),
      unreadBySender: Map.unmodifiable(senders),
      activityUnseenByKind: Map.unmodifiable(activity),
    );
  }

  static String badgeText(int count) => count > 99 ? '99+' : '$count';
}

enum CommunityNotificationKind {
  friendRequest('friend_request'),
  friendAccepted('friend_accepted'),
  postLike('post_like'),
  postSave('post_save'),
  comment('comment'),
  reply('reply'),
  follow('follow'),
  mention('mention'),
  rewardEarned('reward_earned'),
  questCompleted('quest_completed'),
  badgeEarned('badge_earned'),
  challengeUpdate('challenge_update');

  const CommunityNotificationKind(this.wireValue);

  final String wireValue;

  static CommunityNotificationKind? fromWire(String value) {
    for (final kind in values) {
      if (kind.wireValue == value) return kind;
    }
    return null;
  }
}

@immutable
class CommunityNotification {
  const CommunityNotification({
    required this.id,
    required this.kind,
    required this.actorId,
    required this.createdAt,
    required this.entityKind,
    required this.entityId,
    required this.copyKey,
    required this.deepLinkPath,
    this.actorDisplayName,
    this.actorAvatarUrl,
    this.friendshipId,
    this.metadata = const <String, dynamic>{},
    this.seenAt,
  });

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _entityKind = RegExp(r'^[a-z][a-z0-9_]{2,47}$');
  static final RegExp _copyKey = RegExp(r'^[a-z][a-z0-9_]{2,63}$');
  static final RegExp _communityPath = RegExp(
    r'^/community(?:/[A-Za-z0-9._~-]+)*$',
  );

  final String id;
  final CommunityNotificationKind kind;
  final String? actorId;
  final String? actorDisplayName;
  final String? actorAvatarUrl;
  final String? friendshipId;
  final String entityKind;
  final String entityId;
  final String copyKey;
  final String deepLinkPath;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? seenAt;

  bool get seen => seenAt != null;

  factory CommunityNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final rawKind = json['kind'];
    final kind = rawKind is String
        ? CommunityNotificationKind.fromWire(rawKind)
        : null;
    final actorId = json['actor_id'];
    final actorDisplayName = json['actor_display_name'];
    final actorAvatarUrl = json['actor_avatar_url'];
    final friendshipId = json['friendship_id'];
    final rawEntityKind = json['entity_kind'];
    final rawEntityId = json['entity_id'];
    final rawCopyKey = json['copy_key'];
    final rawDeepLinkPath = json['deep_link_path'];
    final rawMetadata = json['metadata'];
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final rawSeenAt = json['seen_at'];
    final seenAt = rawSeenAt == null
        ? null
        : DateTime.tryParse(rawSeenAt.toString());

    final legacyFriendAccepted =
        kind == CommunityNotificationKind.friendAccepted &&
        friendshipId is String &&
        _uuid.hasMatch(friendshipId);
    final entityKind =
        rawEntityKind ?? (legacyFriendAccepted ? 'friendship' : null);
    final entityId =
        rawEntityId ?? (legacyFriendAccepted ? friendshipId : null);
    final copyKey =
        rawCopyKey ?? (legacyFriendAccepted ? 'friend_accepted_v1' : null);
    final deepLinkPath =
        rawDeepLinkPath ??
        (legacyFriendAccepted ? '/community/notifications' : null);
    final metadata = rawMetadata ?? const <String, dynamic>{};

    if (id is! String ||
        !_uuid.hasMatch(id) ||
        kind == null ||
        (actorId != null && (actorId is! String || !_uuid.hasMatch(actorId))) ||
        (actorDisplayName != null &&
            (actorDisplayName is! String ||
                actorDisplayName.trim().isEmpty ||
                actorDisplayName.length > 60)) ||
        (actorAvatarUrl != null && actorAvatarUrl is! String) ||
        (friendshipId != null &&
            (friendshipId is! String || !_uuid.hasMatch(friendshipId))) ||
        entityKind is! String ||
        !_entityKind.hasMatch(entityKind) ||
        entityId is! String ||
        entityId.isEmpty ||
        entityId.length > 160 ||
        copyKey is! String ||
        !_copyKey.hasMatch(copyKey) ||
        deepLinkPath is! String ||
        !_communityPath.hasMatch(deepLinkPath) ||
        metadata is! Map ||
        metadata.keys.any((key) => key is! String) ||
        createdAt == null ||
        (rawSeenAt != null && seenAt == null)) {
      throw const FormatException('Invalid Community notification');
    }

    return CommunityNotification(
      id: id,
      kind: kind,
      actorId: actorId as String?,
      actorDisplayName: actorDisplayName as String?,
      actorAvatarUrl: actorAvatarUrl as String?,
      friendshipId: friendshipId as String?,
      entityKind: entityKind,
      entityId: entityId,
      copyKey: copyKey,
      deepLinkPath: deepLinkPath,
      metadata: Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(metadata),
      ),
      createdAt: createdAt,
      seenAt: seenAt,
    );
  }
}

/// Serializes reloads, discards old-owner responses and preserves last known
/// counts during transient network errors. No notification permission is needed
/// for in-app unread indicators.
class CommunityAttentionController extends ChangeNotifier {
  CommunityAttentionController(this.loader);
  final Future<CommunityAttention> Function() loader;
  CommunityAttention _value = const CommunityAttention();
  CommunityAttention get value => _value;
  String? _owner;
  String? get owner => _owner;
  int _generation = 0;
  bool _disposed = false;
  Future<void>? _running;
  bool _queued = false;
  bool _stale = false;
  bool get stale => _stale;
  bool _hasSnapshot = false;
  bool get hasSnapshot => _hasSnapshot;

  void setOwner(String? owner) {
    if (_disposed || _owner == owner) return;
    _owner = owner;
    _generation++;
    _value = const CommunityAttention();
    _hasSnapshot = false;
    _stale = false;
    _queued = false;
    // An old account's pending Future does not block a new account's reload.
    _running = null;
    notifyListeners();
    if (owner != null) unawaited(refresh());
  }

  Future<void> refresh() {
    if (_disposed || _owner == null) return Future.value();
    if (_running != null) {
      _queued = true;
      return _running!;
    }
    final generation = _generation;
    final completer = Completer<void>();
    _running = completer.future;
    unawaited(_reload(generation, completer));
    return completer.future;
  }

  Future<void> _reload(int generation, Completer<void> completer) async {
    try {
      do {
        _queued = false;
        try {
          final next = await loader();
          if (_disposed || generation != _generation) return;
          _value = next;
          _hasSnapshot = true;
          _stale = false;
          notifyListeners();
        } on Object {
          if (_disposed || generation != _generation) return;
          _stale = true;
          notifyListeners();
        }
      } while (_queued && !_disposed && generation == _generation);
    } finally {
      if (generation == _generation) _running = null;
      completer.complete();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
