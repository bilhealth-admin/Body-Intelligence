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
  });

  final int unreadMessages;
  final int incomingRequests;
  final int communityUpdates;
  final Map<String, int> unreadBySender;
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
    );
  }

  static String badgeText(int count) => count > 99 ? '99+' : '$count';
}

enum CommunityNotificationKind { friendAccepted }

@immutable
class CommunityNotification {
  const CommunityNotification({
    required this.id,
    required this.kind,
    required this.actorId,
    required this.friendshipId,
    required this.createdAt,
    this.actorDisplayName,
    this.actorAvatarUrl,
    this.seenAt,
  });

  final String id;
  final CommunityNotificationKind kind;
  final String? actorId;
  final String? actorDisplayName;
  final String? actorAvatarUrl;
  final String? friendshipId;
  final DateTime createdAt;
  final DateTime? seenAt;

  bool get seen => seenAt != null;

  factory CommunityNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final kind = json['kind'];
    final actorId = json['actor_id'];
    final actorDisplayName = json['actor_display_name'];
    final actorAvatarUrl = json['actor_avatar_url'];
    final friendshipId = json['friendship_id'];
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final rawSeenAt = json['seen_at'];
    final seenAt = rawSeenAt == null ? null : DateTime.tryParse(rawSeenAt.toString());
    if (id is! String ||
        id.isEmpty ||
        kind != 'friend_accepted' ||
        (actorId != null && actorId is! String) ||
        (actorDisplayName != null &&
            (actorDisplayName is! String ||
                actorDisplayName.trim().isEmpty ||
                actorDisplayName.length > 60)) ||
        (actorAvatarUrl != null && actorAvatarUrl is! String) ||
        (friendshipId != null && friendshipId is! String) ||
        createdAt == null ||
        (rawSeenAt != null && seenAt == null)) {
      throw const FormatException('Invalid Community notification');
    }
    return CommunityNotification(
      id: id,
      kind: CommunityNotificationKind.friendAccepted,
      actorId: actorId as String?,
      actorDisplayName: actorDisplayName as String?,
      actorAvatarUrl: actorAvatarUrl as String?,
      friendshipId: friendshipId as String?,
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
