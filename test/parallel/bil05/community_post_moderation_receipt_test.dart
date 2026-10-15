import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/community/activity_rewards/community_post_moderation_receipt.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/presentation/community_notification_destination.dart';

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

  test(
    'enriched canonical legacy reward keeps its copy key and typed receipt',
    () {
      const oldMetadata = {
        'currency': 'ai_tokens',
        'tokens': 5,
        'decision': 'approved',
        'receipt_id': '22222222-2222-4222-8222-222222222222',
      };
      expect(
        CommunityPostModerationReceipt.tryParse(
          entityKind: 'post',
          entityId: postId,
          copyKey: 'community_post_ai_reward_v1',
          metadata: oldMetadata,
        ),
        isNull,
      );
      final receipt = CommunityPostModerationReceipt.tryParse(
        entityKind: 'post',
        entityId: postId,
        copyKey: 'community_post_ai_reward_v1',
        metadata: const {
          ...oldMetadata,
          'receipt_kind': 'post_moderation',
          'post_id': postId,
          'ai_tokens_granted': 5,
          'reward_reason': 'granted',
        },
      );
      expect(receipt?.hasConfirmedAiGrant, isTrue);
      expect(receipt?.route, '/community/post/$postId');
    },
  );

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

  test(
    'review receipts use activity kinds already understood by old clients',
    () {
      final approved = CommunityNotification.fromJson({
        'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'kind': 'reward_earned',
        'actor_id': null,
        'actor_display_name': null,
        'actor_avatar_url': null,
        'friendship_id': null,
        'entity_kind': 'post',
        'entity_id': postId,
        'copy_key': 'post_approved_ai_tokens_v1',
        'deep_link_path': '/community/post/$postId',
        'metadata': {
          'receipt_kind': 'post_moderation',
          'post_id': postId,
          'decision': 'approved',
          'ai_tokens_granted': 5,
          'reward_reason': 'granted',
        },
        'created_at': '2026-10-14T12:00:00Z',
        'seen_at': null,
      });
      expect(approved.kind, CommunityNotificationKind.rewardEarned);
      final approvedReceipt = CommunityPostModerationReceipt.tryParse(
        entityKind: approved.entityKind,
        entityId: approved.entityId,
        copyKey: approved.copyKey,
        metadata: approved.metadata,
      );
      expect(approvedReceipt?.hasConfirmedAiGrant, isTrue);
      expect(approvedReceipt?.route, '/community/post/$postId');

      final rejected = CommunityNotification.fromJson({
        'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'kind': 'comment',
        'actor_id': null,
        'actor_display_name': null,
        'actor_avatar_url': null,
        'friendship_id': null,
        'entity_kind': 'post',
        'entity_id': postId,
        'copy_key': 'post_rejected_v1',
        'deep_link_path': '/community/post/$postId',
        'metadata': {
          'receipt_kind': 'post_moderation',
          'post_id': postId,
          'decision': 'rejected',
          'ai_tokens_granted': 0,
          'reward_reason': 'not_applicable',
        },
        'created_at': '2026-10-14T12:01:00Z',
        'seen_at': null,
      });
      expect(rejected.kind, CommunityNotificationKind.comment);
      expect(
        CommunityNotificationDestination.contentRoute(rejected),
        '/community/content/$postId',
      );
      final rejectedReceipt = CommunityPostModerationReceipt.tryParse(
        entityKind: rejected.entityKind,
        entityId: rejected.entityId,
        copyKey: rejected.copyKey,
        metadata: rejected.metadata,
      );
      expect(
        rejectedReceipt?.decision,
        CommunityPostModerationReceiptDecision.rejected,
      );
      expect(rejectedReceipt?.route, '/community/post/$postId');
    },
  );
}
