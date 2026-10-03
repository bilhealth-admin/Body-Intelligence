import 'dart:io';

import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_post_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'post context backend is bounded and mention notifications wait for approval',
    () {
      final sql = File(
        'supabase/migrations/20261003105229_community_post_context_mentions_v1.sql',
      ).readAsStringSync();

      expect(sql, contains('location_label text'));
      expect(sql, contains('char_length(location_label) between 1 and 80'));
      expect(
        sql,
        contains('create table public.bil_community_post_mentions_v1'),
      );
      expect(sql, contains('bil_search_community_mentions_v1'));
      expect(sql, contains('bil_set_my_community_post_context_v1'));
      expect(sql, contains('v_requested>10'));
      expect(sql, contains('community_mention_target_unavailable'));
      expect(sql, contains("new.moderation_status='approved'"));
      expect(sql, contains("'mention'"));
      expect(sql, contains("'post_mention_v1'"));
      expect(sql, contains('private.bil_activity_pair_allowed_v1'));
      expect(sql, contains('enable row level security'));
      expect(sql, isNot(contains('latitude')));
      expect(sql, isNot(contains('longitude')));
      expect(sql, isNot(contains('gps')));
    },
  );

  test('mention candidate and post context parsers stay strict', () {
    final candidate = CommunityMentionCandidate.fromJson({
      'user_id': '11111111-1111-4111-8111-111111111111',
      'handle': 'bil_member',
      'display_name': 'BIL Member',
      'avatar_url': null,
    });
    expect(candidate.handle, 'bil_member');

    final context = CommunityPostContextDraft(
      locationLabel: ' Cairo ',
      mentions: [candidate],
    ).normalized();
    expect(context.locationLabel, 'Cairo');
    expect(context.mentionedUserIds, [candidate.userId]);

    expect(
      () => CommunityPostContextDraft(
        locationLabel: List<String>.filled(81, 'x').join(),
      ).normalized(),
      throwsFormatException,
    );
  });

  test('Community post keeps location and Activity parses mention', () {
    final post = CommunityPost.fromJson({
      'id': '11111111-1111-4111-8111-111111111111',
      'author_id': '22222222-2222-4222-8222-222222222222',
      'body': 'A post',
      'created_at': '2026-10-03T10:00:00Z',
      'location_label': 'Cairo',
      'moderation_status': 'approved',
      'moderation_visibility': 'visible',
    });
    expect(post.locationLabel, 'Cairo');
    expect(post.withSaved(true).locationLabel, 'Cairo');
    expect(
      CommunityNotificationKind.fromWire('mention'),
      CommunityNotificationKind.mention,
    );
  });

  test(
    'Flutter composer exposes manual location and mention search without GPS',
    () {
      final repository = File(
        'lib/features/community/data/community_repository.dart',
      ).readAsStringSync();
      final composer = File(
        'lib/features/community/presentation/community_post_composer_page.dart',
      ).readAsStringSync();
      final card = File(
        'lib/features/community/presentation/community_post_card.dart',
      ).readAsStringSync();
      final detail = File(
        'lib/features/community/presentation/community_post_detail_page.dart',
      ).readAsStringSync();

      expect(repository, contains('bil_search_community_mentions_v1'));
      expect(repository, contains('bil_set_my_community_post_context_v1'));
      expect(repository, contains('publishRichPost'));
      expect(composer, contains('community-composer-location'));
      expect(composer, contains('community-composer-mention-query'));
      expect(composer, contains('community-composer-mention-search'));
      expect(composer, contains('BIL does not request GPS'));
      expect(card, contains('community-post-location-'));
      expect(detail, contains('community-post-detail-location'));
      expect(composer, isNot(contains('Geolocator')));
      expect(composer, isNot(contains('requestPermission')));
    },
  );
}
