import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quest rewards are server-authoritative and fail closed by default', () {
    final sql = File(
      'supabase/migrations/20261003035646_community_quest_reward_engine_v1.sql',
    ).readAsStringSync();

    expect(sql, contains('create table public.bil_community_reward_policy'));
    expect(sql, contains('create table public.bil_community_quest_definitions'));
    expect(sql, contains('create table public.bil_community_quest_progress'));
    expect(
      sql,
      contains('create table public.bil_community_quest_progress_events'),
    );
    expect(
      sql,
      contains('create table public.bil_community_reward_claim_audit'),
    );
    expect(sql, contains('max_quest_gold_per_owner_per_utc_day bigint not null default 0'));
    expect(sql, contains('max_quest_xp_per_owner_per_utc_day bigint not null default 0'));
    expect(sql, contains('active boolean not null default false'));
    expect(sql, contains('private.bil_record_community_action_v1'));
    expect(sql, contains('private.bil_record_community_quest_progress_v1'));
    expect(sql, contains('private.bil_settle_community_quest_reward_v1'));
    expect(sql, contains('private.bil_post_gold_ledger_v1'));
    expect(sql, contains('private.bil_post_community_xp_v1'));
    expect(sql, contains('private.bil_emit_community_activity_v2'));
    expect(sql, contains('public.bil_list_community_quests_v1()'));
    expect(sql, contains('public.bil_claim_community_quest_v1'));
    expect(sql, contains("'ready_to_claim'"));
    expect(sql, contains("'claimed'"));
    expect(sql, contains("'manual'"));
    expect(sql, contains("'auto'"));
    expect(sql, contains("'quest_completed'"));
    expect(sql, contains("'reward_earned'"));
    expect(sql, contains('quest_progress_source_invalid'));
    expect(sql, contains('community_reward_claim_audit'));
    expect(
      sql,
      isNot(contains('grant execute on function private.bil_record_community')),
    );
  });
}
