part of 'community_repository.dart';

mixin _CommunityConnectionsMessagingRepositoryMixin {
  SupabaseClient get _client;

  User get _user;

  String get currentUserId;

  Future<T> _runCommunityMutation<T>(Future<T> Function() mutation);

  Future<void> _requireAcceptedContentPolicy();

  Future<T> _runCommunityOwnerOperation<T>(
    Future<T> Function(CommunityOwnerOperation operation) action,
  );

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
                      !CommunityRepository._unsafeText.hasMatch(
                        displayName,
                      ))) &&
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
    DateTime? before,
    String? beforeId,
    List<CommunityNotificationKind>? kinds,
    int limit = 30,
  }) async {
    if (limit < 1 || limit > 100) throw ArgumentError.value(limit, 'limit');
    if ((before == null) != (beforeId == null) ||
        (beforeId != null && !CommunityRepository._uuid.hasMatch(beforeId)) ||
        (kinds != null &&
            (kinds.isEmpty || kinds.toSet().length != kinds.length))) {
      throw ArgumentError('Invalid Community activity cursor or kinds');
    }
    final response = await _client.rpc(
      'bil_list_community_activity_v2',
      params: {
        'p_before': before?.toUtc().toIso8601String(),
        'p_before_id': beforeId,
        'p_kinds': kinds?.map((kind) => kind.wireValue).toList(growable: false),
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
    if (unique.length > 100 ||
        unique.any((id) => !CommunityRepository._uuid.hasMatch(id))) {
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
    if (!CommunityRepository._uuid.hasMatch(id)) {
      throw ArgumentError.value(id, 'id');
    }
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
    if (!CommunityRepository._uuid.hasMatch(id)) {
      throw ArgumentError.value(id, 'id');
    }
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

  Future<List<CommunityMessage>> loadMessages(String otherUserId) =>
      _loadMessagePage(otherUserId);

  Future<List<CommunityMessage>> loadOlderMessages(
    String otherUserId, {
    required DateTime before,
    required String beforeId,
  }) => _loadMessagePage(otherUserId, before: before, beforeId: beforeId);

  Future<List<CommunityMessage>> _loadMessagePage(
    String otherUserId, {
    DateTime? before,
    String? beforeId,
  }) => _runCommunityOwnerOperation((operation) async {
    final owner = operation.ownerId;
    if (owner == null) throw const AuthException('Sign-in required');
    if (!CommunityRepository._uuid.hasMatch(otherUserId) ||
        owner == otherUserId ||
        (before == null) != (beforeId == null) ||
        (beforeId != null && !CommunityRepository._uuid.hasMatch(beforeId))) {
      throw ArgumentError('Invalid private conversation or cursor');
    }
    final cursor = before == null
        ? ''
        : ',or(created_at.lt.${before.toUtc().toIso8601String()},'
              'and(created_at.eq.${before.toUtc().toIso8601String()},id.lt.$beforeId))';
    final rows = await _client
        .from('bil_messages')
        .select('id,sender_id,recipient_id,body,created_at,read_at')
        .or(
          'and(sender_id.eq.$owner,recipient_id.eq.$otherUserId$cursor),'
          'and(sender_id.eq.$otherUserId,recipient_id.eq.$owner$cursor)',
        )
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(50);
    operation.check();
    final messages = <CommunityMessage>[];
    final ids = <String>{};
    for (final row in rows) {
      final message = CommunityMessage.fromJson(row);
      final pair =
          (message.senderId == owner && message.recipientId == otherUserId) ||
          (message.senderId == otherUserId && message.recipientId == owner);
      final older =
          before == null ||
          message.createdAt.isBefore(before) ||
          (message.createdAt.isAtSameMomentAs(before) &&
              message.id.compareTo(beforeId!) < 0);
      if (!pair ||
          !older ||
          !CommunityRepository._uuid.hasMatch(message.id) ||
          !_validMessageEnvelope(message.body) ||
          !ids.add(message.id)) {
        throw const FormatException('Invalid private conversation readback');
      }
      messages.add(message);
    }
    // Server pages are newest-first; the reversed viewport consumes an
    // ascending transcript with the same deterministic UUID tie-breaker.
    messages.sort((left, right) {
      final byTime = left.createdAt.compareTo(right.createdAt);
      return byTime == 0 ? left.id.compareTo(right.id) : byTime;
    });
    return List<CommunityMessage>.unmodifiable(messages);
  });

  /// The write RPC returns a count, not the identities that it acknowledged.
  /// Read only the requested incoming rows back through existing message RLS.
  Future<Set<String>> loadReadMessageIds(
    String otherUserId,
    List<String> messageIds,
  ) => _runCommunityOwnerOperation((operation) async {
    final owner = operation.ownerId;
    if (owner == null) throw const AuthException('Sign-in required');
    final ids = messageIds.toSet();
    if (!CommunityRepository._uuid.hasMatch(otherUserId) ||
        otherUserId == owner ||
        ids.length > 200 ||
        ids.any((id) => !CommunityRepository._uuid.hasMatch(id))) {
      throw ArgumentError('Invalid private message readback');
    }
    if (ids.isEmpty) return <String>{};
    final rows = await _client
        .from('bil_messages')
        .select('id,sender_id,recipient_id,read_at')
        .eq('sender_id', otherUserId)
        .eq('recipient_id', owner)
        .inFilter('id', ids.toList());
    operation.check();
    final confirmed = <String>{};
    for (final row in rows) {
      if (!ids.contains(row['id']) ||
          row['sender_id'] != otherUserId ||
          row['recipient_id'] != owner) {
        throw const FormatException(
          'Message readback does not belong to this conversation',
        );
      }
      final readAt = row['read_at'];
      if (readAt == null) continue;
      if (readAt is! String || DateTime.tryParse(readAt) == null) {
        throw const FormatException('Invalid message read timestamp');
      }
      confirmed.add(row['id'] as String);
    }
    return Set<String>.unmodifiable(confirmed);
  });

  Stream<void> watchConversationChanges(String otherUserId) {
    final currentUserId = _user.id;
    if (!CommunityRepository._uuid.hasMatch(otherUserId) ||
        otherUserId == currentUserId) {
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

  Future<List<Map<String, dynamic>>> loadInboxMessages() =>
      _runCommunityOwnerOperation((operation) async {
        final owner = operation.ownerId;
        if (owner == null) throw const AuthException('Sign-in required');
        final rows = await _client
            .from('bil_messages')
            .select('id,sender_id,recipient_id,body,created_at,read_at')
            .eq('recipient_id', owner)
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .limit(100);
        operation.check();
        return _enrichMessageRows(rows, owner: owner, profileKey: 'sender_id');
      });

  Stream<void> watchInboxChanges() => _client
      .from('bil_messages')
      .stream(primaryKey: const ['id'])
      .eq('recipient_id', _user.id)
      .order('created_at')
      .limit(1)
      .map<void>((_) {});

  Future<List<Map<String, dynamic>>> loadSentMessages() =>
      _runCommunityOwnerOperation((operation) async {
        final owner = operation.ownerId;
        if (owner == null) throw const AuthException('Sign-in required');
        final rows = await _client
            .from('bil_messages')
            .select('id,sender_id,recipient_id,body,created_at,read_at')
            .eq('sender_id', owner)
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .limit(100);
        operation.check();
        return _enrichMessageRows(
          rows,
          owner: owner,
          profileKey: 'recipient_id',
        );
      });

  Future<List<Map<String, dynamic>>> _enrichMessageRows(
    List<Map<String, dynamic>> rows, {
    required String profileKey,
    required String owner,
  }) async {
    CommunityOwnerOperation.checkCurrent();
    final currentUserId = owner;
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
    CommunityOwnerOperation.checkCurrent();
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
        body.runes.length > 2000 ||
        CommunityRepository._unsafeText.hasMatch(body)) {
      return false;
    }
    const marker = '[BIL-SUBJECT]';
    if (!body.startsWith(marker)) return true;
    final newline = body.indexOf('\n');
    if (newline < 0) return false;
    final subject = body.substring(marker.length, newline);
    final message = body.substring(newline + 1);
    return subject.runes.length <= 120 &&
        message.trim().isNotEmpty &&
        message.runes.length <= 2000;
  }

  Future<void> sendMessage(String recipientId, String body) =>
      _runCommunityOwnerOperation((operation) async {
        final owner = operation.ownerId;
        if (owner == null) throw const AuthException('Sign-in required');
        if (!CommunityRepository._uuid.hasMatch(recipientId) ||
            recipientId == owner) {
          throw ArgumentError.value(recipientId, 'recipientId');
        }
        final text = body.trim();
        // PostgreSQL length(text) counts Unicode code points, not UTF-16 units.
        if (!_validMessageEnvelope(text)) {
          throw ArgumentError.value(body, 'body');
        }
        CommunityTextPolicy.enforce(
          text,
          surface: CommunityTextSurface.message,
        );
        await _requireAcceptedContentPolicy();
        operation.check();
        await _runCommunityMutation(
          () => _client.from('bil_messages').insert({
            'sender_id': owner,
            'recipient_id': recipientId,
            'body': text,
          }),
        );
        operation.check();
      });

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
