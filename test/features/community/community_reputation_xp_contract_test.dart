import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Community XP is permanent reputation, not spendable currency', () {
    final sql = File(
      'supabase/migrations/20261003030729_community_reputation_xp_foundation_v1.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create table public.bil_community_reputation_accounts'),
    );
    expect(sql, contains('create table public.bil_community_xp_ledger'));
    expect(sql, contains('create table public.bil_community_level_policy'));
    expect(sql, contains('private.bil_post_community_xp_v1'));
    expect(sql, contains('bil_community_xp_owner_idempotency_key'));
    expect(sql, contains('bil_community_xp_single_reversal_idx'));
    expect(sql, contains('bil_community_xp_no_negative_awards'));
    expect(sql, contains('community_xp_negative_award_forbidden'));
    expect(sql, contains('public.bil_community_my_reputation_v1()'));
    expect(sql, contains("values(1,0,'community_level_1',true)"));
    expect(sql, isNot(contains('bil_gold_ledger')));
    expect(sql, isNot(contains('bil_ai_credit_balances')));
    expect(sql, isNot(contains('bil_subscriptions')));
  });
}
