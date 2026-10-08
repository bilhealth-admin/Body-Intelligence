import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/community_repository.dart';
import '../../domain/community_content_policy.dart';
import '../../services/community_owner_operation.dart';
import '../domain/community_channel_models.dart';
import '../domain/community_channels_repository.dart';
import 'community_channel_codec.dart';

/// The app's existing CommunityOwnerHttpClient must remain installed on this
/// Supabase client. It enforces the visit fence after SDK token resolution.
final class SupabaseCommunityChannelsRepository
    implements CommunityChannelsRepository {
  SupabaseCommunityChannelsRepository(this.community);

  final CommunityRepository community;
  SupabaseClient get _client => community.communitySocialClient;

  @override
  String? get currentOwnerId => _client.auth.currentUser?.id;

  @override
  Stream<String?> get ownerChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session?.user.id);

  Future<T> _run<T>(
    ChannelRequestScope scope,
    Future<T> Function() action, {
    bool Function()? isActive,
  }) => CommunityOwnerOperation.run(
    client: _client,
    ownerId: scope.ownerId,
    readOwner: () => currentOwnerId,
    isCurrentOwner: () => scope.isCurrent && (isActive?.call() ?? true),
    beforeDataSend: () async => scope.check(),
    action: (operation) async {
      scope.check();
      try {
        final result = await action();
        operation.check();
        scope.check();
        return result;
      } on PostgrestException catch (error) {
        operation.check();
        scope.check();
        throw _failure(error);
      } on CommunityPolicyAccessException catch (error) {
        operation.check();
        scope.check();
        throw ChannelFailure(
          error.failure == CommunityPolicyAccessFailure.acceptanceRequired
              ? ChannelFailureKind.policyRequired
              : ChannelFailureKind.unavailable,
        );
      } on Object {
        operation.check();
        scope.check();
        rethrow;
      }
    },
  );

  static ChannelFailure _failure(PostgrestException error) {
    if (error.code == 'PGRST202' ||
        error.code == '42883' ||
        error.code == '42P01') {
      return const ChannelFailure(ChannelFailureKind.unavailable);
    }
    if (error.message.contains('policy_acceptance_required')) {
      return const ChannelFailure(ChannelFailureKind.policyRequired);
    }
    if (error.message.contains('policy_unavailable')) {
      return const ChannelFailure(ChannelFailureKind.unavailable);
    }
    if (error.message.contains('idempotency_payload_mismatch')) {
      return const ChannelFailure(ChannelFailureKind.conflict);
    }
    if (error.code == '42501') {
      return const ChannelFailure(ChannelFailureKind.denied);
    }
    if (error.code == '22023') {
      return const ChannelFailure(ChannelFailureKind.invalidText);
    }
    return const ChannelFailure(ChannelFailureKind.transport);
  }

  @override
  Future<CommunityChannelCapabilities> loadCapabilities(
    ChannelRequestScope scope,
  ) => _run(
    scope,
    () async => CommunityChannelCodec.capabilities(
      await _client.rpc('bil07_channel_capabilities_v1'),
      scope.ownerId,
    ),
  );

  @override
  Future<CommunityChannelDirectory> loadDirectory(
    ChannelRequestScope scope, {
    String? afterId,
    int limit = 50,
  }) => _run(scope, () async {
    if (afterId != null) CommunityChannelCodec.requireUuid(afterId);
    if (limit < 1 || limit > 100) throw ArgumentError.value(limit, 'limit');
    final result = CommunityChannelCodec.directory(
      await _client.rpc(
        'bil07_channel_directory_v1',
        params: {'p_after_id': afterId, 'p_limit': limit},
      ),
      scope.ownerId,
    );
    if (afterId != null &&
        result.channels.any((row) => row.id.compareTo(afterId) <= 0)) {
      throw const FormatException('Channel directory did not advance');
    }
    return result;
  });

  @override
  Future<CommunityChannelMessagePage> loadMessages(
    ChannelRequestScope scope,
    String channelId, {
    int? beforeSequence,
    int? afterSequence,
    int limit = 50,
  }) => _run(scope, () async {
    CommunityChannelCodec.requireUuid(channelId);
    if (limit < 1 ||
        limit > 100 ||
        (beforeSequence != null &&
            (beforeSequence < 1 || afterSequence != null)) ||
        (afterSequence != null && afterSequence < 0)) {
      throw ArgumentError('Invalid channel paging');
    }
    return CommunityChannelCodec.messages(
      await _client.rpc(
        'bil07_channel_messages_v1',
        params: {
          'p_channel_id': channelId,
          'p_before_sequence': beforeSequence,
          'p_after_sequence': afterSequence,
          'p_limit': limit,
        },
      ),
      scope.ownerId,
      channelId,
      beforeSequence: beforeSequence,
      afterSequence: afterSequence,
    );
  });

  @override
  Future<CommunityChannelMessage> send(
    ChannelRequestScope scope,
    CommunityChannelSendAttempt attempt,
  ) => _run(scope, () async {
    if (attempt.ownerId != scope.ownerId) throw const ChannelVisitCancelled();
    CommunityChannelCodec.requireUuid(attempt.channelId);
    CommunityChannelCodec.requireUuid(attempt.clientMessageId);
    CommunityChannelText.validate(
      attempt.text,
      maxCodePoints: CommunityChannelText.maxCodePointsV1,
    );
    await community.requireAcceptedCommunityPolicy();
    scope.check();
    final payload = await community.runCommunitySocialMutation(
      () => _client.rpc(
        'bil07_channel_send_v1',
        params: {
          'p_channel_id': attempt.channelId,
          'p_client_message_id': attempt.clientMessageId,
          'p_text': attempt.text,
        },
      ),
    );
    scope.check();
    final row = CommunityChannelCodec.envelope(
      payload,
      ownerId: scope.ownerId,
      channelId: attempt.channelId,
    );
    if (row['idempotent_replay'] is! bool) {
      throw const FormatException('Invalid channel send receipt');
    }
    final message = CommunityChannelCodec.message(
      row['message'],
      scope.ownerId,
      attempt.channelId,
    );
    if (message.authorId != scope.ownerId ||
        message.text != attempt.text ||
        message.clientMessageId != attempt.clientMessageId) {
      throw const FormatException('Channel send receipt payload mismatch');
    }
    return message;
  });

  @override
  Future<CommunityChannelReadback> acknowledgeVisible(
    ChannelRequestScope scope,
    String channelId,
    List<String> messageIds,
  ) => _run(scope, () async {
    CommunityChannelCodec.requireUuid(channelId);
    final ids = messageIds.toSet();
    if (ids.isEmpty || ids.length > 100) {
      throw ArgumentError('Invalid channel read batch');
    }
    for (final id in ids) {
      CommunityChannelCodec.requireUuid(id);
    }
    final params = {'p_channel_id': channelId, 'p_message_ids': ids.toList()};
    await _client.rpc('bil07_channel_read_v1', params: params);
    scope.check();
    // A separate authoritative SELECT is required. The write response is never
    // used as evidence that every requested message became read.
    final payload = await _client.rpc(
      'bil07_channel_readback_v1',
      params: params,
    );
    scope.check();
    return CommunityChannelCodec.readback(
      payload,
      scope.ownerId,
      channelId,
      ids,
    );
  });

  @override
  Future<CommunityChannelPresence> loadPresence(
    ChannelRequestScope scope,
    String channelId, {
    required bool heartbeat,
    required bool Function() isForeground,
  }) => _run(scope, () async {
    CommunityChannelCodec.requireUuid(channelId);
    if (!isForeground()) throw const ChannelVisitCancelled();
    // The scope passed by the controller includes the foreground epoch, so the
    // common HTTP transport repeats this fence after an awaited token refresh.
    final payload = await _client.rpc(
      'bil07_channel_presence_v1',
      params: {'p_channel_id': channelId, 'p_heartbeat': heartbeat},
    );
    scope.check();
    if (!isForeground()) throw const ChannelVisitCancelled();
    return CommunityChannelCodec.presence(payload, scope.ownerId, channelId);
  }, isActive: isForeground);

  @override
  Stream<CommunityChannelChange> watchChanges(
    ChannelRequestScope scope,
    String? channelId,
  ) {
    // V1 advertises realtime_available=false. This adapter is dormant until an
    // independently reviewed publication/RLS contract advertises support. Its
    // payload is only an invalidation signal; RPCs remain authoritative.
    RealtimeChannel? subscription;
    var cancelled = false;
    late final StreamController<CommunityChannelChange> output;
    void emit(CommunityChannelChange value) {
      if (!cancelled && scope.isCurrent && !output.isClosed) output.add(value);
    }

    output = StreamController<CommunityChannelChange>(
      onListen: () {
        if (!scope.isCurrent) {
          unawaited(output.close());
          return;
        }
        if (channelId != null) CommunityChannelCodec.requireUuid(channelId);
        subscription = _client
            .channel(
              'bil07:${scope.ownerId}:${scope.visitGeneration}:${channelId ?? 'directory'}',
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: channelId == null
                  ? 'bil07_channels_v1'
                  : 'bil07_channel_messages_v1',
              filter: channelId == null
                  ? null
                  : PostgresChangeFilter(
                      type: PostgresChangeFilterType.eq,
                      column: 'channel_id',
                      value: channelId,
                    ),
              callback: (_) => emit(CommunityChannelChange.invalidated),
            )
            .subscribe((status, error) {
              emit(
                status == RealtimeSubscribeStatus.subscribed
                    ? CommunityChannelChange.connected
                    : CommunityChannelChange.disconnected,
              );
            });
      },
      onCancel: () async {
        cancelled = true;
        final channel = subscription;
        if (channel != null) {
          try {
            await _client.removeChannel(channel);
          } on Object {
            // The visit is already revoked; teardown cannot reissue a request.
          }
        }
      },
    );
    return output.stream;
  }
}
