/// Typed projection of the durable post-moderation Activity receipt.
///
/// This model never grants currency. `aiTokensGranted == 5` is accepted only
/// when the server receipt itself declares the granted reward reason.
enum CommunityPostModerationReceiptDecision { approved, rejected }

class CommunityPostModerationReceipt {
  const CommunityPostModerationReceipt({
    required this.postId,
    required this.decision,
    required this.aiTokensGranted,
    required this.rewardReason,
  });

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final String postId;
  final CommunityPostModerationReceiptDecision decision;
  final int aiTokensGranted;
  final String rewardReason;

  bool get hasConfirmedAiGrant =>
      decision == CommunityPostModerationReceiptDecision.approved &&
      aiTokensGranted == 5 &&
      rewardReason == 'granted';

  String get route => '/community/post/$postId';

  static CommunityPostModerationReceipt? tryParse({
    required String entityKind,
    required String entityId,
    required String copyKey,
    required Map<String, dynamic> metadata,
  }) {
    if (entityKind != 'post' || !_uuid.hasMatch(entityId)) return null;
    if (metadata['receipt_kind'] != 'post_moderation' ||
        metadata['post_id'] != entityId) {
      return null;
    }

    final decision = switch (metadata['decision']) {
      'approved' => CommunityPostModerationReceiptDecision.approved,
      'rejected' => CommunityPostModerationReceiptDecision.rejected,
      _ => null,
    };
    final rawTokens = metadata['ai_tokens_granted'];
    final rewardReason = metadata['reward_reason'];
    if (decision == null ||
        rawTokens is! num ||
        rawTokens % 1 != 0 ||
        !const {0, 5}.contains(rawTokens.toInt()) ||
        rewardReason is! String ||
        rewardReason.isEmpty) {
      return null;
    }
    final tokens = rawTokens.toInt();

    final valid = switch (copyKey) {
      'post_approved_ai_tokens_v1' =>
        decision == CommunityPostModerationReceiptDecision.approved &&
            tokens == 5 &&
            rewardReason == 'granted',
      'post_approved_no_ai_tokens_v1' =>
        decision == CommunityPostModerationReceiptDecision.approved &&
            tokens == 0,
      'post_rejected_v1' =>
        decision == CommunityPostModerationReceiptDecision.rejected &&
            tokens == 0,
      _ => false,
    };
    if (!valid) return null;

    return CommunityPostModerationReceipt(
      postId: entityId,
      decision: decision,
      aiTokensGranted: tokens,
      rewardReason: rewardReason,
    );
  }
}
