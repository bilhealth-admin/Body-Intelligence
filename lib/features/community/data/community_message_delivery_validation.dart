part of 'community_repository.dart';

// Pure validation shared by scoped message reads and verified delivery.
// RPC execution and owner/generation guards stay in the repository mixin.

String newCommunityMessageRequestId() => const Uuid().v4();

/// Server rejected recipient eligibility, independently of connectivity.
/// Keep the server's friendship, privacy and block checks authoritative.
class CommunityMessageRecipientUnavailable implements Exception {
  const CommunityMessageRecipientUnavailable();
}

class CommunityMessageDeliveryUnavailable implements Exception {
  const CommunityMessageDeliveryUnavailable();
}

/// A verified prior request was delivered and later removed. Never resend it.
class CommunityMessageDeliveryRemoved implements Exception {
  const CommunityMessageDeliveryRemoved();
}

bool _validMessageEnvelope(String body) {
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

void _validateMessageDelivery(
  Object? response, {
  required String owner,
  required String recipient,
  required String requestId,
  required String body,
}) {
  if (response is! Map) {
    throw const FormatException('Unverified private message delivery');
  }
  final removed = response['status'] == 'removed';
  final messageId = response['message_id'];
  if ((!removed && response['status'] != 'delivered') ||
      response['owner_id'] != owner ||
      response['recipient_id'] != recipient ||
      response['request_id'] != requestId ||
      (removed ? response['body'] != null : response['body'] != body) ||
      (messageId == null
          ? !removed
          : messageId is! String ||
                !CommunityRepository._uuid.hasMatch(messageId)) ||
      response['delivered_at'] is! String ||
      DateTime.tryParse(response['delivered_at'] as String) == null) {
    throw const FormatException('Unverified private message delivery');
  }
}
