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
