import 'community_channel_models.dart';

abstract interface class CommunityChannelsRepository {
  String? get currentOwnerId;
  Stream<String?> get ownerChanges;

  Future<CommunityChannelCapabilities> loadCapabilities(
    ChannelRequestScope scope,
  );
  Future<CommunityChannelDirectory> loadDirectory(
    ChannelRequestScope scope, {
    String? afterId,
    int limit = 50,
  });
  Future<CommunityChannelMessagePage> loadMessages(
    ChannelRequestScope scope,
    String channelId, {
    int? beforeSequence,
    int? afterSequence,
    int limit = 50,
  });
  Future<CommunityChannelMessage> send(
    ChannelRequestScope scope,
    CommunityChannelSendAttempt attempt,
  );
  Future<CommunityChannelReadback> acknowledgeVisible(
    ChannelRequestScope scope,
    String channelId,
    List<String> messageIds,
  );
  Future<CommunityChannelPresence> loadPresence(
    ChannelRequestScope scope,
    String channelId, {
    required bool heartbeat,
    required bool Function() isForeground,
  });

  /// Realtime is an invalidation hint, never an authoritative message/read or
  /// membership payload. Every reconnect is reconciled using the RPC contract.
  Stream<CommunityChannelChange> watchChanges(
    ChannelRequestScope scope,
    String? channelId,
  );
}
