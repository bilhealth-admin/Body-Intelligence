import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('social interactions emit durable Activity without exposing saves', () {
    final sql = File(
      'supabase/migrations/20261003094723_community_social_activity_emitters_v1.sql',
    ).readAsStringSync();

    expect(sql, contains('private.bil_activity_pair_allowed_v1'));
    expect(sql, contains('private.bil_emit_post_like_activity_v1'));
    expect(sql, contains('private.bil_emit_post_save_activity_v1'));
    expect(sql, contains('private.bil_emit_comment_activity_v1'));
    expect(sql, contains('private.bil_emit_follow_activity_v1'));
    expect(sql, contains("'post_like'"));
    expect(sql, contains("'post_save'"));
    expect(sql, contains("'comment'"));
    expect(sql, contains("'reply'"));
    expect(sql, contains("'follow'"));
    expect(sql, contains("'post_like_v1'"));
    expect(sql, contains("'post_save_v1'"));
    expect(sql, contains("'post_comment_v1'"));
    expect(sql, contains("'comment_reply_v1'"));
    expect(sql, contains("'profile_follow_v1'"));
    expect(sql, contains("v_recipient,null,'post_save'"));
    expect(sql, contains('public.bil_blocks'));
    expect(sql, contains('private.bil_community_member_access'));
    expect(sql, contains('bil_social_post_like_activity_v1'));
    expect(sql, contains('bil_social_post_save_activity_v1'));
    expect(sql, contains('bil_social_comment_activity_v1'));
    expect(sql, contains('bil_follow_activity_v1'));
    expect(
      sql,
      isNot(contains('grant execute on function private.bil_emit_post_like')),
    );
  });
}
