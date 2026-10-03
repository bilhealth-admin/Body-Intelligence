import 'dart:io';

import 'package:body_intelligence_log/features/community/domain/community_comment_threads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('comment threads v3 page roots and replies independently', () {
    final sql = File(
      'supabase/migrations/20261003121612_community_comment_threads_v3.sql',
    ).readAsStringSync();

    expect(sql, contains('bil_social_comments_root_page_v3'));
    expect(sql, contains('bil_social_comments_reply_page_v3'));
    expect(sql, contains('bil_social_comment_threads_v3'));
    expect(sql, contains('bil_social_comment_replies_v3'));
    expect(sql, contains('reply_count'));
    expect(sql, contains('limit 3'));
    expect(sql, contains('public.bil_social_post_visible_v2'));
    expect(sql, contains('public.bil_social_member_visible_v2'));
    expect(
      sql,
      contains(
        'grant execute on function public.bil_social_comment_threads_v3',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.bil_social_comment_replies_v3',
      ),
    );
  });

  test(
    'thread parser keeps authoritative reply count separate from preview',
    () {
      final thread = CommunityCommentThread.fromJson({
        'root': {
          'id': '11111111-1111-4111-8111-111111111111',
          'author_id': '22222222-2222-4222-8222-222222222222',
          'parent_id': null,
          'body': 'Root',
          'created_at': '2026-10-03T12:00:00Z',
          'author_name': 'Root member',
          'avatar_url': null,
          'handle': 'root_member',
          'like_count': 2,
          'liked': false,
          'reply_count': 4,
        },
        'replies': [
          {
            'id': '33333333-3333-4333-8333-333333333333',
            'author_id': '44444444-4444-4444-8444-444444444444',
            'parent_id': '11111111-1111-4111-8111-111111111111',
            'body': 'Reply',
            'created_at': '2026-10-03T12:01:00Z',
            'author_name': 'Reply member',
            'avatar_url': null,
            'handle': 'reply_member',
            'like_count': 0,
            'liked': false,
            'reply_count': 0,
          },
        ],
        'reply_count': 4,
        'root_created_at': '2026-10-03T12:00:00Z',
        'root_id': '11111111-1111-4111-8111-111111111111',
      });

      expect(thread.root.replyCount, 4);
      expect(thread.replyCount, 4);
      expect(thread.replies, hasLength(1));
      expect(thread.hasHiddenReplies, isTrue);
    },
  );

  test('post detail uses collapsed server-paged replies', () {
    final repository = File(
      'lib/features/community/data/community_social_repository_mixin.dart',
    ).readAsStringSync();
    final detail = File(
      'lib/features/community/presentation/community_post_detail_page.dart',
    ).readAsStringSync();

    expect(repository, contains('bil_social_comment_threads_v3'));
    expect(repository, contains('bil_social_comment_replies_v3'));
    expect(detail, contains('loadPostCommentThreads'));
    expect(detail, contains('loadCommentReplies'));
    expect(detail, contains('community-comment-view-replies-'));
    expect(detail, contains('community-comment-load-replies-'));
    expect(detail, contains('community-comment-hide-replies-'));
    expect(detail, isNot(contains('communityCommentsInThreadOrder(_comments')));
  });
}
