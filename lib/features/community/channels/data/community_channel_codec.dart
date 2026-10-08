import '../domain/community_channel_models.dart';

/// Strict boundary for the unpublished v1 RPC contract. No numeric defaults
/// turn a missing capability, unread count, or presence source into success.
abstract final class CommunityChannelCodec {
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static const _largestExactInteger = 9007199254740991;

  static void requireUuid(String value) {
    if (!_uuid.hasMatch(value)) {
      throw const FormatException('Invalid channel UUID');
    }
  }

  static Map<String, dynamic> envelope(
    Object? value, {
    required String ownerId,
    String? channelId,
  }) {
    final row = _map(value);
    if (row['contract_version'] != 1) {
      throw const ChannelFailure(ChannelFailureKind.unavailable);
    }
    requireUuid(ownerId);
    if (row['owner_id'] != ownerId ||
        (channelId != null && row['channel_id'] != channelId)) {
      throw const FormatException('Channel response scope mismatch');
    }
    _date(row, 'server_time');
    return row;
  }

  static CommunityChannelCapabilities capabilities(
    Object? payload,
    String ownerId,
  ) {
    final row = envelope(payload, ownerId: ownerId);
    final textLimit = _integer(row, 'max_text_code_points', min: 1);
    final pageSize = _integer(row, 'max_page_size', min: 1);
    final receiptIds = _integer(row, 'max_receipt_ids', min: 1);
    final ttl = _integer(row, 'presence_ttl_seconds', min: 1);
    final heartbeat = _integer(row, 'presence_heartbeat_seconds', min: 1);
    if (textLimit != CommunityChannelText.maxCodePointsV1 ||
        pageSize != 100 ||
        receiptIds != 100 ||
        ttl != 90 ||
        heartbeat != 30 ||
        row['read_receipts'] != 'exact_message_ids_v1') {
      throw const ChannelFailure(ChannelFailureKind.unavailable);
    }
    return CommunityChannelCapabilities(
      maxTextCodePoints: textLimit,
      maxPageSize: pageSize,
      maxReceiptIds: receiptIds,
      presenceTtlSeconds: ttl,
      presenceHeartbeatSeconds: heartbeat,
      realtimeAvailable: _boolean(row, 'realtime_available'),
    );
  }

  static CommunityChannelDirectory directory(Object? payload, String ownerId) {
    final row = envelope(payload, ownerId: ownerId);
    final rows = _list(row, 'channels');
    if (rows.length > 100) {
      throw const FormatException('Oversized channel directory');
    }
    final ids = <String>{};
    final channels = <CommunityChannel>[];
    for (final value in rows) {
      final item = _map(value);
      final id = _id(item, 'id');
      final membership = _string(item, 'membership');
      final visibility = _string(item, 'visibility');
      final enabled = _boolean(item, 'enabled');
      final canRead = _boolean(item, 'can_read');
      final canSend = _boolean(item, 'can_send');
      final limit = _integer(item, 'max_text_code_points', min: 1);
      final unread = item['unread_count'] == null
          ? null
          : _integer(item, 'unread_count');
      if (!ids.add(id) ||
          !{'active', 'none', 'banned'}.contains(membership) ||
          !{'public', 'members'}.contains(visibility) ||
          limit != CommunityChannelText.maxCodePointsV1 ||
          (canRead && (!enabled || membership == 'banned')) ||
          (canRead && visibility == 'members' && membership != 'active') ||
          (canSend && (!canRead || membership != 'active')) ||
          (!canRead && unread != null)) {
        throw const FormatException('Invalid channel permissions');
      }
      channels.add(
        CommunityChannel(
          id: id,
          slug: _string(item, 'slug'),
          title: _string(item, 'title'),
          description: _string(item, 'description', allowEmpty: true),
          visibility: visibility,
          enabled: enabled,
          membership: membership,
          canRead: canRead,
          canSend: canSend,
          unreadCount: unread,
          latestSequence: _integer(item, 'latest_sequence'),
          maxTextCodePoints: limit,
        ),
      );
    }
    final next = row['next_after_id'] == null
        ? null
        : _id(row, 'next_after_id');
    if (next != null && !ids.contains(next)) {
      throw const FormatException('Invalid channel directory cursor');
    }
    return CommunityChannelDirectory(
      channels: List.unmodifiable(channels),
      nextAfterId: next,
      serverTime: _date(row, 'server_time'),
    );
  }

  static CommunityChannelMessage message(
    Object? payload,
    String ownerId,
    String channelId,
  ) {
    final row = _map(payload);
    if (_id(row, 'channel_id') != channelId) {
      throw const FormatException('Message channel mismatch');
    }
    final author = _id(row, 'author_id');
    final clientId = row['client_message_id'] == null
        ? null
        : _id(row, 'client_message_id');
    final name = row['author_display_name'];
    final text = _string(row, 'text', allowEmpty: false);
    CommunityChannelText.validateEnvelope(
      text,
      maxCodePoints: CommunityChannelText.maxCodePointsV1,
    );
    if ((name != null && (name is! String || name.runes.length > 120)) ||
        (author == ownerId && clientId == null) ||
        text.runes.length > CommunityChannelText.maxCodePointsV1) {
      throw const FormatException('Invalid channel message projection');
    }
    return CommunityChannelMessage(
      id: _id(row, 'id'),
      channelId: channelId,
      sequence: _integer(row, 'sequence', min: 1),
      authorId: author,
      authorDisplayName: name as String?,
      text: text,
      clientMessageId: clientId,
      createdAt: _date(row, 'created_at'),
      isRead: _boolean(row, 'is_read'),
    );
  }

  static CommunityChannelMessagePage messages(
    Object? payload,
    String ownerId,
    String channelId, {
    int? beforeSequence,
    int? afterSequence,
  }) {
    final row = envelope(payload, ownerId: ownerId, channelId: channelId);
    final items = _list(row, 'messages');
    if (items.length > 100) {
      throw const FormatException('Oversized channel page');
    }
    final ids = <String>{};
    var previous = 0;
    final messages = <CommunityChannelMessage>[];
    for (final item in items) {
      final value = message(item, ownerId, channelId);
      if (!ids.add(value.id) ||
          value.sequence <= previous ||
          (beforeSequence != null && value.sequence >= beforeSequence) ||
          (afterSequence != null && value.sequence <= afterSequence)) {
        throw const FormatException('Unordered channel page');
      }
      previous = value.sequence;
      messages.add(value);
    }
    final before = _nullableInteger(row, 'next_before_sequence');
    final after = _nullableInteger(row, 'next_after_sequence');
    if ((messages.isEmpty && (before != null || after != null)) ||
        (messages.isNotEmpty &&
            (before != messages.first.sequence ||
                after != messages.last.sequence))) {
      throw const FormatException('Channel page cursor mismatch');
    }
    final hasMore = _boolean(row, 'has_more');
    if (hasMore && messages.isEmpty) {
      throw const FormatException(
        'Empty channel page cannot have a continuation',
      );
    }
    return CommunityChannelMessagePage(
      messages: List.unmodifiable(messages),
      hasMore: hasMore,
      nextBeforeSequence: before,
      nextAfterSequence: after,
      serverTime: _date(row, 'server_time'),
    );
  }

  static CommunityChannelReadback readback(
    Object? payload,
    String ownerId,
    String channelId,
    Set<String> requested,
  ) {
    final row = envelope(payload, ownerId: ownerId, channelId: channelId);
    final confirmed = <String>{};
    for (final value in _list(row, 'acknowledged_message_ids')) {
      if (value is! String ||
          !requested.contains(value) ||
          !confirmed.add(value)) {
        throw const FormatException('Unrequested channel read receipt');
      }
    }
    return CommunityChannelReadback(
      confirmedIds: Set.unmodifiable(confirmed),
      unreadCount: _integer(row, 'unread_count'),
      serverTime: _date(row, 'server_time'),
    );
  }

  static CommunityChannelPresence presence(
    Object? payload,
    String ownerId,
    String channelId,
  ) {
    final row = envelope(payload, ownerId: ownerId, channelId: channelId);
    final at = _date(row, 'server_time');
    final until = _date(row, 'valid_until');
    final own = row['expires_at'] == null ? null : _date(row, 'expires_at');
    if (_integer(row, 'ttl_seconds') != 90 ||
        !until.isAfter(at) ||
        until.difference(at) > const Duration(seconds: 30) ||
        (own != null &&
            (!own.isAfter(at) ||
                own.difference(at) > const Duration(seconds: 90)))) {
      throw const FormatException('Invalid channel presence freshness');
    }
    return CommunityChannelPresence(
      onlineCount: _integer(row, 'online_count'),
      serverTime: at,
      validUntil: until,
      ownExpiresAt: own,
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected channel object');
    }
    return value;
  }

  static String _string(
    Map<String, dynamic> row,
    String key, {
    bool allowEmpty = false,
  }) {
    final value = row[key];
    if (value is! String || (!allowEmpty && value.isEmpty)) {
      throw FormatException('Invalid channel field: $key');
    }
    return value;
  }

  static String _id(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    requireUuid(value);
    return value;
  }

  static int _integer(Map<String, dynamic> row, String key, {int min = 0}) {
    final value = row[key];
    if (value is! int || value < min || value > _largestExactInteger) {
      throw FormatException('Invalid channel integer: $key');
    }
    return value;
  }

  static int? _nullableInteger(Map<String, dynamic> row, String key) =>
      row[key] == null ? null : _integer(row, key, min: 1);

  static bool _boolean(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! bool) throw FormatException('Invalid channel boolean: $key');
    return value;
  }

  static List<Object?> _list(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! List) throw FormatException('Invalid channel list: $key');
    return value.cast<Object?>();
  }

  static DateTime _date(Map<String, dynamic> row, String key) {
    final value = _string(row, key);
    final date = DateTime.tryParse(value);
    if (date == null || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
      throw FormatException('Invalid channel timestamp: $key');
    }
    return date.toUtc();
  }
}
