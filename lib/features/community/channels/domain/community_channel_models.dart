import '../../domain/community_text_policy.dart';

enum ChannelFailureKind {
  unavailable,
  denied,
  policyRequired,
  invalidText,
  conflict,
  transport,
}

final class ChannelFailure implements Exception {
  const ChannelFailure(this.kind);

  final ChannelFailureKind kind;

  @override
  String toString() => 'Community channel: ${kind.name}';
}

/// A single visit, including its repository instance and delivered auth epoch.
/// A visit is permanently revoked; matching the owner ID again cannot revive it.
final class ChannelRequestScope {
  const ChannelRequestScope({
    required this.ownerId,
    required this.visitGeneration,
    required this.isCurrentVisit,
  });

  final String ownerId;
  final int visitGeneration;
  final bool Function() isCurrentVisit;

  bool get isCurrent => isCurrentVisit();

  void check() {
    if (!isCurrent) throw const ChannelVisitCancelled();
  }
}

final class ChannelVisitCancelled implements Exception {
  const ChannelVisitCancelled();
}

abstract final class CommunityChannelText {
  // This is the versioned CHANNEL contract, independent of the post limit.
  static const maxCodePointsV1 = 2000;
  static final _unsafe = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static const _blank = <int>{
    9,
    10,
    13,
    32,
    160,
    5760,
    8192,
    8193,
    8194,
    8195,
    8196,
    8197,
    8198,
    8199,
    8200,
    8201,
    8202,
    8232,
    8233,
    8239,
    8287,
    12288,
    65279,
  };

  /// Preserve the exact payload. Neither validation nor retry trims/clips it.
  static void validate(String text, {required int maxCodePoints}) {
    validateEnvelope(text, maxCodePoints: maxCodePoints);
    CommunityTextPolicy.enforce(text, surface: CommunityTextSurface.message);
  }

  static void validateEnvelope(String text, {required int maxCodePoints}) {
    if (maxCodePoints != maxCodePointsV1 ||
        !text.runes.any((rune) => !_blank.contains(rune)) ||
        text.runes.length > maxCodePoints ||
        _unsafe.hasMatch(text)) {
      throw const ChannelFailure(ChannelFailureKind.invalidText);
    }
  }
}

final class CommunityChannelCapabilities {
  const CommunityChannelCapabilities({
    this.maxTextCodePoints = CommunityChannelText.maxCodePointsV1,
    this.maxPageSize = 100,
    this.maxReceiptIds = 100,
    this.presenceTtlSeconds = 90,
    this.presenceHeartbeatSeconds = 30,
    this.realtimeAvailable = false,
  });

  final int maxTextCodePoints;
  final int maxPageSize;
  final int maxReceiptIds;
  final int presenceTtlSeconds;
  final int presenceHeartbeatSeconds;
  final bool realtimeAvailable;
}

final class CommunityChannel {
  const CommunityChannel({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.visibility,
    required this.enabled,
    required this.membership,
    required this.canRead,
    required this.canSend,
    required this.unreadCount,
    required this.latestSequence,
    this.maxTextCodePoints = CommunityChannelText.maxCodePointsV1,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String visibility;
  final bool enabled;
  final String membership;
  final bool canRead;
  final bool canSend;
  final int? unreadCount;
  final int latestSequence;
  final int maxTextCodePoints;

  CommunityChannel withUnread(int? count) => CommunityChannel(
    id: id,
    slug: slug,
    title: title,
    description: description,
    visibility: visibility,
    enabled: enabled,
    membership: membership,
    canRead: canRead,
    canSend: canSend,
    unreadCount: count,
    latestSequence: latestSequence,
    maxTextCodePoints: maxTextCodePoints,
  );
}

final class CommunityChannelMessage {
  const CommunityChannelMessage({
    required this.id,
    required this.channelId,
    required this.sequence,
    required this.authorId,
    required this.authorDisplayName,
    required this.text,
    required this.clientMessageId,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final String channelId;
  final int sequence;
  final String authorId;
  final String? authorDisplayName;
  final String text;
  final String? clientMessageId;
  final DateTime createdAt;
  final bool isRead;

  CommunityChannelMessage confirmedRead() => CommunityChannelMessage(
    id: id,
    channelId: channelId,
    sequence: sequence,
    authorId: authorId,
    authorDisplayName: authorDisplayName,
    text: text,
    clientMessageId: clientMessageId,
    createdAt: createdAt,
    isRead: true,
  );
}

final class CommunityChannelDirectory {
  const CommunityChannelDirectory({
    required this.channels,
    required this.serverTime,
    this.nextAfterId,
  });

  final List<CommunityChannel> channels;
  final DateTime serverTime;
  final String? nextAfterId;
}

final class CommunityChannelMessagePage {
  const CommunityChannelMessagePage({
    required this.messages,
    required this.hasMore,
    required this.serverTime,
    this.nextBeforeSequence,
    this.nextAfterSequence,
  });

  final List<CommunityChannelMessage> messages;
  final bool hasMore;
  final DateTime serverTime;
  final int? nextBeforeSequence;
  final int? nextAfterSequence;
}

final class CommunityChannelReadback {
  const CommunityChannelReadback({
    required this.confirmedIds,
    required this.unreadCount,
    required this.serverTime,
  });

  final Set<String> confirmedIds;
  final int unreadCount;
  final DateTime serverTime;
}

final class CommunityChannelPresence {
  const CommunityChannelPresence({
    required this.onlineCount,
    required this.serverTime,
    required this.validUntil,
    this.ownExpiresAt,
  });

  final int onlineCount;
  final DateTime serverTime;
  final DateTime validUntil;
  final DateTime? ownExpiresAt;
}

final class CommunityChannelSendAttempt {
  const CommunityChannelSendAttempt({
    required this.ownerId,
    required this.channelId,
    required this.clientMessageId,
    required this.text,
    required this.draftRevision,
  });

  final String ownerId;
  final String channelId;
  final String clientMessageId;
  final String text;
  final int draftRevision;
}

enum CommunityChannelChange { invalidated, connected, disconnected }

/// Ephemeral, process-local drafts. Never mix owners or channels. This does not
/// claim persistence after process termination or upload private draft text.
final class CommunityChannelDraftStore {
  static final process = CommunityChannelDraftStore();
  final _drafts = <(String, String), _ChannelDraft>{};

  _ChannelDraft _draft(String owner, String channel) =>
      _drafts.putIfAbsent((owner, channel), _ChannelDraft.new);

  String text(String owner, String channel) => _draft(owner, channel).text;
  int revision(String owner, String channel) => _draft(owner, channel).revision;
  CommunityChannelSendAttempt? pending(String owner, String channel) =>
      _draft(owner, channel).pending;

  void update(String owner, String channel, String text) {
    final draft = _draft(owner, channel);
    if (draft.text == text) return;
    draft.text = text;
    draft.revision++;
  }

  void begin(CommunityChannelSendAttempt attempt) {
    final draft = _draft(attempt.ownerId, attempt.channelId);
    if (draft.pending != null) {
      throw const ChannelFailure(ChannelFailureKind.conflict);
    }
    draft.pending = attempt;
  }

  /// Only the acknowledged attempt can clear itself, and only its unchanged
  /// draft revision can clear the editor. Newer typing survives a late reply.
  void acknowledge(CommunityChannelSendAttempt attempt) {
    final draft = _draft(attempt.ownerId, attempt.channelId);
    if (draft.pending?.clientMessageId != attempt.clientMessageId) return;
    draft.pending = null;
    if (draft.revision == attempt.draftRevision && draft.text == attempt.text) {
      draft.text = '';
      draft.revision++;
    }
  }
}

final class _ChannelDraft {
  String text = '';
  int revision = 0;
  CommunityChannelSendAttempt? pending;
}
