part of 'community_repository.dart';

/// Removes only the authenticated participant's own mailbox copy.
/// The deployed void RPC needs an owner/RLS-bound absence readback; an HTTP
/// acknowledgement alone must not remove a still-visible local message.
extension CommunityMessageDeletion on CommunityRepository {
  Future<void> deleteMessageForCurrentUser(CommunityMessage message) =>
      _runCommunityOwnerOperation((operation) async {
        final owner = operation.ownerId;
        if (owner == null) throw const AuthException('Sign-in required');
        if (!CommunityRepository._uuid.hasMatch(message.id) ||
            !CommunityRepository._uuid.hasMatch(message.senderId) ||
            !CommunityRepository._uuid.hasMatch(message.recipientId) ||
            message.senderId == message.recipientId ||
            (message.senderId != owner && message.recipientId != owner)) {
          throw ArgumentError('Invalid participant message deletion');
        }
        final before = await _messageDeletionReadback(message.id, owner);
        operation.check();
        if (before == null) return; // Already absent from this actor's mailbox.
        _checkMessageDeletionIdentity(before, message);
        await deleteMessage(message.id);
        operation.check();
        final after = await _messageDeletionReadback(message.id, owner);
        operation.check();
        if (after != null) {
          _checkMessageDeletionIdentity(after, message);
          throw StateError('Message removal could not be confirmed');
        }
      });

  /// Sender-owned erasure is distinct from mailbox hiding. Even a row already
  /// hidden for this sender must reach the guarded server erasure RPC.
  Future<void> _deleteMessageForEveryoneOwned(CommunityMessage message) =>
      _runCommunityOwnerOperation((operation) async {
        final owner = operation.ownerId;
        if (owner == null) throw const AuthException('Sign-in required');
        if (!CommunityRepository._uuid.hasMatch(message.id) ||
            !CommunityRepository._uuid.hasMatch(message.recipientId) ||
            message.senderId != owner ||
            message.recipientId == owner) {
          throw ArgumentError('Invalid sender message erasure');
        }
        final before = await _messageDeletionReadback(message.id, owner);
        operation.check();
        if (before != null) _checkMessageDeletionIdentity(before, message);
        await _client.rpc(
          'bil_delete_message_for_everyone_v1',
          params: {'p_message_id': message.id},
        );
        operation.check();
        final after = await _messageDeletionReadback(message.id, owner);
        operation.check();
        if (after != null) {
          _checkMessageDeletionIdentity(after, message);
          throw StateError('Message erasure could not be confirmed');
        }
      });

  /// RLS presence for already loaded older rows. Absence removes stale local
  /// text after an erasure/hide; it never manufactures relationship statuses.
  Future<Set<String>> _loadVisibleConversationMessageIds(
    String peer,
    List<String> messageIds,
  ) => _runCommunityOwnerOperation((operation) async {
    final owner = operation.ownerId;
    if (owner == null) throw const AuthException('Sign-in required');
    final ids = messageIds.toSet();
    if (!CommunityRepository._uuid.hasMatch(peer) ||
        peer == owner ||
        ids.length > 200 ||
        ids.any((id) => !CommunityRepository._uuid.hasMatch(id))) {
      throw ArgumentError('Invalid conversation visibility readback');
    }
    if (ids.isEmpty) return <String>{};
    final rows = await _client
        .from('bil_messages')
        .select('id,sender_id,recipient_id')
        .inFilter('id', ids.toList())
        .or(
          'and(sender_id.eq.$owner,recipient_id.eq.$peer),and(sender_id.eq.$peer,recipient_id.eq.$owner)',
        );
    operation.check();
    final visible = <String>{};
    for (final row in rows) {
      if (!ids.contains(row['id']) ||
          !((row['sender_id'] == owner && row['recipient_id'] == peer) ||
              (row['sender_id'] == peer && row['recipient_id'] == owner))) {
        throw const FormatException('Conversation visibility identity changed');
      }
      visible.add(row['id'] as String);
    }
    return Set<String>.unmodifiable(visible);
  });

  Future<Map<String, dynamic>?> _messageDeletionReadback(
    String messageId,
    String owner,
  ) => _client
      .from('bil_messages')
      // These existing columns work without expanding any SELECT grant.
      .select('id,sender_id,recipient_id')
      .eq('id', messageId)
      .or('sender_id.eq.$owner,recipient_id.eq.$owner')
      .maybeSingle();

  void _checkMessageDeletionIdentity(
    Map<String, dynamic> row,
    CommunityMessage message,
  ) {
    if (row['id'] != message.id ||
        row['sender_id'] != message.senderId ||
        row['recipient_id'] != message.recipientId) {
      throw const FormatException('Message removal identity changed');
    }
  }
}
