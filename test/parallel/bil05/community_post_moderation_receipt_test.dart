import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/community/activity_rewards/community_post_moderation_receipt.dart';

void main() {
  const postId = '11111111-1111-4111-8111-111111111111';

  test('accepts server-confirmed +5 AI token receipt', () {
    final receipt = CommunityPostModerationReceipt.tryParse(
      entityKind: 'post',
      entityId: postId,
      copyKey: 'post_approved_ai_tokens_v1',
      metadata: const {
        'receipt_kind': 'post_moderation',
        'post_id': postId,
        'decision': 'approved',
        'ai_tokens_granted': 5,
        'reward_reason': 'granted',
      },
    );

    expect(receipt, isNotNull);
    expect(receipt!.hasConfirmedAiGrant, isTrue);
    expect(receipt.aiTokensGranted, 5);
    expect(receipt.route, '/community/post/$postId');
  });

  test('approved daily-cap receipt does not promise AI tokens', () {
    final receipt = CommunityPostModerationReceipt.tryParse(
      entityKind: 'post',
      entityId: postId,
      copyKey: 'post_approved_no_ai_tokens_v1',
      metadata: const {
        'receipt_kind': 'post_moderation',
        'post_id': postId,
        'decision': 'approved',
        'ai_tokens_granted': 0,
        'reward_reason': 'daily_cap_reached',
      },
    );

    expect(receipt, isNotNull);
    expect(receipt!.hasConfirmedAiGrant, isFalse);
    expect(receipt.aiTokensGranted, 0);
  });

  test('rejected receipt is a post result, never an AI grant', () {
    final receipt = CommunityPostModerationReceipt.tryParse(
      entityKind: 'post',
      entityId: postId,
      copyKey: 'post_rejected_v1',
      metadata: const {
        'receipt_kind': 'post_moderation',
        'post_id': postId,
        'decision': 'rejected',
        'ai_tokens_granted': 0,
        'reward_reason': 'not_applicable',
      },
    );

    expect(receipt, isNotNull);
    expect(receipt!.decision, CommunityPostModerationReceiptDecision.rejected);
    expect(receipt.hasConfirmedAiGrant, isFalse);
  });

  test('rejects +5 claim without a granted server reason', () {
    final receipt = CommunityPostModerationReceipt.tryParse(
      entityKind: 'post',
      entityId: postId,
      copyKey: 'post_approved_ai_tokens_v1',
      metadata: const {
        'receipt_kind': 'post_moderation',
        'post_id': postId,
        'decision': 'approved',
        'ai_tokens_granted': 5,
        'reward_reason': 'daily_cap_reached',
      },
    );

    expect(receipt, isNull);
  });

  test('rejects mismatched post identity', () {
    final receipt = CommunityPostModerationReceipt.tryParse(
      entityKind: 'post',
      entityId: postId,
      copyKey: 'post_approved_ai_tokens_v1',
      metadata: const {
        'receipt_kind': 'post_moderation',
        'post_id': '22222222-2222-4222-8222-222222222222',
        'decision': 'approved',
        'ai_tokens_granted': 5,
        'reward_reason': 'granted',
      },
    );

    expect(receipt, isNull);
  });
}
