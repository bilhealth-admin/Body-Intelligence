import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('referral attribution is fail-closed and reward-safe', () {
    final sql = File(
      'supabase/migrations/20261003080333_community_referral_attribution_foundation_v1.sql',
    ).readAsStringSync();

    expect(sql, contains('create table public.bil_community_referral_policy'));
    expect(sql, contains('create table public.bil_community_invites'));
    expect(
      sql,
      contains('create table public.bil_community_referral_attributions'),
    );
    expect(sql, contains('invite_links_enabled boolean not null default false'));
    expect(
      sql,
      contains('reward_progress_enabled boolean not null default false'),
    );
    expect(sql, contains("token_hash ~ '^[0-9a-f]{64}$'"));
    expect(sql, contains("p_token !~ '^[0-9a-f]{48}$'"));
    expect(sql, contains('inviter_id<>invitee_id'));
    expect(sql, contains('invitee_id uuid not null unique'));
    expect(sql, contains("integrity_state in ('pending','verified','rejected')"));
    expect(sql, contains('private.bil_record_community_action_v1'));
    expect(sql, contains("'invite_friend_qualified'"));
    expect(sql, contains("'referral-qualified:'"));
    expect(sql, contains('bil_friendship_referral_qualification'));
    expect(sql, contains('bil_set_community_referral_integrity_v1'));
    expect(sql, contains("auth.role()<>'service_role'"));
    expect(sql, contains('bil_reconcile_community_referral_v1'));
    expect(sql, contains('grant execute on function public.bil_preview_community_invite_v1(text)'));
    expect(sql, contains('to anon,authenticated'));
    expect(
      sql,
      contains(
        'revoke all on function private.bil_maybe_record_referral_reward_progress_v1(uuid)',
      ),
    );
    expect(sql, isNot(contains('bil_post_gold_ledger_v1(')));
    expect(sql, isNot(contains('bil_ai_credit_balances')));
  });
}