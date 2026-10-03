import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Activity v2 expands durable events without breaking v1 clients', () {
    final sql = File(
      'supabase/migrations/20261003031504_community_activity_v2_compatibility_foundation.sql',
    ).readAsStringSync();

    expect(sql, contains('add column entity_kind text'));
    expect(sql, contains('add column entity_id text'));
    expect(sql, contains('add column copy_key text'));
    expect(sql, contains('add column deep_link_path text'));
    expect(
      sql,
      contains("add column metadata jsonb not null default '{}'::jsonb"),
    );
    expect(sql, contains("'reward_earned'"));
    expect(sql, contains("'quest_completed'"));
    expect(sql, contains("'badge_earned'"));
    expect(sql, contains("'challenge_update'"));
    expect(sql, contains("and n.kind='friend_accepted'"));
    expect(sql, contains('public.bil_list_community_activity_v2'));
    expect(sql, contains('public.bil_mark_community_activity_seen_v2'));
    expect(sql, contains('private.bil_attention_snapshot_v2'));
    expect(sql, contains('public.bil_community_attention_v2()'));
    expect(sql, contains("'activity_unseen_by_kind'"));
    expect(
      sql,
      contains('bil_community_notifications_recipient_history_v2_idx'),
    );
    expect(
      sql,
      contains('bil_community_notifications_recipient_kind_unseen_v2_idx'),
    );
    expect(sql, contains("'friendship'"));
    expect(sql, contains("'friend_accepted_v1'"));
    expect(sql, contains("'/community/notifications'"));
  });
}
