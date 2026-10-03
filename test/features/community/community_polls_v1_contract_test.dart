import 'dart:io';

import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_polls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'poll backend is owner-created, visible-post voted, and RLS isolated',
    () {
      final sql = File(
        'supabase/migrations/20261003095405_community_polls_foundation_v1.sql',
      ).readAsStringSync();
      final batch = File(
        'supabase/migrations/20261003095854_community_poll_batch_read_v1.sql',
      ).readAsStringSync();

      expect(sql, contains('create table public.bil_community_polls'));
      expect(sql, contains('create table public.bil_community_poll_options'));
      expect(sql, contains('create table public.bil_community_poll_votes'));
      expect(sql, contains('cardinality(p_options)<2'));
      expect(sql, contains('cardinality(p_options)>6'));
      expect(sql, contains("p.moderation_status='pending'"));
      expect(sql, contains('public.bil_social_post_visible_v2'));
      expect(sql, contains('bil_vote_community_poll_v1'));
      expect(sql, contains('enable row level security'));
      expect(
        sql,
        contains('revoke all on table public.bil_community_poll_votes'),
      );
      expect(batch, contains('bil_community_polls_v1'));
      expect(batch, contains('cardinality(p_post_ids)>100'));
    },
  );

  test(
    'poll models reject malformed choices and preserve poll on post copies',
    () {
      final poll = CommunityPoll.fromJson({
        'post_id': '11111111-1111-4111-8111-111111111111',
        'question': 'Which one?',
        'allow_multiple': false,
        'closes_at': null,
        'closed': false,
        'total_votes': 3,
        'options': [
          {
            'id': '22222222-2222-4222-8222-222222222222',
            'position': 0,
            'text': 'A',
            'vote_count': 2,
            'selected': true,
          },
          {
            'id': '33333333-3333-4333-8333-333333333333',
            'position': 1,
            'text': 'B',
            'vote_count': 1,
            'selected': false,
          },
        ],
      });
      expect(poll.hasSelection, isTrue);

      final post = CommunityPost(
        id: poll.postId,
        authorId: '44444444-4444-4444-8444-444444444444',
        body: 'Poll post',
        createdAt: DateTime.utc(2026, 10, 3),
        poll: poll,
      );
      final copied = post.withSaved(true).withPoll(poll);
      expect(copied.poll?.question, 'Which one?');
      expect(copied.saved, isTrue);

      expect(
        () => const CommunityPollDraft(
          question: 'Duplicate options?',
          options: ['Same', 'same'],
        ).normalized(),
        throwsFormatException,
      );
    },
  );

  test('composer and feed use server poll receipts rather than fake UI state', () {
    final repository = [
      'lib/features/community/data/community_repository.dart',
      'lib/features/community/data/community_repository_discovery_mixin.dart',
      'lib/features/community/data/community_repository_publishing_mixin.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final mixin = File(
      'lib/features/community/data/community_feed_repository_mixin.dart',
    ).readAsStringSync();
    final composer = [
      'lib/features/community/presentation/community_post_composer_page.dart',
      'lib/features/community/presentation/community_post_composer_rendering.dart',
      'lib/features/community/presentation/community_post_composer_reference_sections.dart',
      'lib/features/community/presentation/community_post_composer_reference_actions.dart',
      'lib/features/community/presentation/community_post_composer_toolbar.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final card = File(
      'lib/features/community/presentation/community_post_card.dart',
    ).readAsStringSync();
    final detail = File(
      'lib/features/community/presentation/community_post_detail_page.dart',
    ).readAsStringSync();
    final panel = File(
      'lib/features/community/presentation/community_poll_panel.dart',
    ).readAsStringSync();

    expect(repository, contains('bil_create_my_community_poll_v1'));
    expect(repository, contains('bil_vote_community_poll_v1'));
    expect(repository, contains('bil_community_polls_v1'));
    expect(repository, contains('publishPostWithTopicsCircleAndPoll'));
    expect(repository, contains('publishPostWithImageTopicsCircleAndPoll'));
    expect(mixin, contains('loadCommunityPolls(postIds)'));
    expect(composer, contains('community-composer-poll-toggle'));
    expect(composer, contains('community-composer-poll-question'));
    expect(composer, contains('community-composer-poll-add-option'));
    expect(card, contains('_CommunityPollPanel'));
    expect(detail, contains('_CommunityPollPanel'));
    expect(panel, contains('voteCommunityPoll'));
    expect(panel, contains('community-poll-option-'));
  });
}
