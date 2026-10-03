part of 'community_repository.dart';

mixin _CommunityConnectionsMessagingRepositoryMixin {
  SupabaseClient get _client;

  User get _user;

  String get currentUserId;

  Future<T> _runCommunityMutation<T>(Future<T> Function() mutation);

  Future<void> _requireAcceptedContentPolicy();

  Future<List<Map<String, dynamic>>> loadFriendships() async {
    return await _client
        .from('bil_friendships')
        .select()
        .order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async {
    final response = await _client.rpc('bil_list_community_connections');
    if (response is! List) {
      throw const FormatException('Invalid community connections result');
    }
    return response
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .where((row) {
          final id = row['id'];
          final requester = row['requester_id'];
          final addressee = row['addressee_id'];
          final status = row['status'];
          final otherUserId = row['other_user_id'];
          final displayName = row['display_name'];
          final avatarUrl = row['avatar_url'];
          return id is String &&
              CommunityRepository._uuid.hasMatch(id) &&
              requester is String &&
              CommunityRepository._uuid.hasMatch(requester) &&
              addressee is String &&
              CommunityRepository._uuid.hasMatch(addressee) &&
              (requester == _user.id || addressee == _user.id) &&
              status is String &&
              const {'pending', 'accepted'}.contains(status) &&
              otherUserId is String &&
              CommunityRepository._uuid.hasMatch(otherUserId) &&
              (displayName == null ||
                  (displayName is String &&
                      displayName.trim().length >= 2 &&
                      displayName.trim().length <= 60 &&
                      !CommunityRepository._unsafeText.hasMatch(displayName))) &&
              (avatarUrl == null || avatarUrl is String);
        })
        .map((row) {
          return {
            ...row,
            'profile': {
              'display_name': row['display_name'],
              'avatar_url': row['avatar_url'],
            },
          };
        })
        .toList(growable: false);
  }

  Future<List<CommunityNotification>> loadCommunityNotifications({
    int limit = 30,
  }) async {
    if (limit < 1 || limit > 100) throw ArgumentError.value(limit, 'limit');
    final response = await _client.rpc(
      'bil_list_community_activity_v2',
      params: {
        'p_before': null,
        'p_before_id': null,
        'p_kinds': null,
        'p_limit': limit,
      },
    );
    if (response is! List) {
      throw const FormatException('Invalid Community notifications result');
    }
    return List<CommunityNotification>.unmodifiable(
      response.map((item) {
        if (item is! Map) {
          throw const FormatException('Invalid Community notification');
        }
        return CommunityNotification.fromJson(Map<String, dynamic>.from(item));
      }),
    );
  }

  Future<int> markCommunityNotificationsSeen(List<String> ids) async {
    final unique = ids.toSet().toList(growable: false);
    if (unique.isEmpty) return 0;
    if (unique.length > 100 || unique.any((id) => !CommunityRepository._uuid.hasMatch(id))) {
      throw ArgumentError.value(ids, 'ids');
    }
    final response = await _client.rpc(
      'bil_mark_community_activity_seen_v2',
      params: {'p_ids': unique},
    );
    if (response is! int || response < 0 || response > unique.length) {
      throw const FormatException('Invalid Community seen result');
    }
    return response;
  }

  Future<void> follow(String userId) =>
      _client.rpc('bil_follow_member', params: {'p_followed_id': userId});

  Future<void> unfollow(String userId) =>
      _client.rpc('bil_unfollow_member', params: {'p_followed_id': userId});

  Future<void> respondToFriendship(String id, {required bool accept}) async {
    if (!CommunityRepository._uuid.hasMatch(id)) throw ArgumentError.value(id, 'id');
    final changed = await _client
        .from('bil_friendships')
        .update({
          'status': accept ? 'accepted' : 'declined',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('addressee_id', _user.id)
        .eq('status', 'pending')
        .select('id');
    if (changed.length != 1) {
      throw StateError('Friend request was not available to update');
    }
  }

  Future<void> removeFriendship(String id) async {
    if (!CommunityRepository._uuid.hasMatch(id)) throw ArgumentError.value(id, 'id');
    final changed = await _client
        .from('bil_friendships')
        .delete()
        .eq('id', id)
        .or('requester_id.eq.${_user.id},addressee_id.eq.${_user.id}')
        .select('id');
    if (changed.length != 1) {
      throw StateError('Friendship was not available to remove');
    }
  }

  Future<void> blockMember(String userId) async {
    await _client.rpc(
      'bil_block_community_member',
      params: {'p_blocked_id': userId},
    );
  }

  Future<List<CommunityMessage>> loadMessages(String otherUserId) async {
    final userId = _user.id;
    final rows = await _client
        .from('bil_messages')
        .select('id,sender_id,recipient_id,body,created_at,read_at')
        .or(
          'and(sender_id.eq.$userId,recipient_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,recipient_id.eq.$userId)',
        )
        .order('created_at')
        .order('id');
    final messages = rows
        .map((row) => CommunityMessage.fromJson(row))
        .toList(growable: true);
    // Keep the conversation transcript chronological even if an edge/cache
    // returns rows outside the requested order. The chat viewport is reversed
    // so this places the newest message at the latest (bottom) end.
    messages.sort((left, right) {
      final byTime = left.createdAt.compareTo(right.createdAt);
      return byTime == 0 ? left.id.compareTo(right.id) : byTime;
    });
    return List<CommunityMessage>.unmodifiable(messages);
  }

  Stream<void> watchConversationChanges(String otherUserId) {
    final currentUserId = _user.id;
    if (!CommunityRepository._uuid.hasMatch(otherUserId) || otherUserId == currentUserId) {
      throw ArgumentError.value(otherUserId, 'otherUserId');
    }

    Stream<void> changesWhere(String column) => _client
        .from('bil_messages')
        .stream(primaryKey: const ['id'])
        .eq(column, otherUserId)
        .order('created_at')
        .order('id')
        .limit(1)
        .map<void>((_) {});

    final streams = <Stream<void>>[
      // With message RLS, these are respectively other -> current and
      // current -> other. No rows from unrelated conversations are visible.
      changesWhere('sender_id'),
      changesWhere('recipient_id'),
    ];
    final subscriptions = <StreamSubscription<void>>[];
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        for (final stream in streams) {
          subscriptions.add(
            stream.listen(
              (_) => controller.add(null),
              onError: controller.addError,
            ),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<List<Map<String, dynamic>>> loadInboxMessages() async {
    final rows = await _client
        .from('bil_messages')
        .select('id,sender_id,recipient_id,body,created_at,read_at')
        .eq('recipient_id', _user.id)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(100);
    return _enrichMessageRows(rows, profileKey: 'sender_id');
  }

  Stream<void> watchInboxChanges() => _client
      .from('bil_messages')
      .stream(primaryKey: const ['id'])
      .eq('recipient_id', _user.id)
      .order('created_at')
      .limit(1)
      .map<void>((_) {});

  Future<List<Map<String, dynamic>>> loadSentMessages() async {
    final rows = await _client
        .from('bil_messages')
        .select('id,sender_id,recipient_id,body,created_at,read_at')
        .eq('sender_id', _user.id)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(100);
    return _enrichMessageRows(rows, profileKey: 'recipient_id');
  }

  Future<List<Map<String, dynamic>>> _enrichMessageRows(
    List<Map<String, dynamic>> rows, {
    required String profileKey,
  }) async {
    final currentUserId = _user.id;
    final validRows = rows
        .where((row) {
          final id = row['id'];
          final sender = row['sender_id'];
          final recipient = row['recipient_id'];
          final body = row['body'];
          final createdAt = row['created_at'];
          final parsedAt = createdAt is String
              ? DateTime.tryParse(createdAt)
              : null;
          final envelopeValid = body is String && _validMessageEnvelope(body);
          final ownsRow = profileKey == 'sender_id'
              ? recipient == currentUserId
              : sender == currentUserId;
          return id is String &&
              CommunityRepository._uuid.hasMatch(id) &&
              sender is String &&
              CommunityRepository._uuid.hasMatch(sender) &&
              recipient is String &&
              CommunityRepository._uuid.hasMatch(recipient) &&
              ownsRow &&
              envelopeValid &&
              parsedAt != null;
        })
        .toList(growable: false);
    if (validRows.isEmpty) return const [];
    final ids = validRows
        .map((row) => row[profileKey] as String)
        .toSet()
        .toList();
    final profiles = await _client
        .from('bil_public_profiles')
        .select('user_id,display_name,avatar_url')
        .inFilter('user_id', ids);
    final byId = <String, Map<String, dynamic>>{};
    for (final row in profiles) {
      final id = row['user_id'];
      final name = row['display_name'];
      final avatar = row['avatar_url'];
      if (id is String &&
          CommunityRepository._uuid.hasMatch(id) &&
          name is String &&
          name.trim().isNotEmpty &&
          name.length <= 60 &&
          (avatar == null || avatar is String)) {
        byId[id] = row;
      }
    }
    return validRows
        .map((row) => {...row, 'profile': byId[row[profileKey]]})
        .toList(growable: false);
  }

  static bool _validMessageEnvelope(String body) {
    if (body.trim().isEmpty ||
        body.length > 4200 ||
        CommunityRepository._unsafeText.hasMatch(body)) {
      return false;
    }
    const marker = '[BIL-SUBJECT]';
    if (!body.startsWith(marker)) return true;
    final newline = body.indexOf('\n');
    if (newline < 0) return false;
    final subject = body.substring(marker.length, newline);
    final message = body.substring(newline + 1);
    return subject.length <= 120 &&
        message.trim().isNotEmpty &&
        message.length <= 4000;
  }

  Future<void> sendMessage(String recipientId, String body) async {
    if (!CommunityRepository._uuid.hasMatch(recipientId) || recipientId == _user.id) {
      throw ArgumentError.value(recipientId, 'recipientId');
    }
    final text = body.trim();
    if (text.isEmpty || text.length > 4200 || CommunityRepository._unsafeText.hasMatch(text)) {
      throw ArgumentError.value(body, 'body');
    }
    CommunityTextPolicy.enforce(text, surface: CommunityTextSurface.message);
    await _requireAcceptedContentPolicy();
    await _runCommunityMutation(
      () => _client.from('bil_messages').insert({
        'sender_id': _user.id,
        'recipient_id': recipientId,
        'body': text,
      }),
    );
  }

  Future<void> deleteMessage(String messageId) =>
      _client.rpc('bil_delete_message', params: {'p_message_id': messageId});

  Future<void> acceptContentPolicy(String version) => _client
      .from('bil_content_policy_acceptances')
      .upsert({'user_id': _user.id, 'policy_version': version});

  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async {
    if (localeCode.trim().isEmpty) {
      throw ArgumentError.value(localeCode, 'localeCode');
    }
    final response = await _client.rpc('bil_current_community_policy_status');
    if (response is! Map) {
      throw const FormatException('Invalid Community policy status payload');
    }
    return CommunityPolicyState.fromServerSnapshot(
      Map<String, dynamic>.from(response),
    );
  }

}
