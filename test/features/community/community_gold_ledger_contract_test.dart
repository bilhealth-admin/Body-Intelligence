import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BIL Gold is an isolated immutable-ledger economy contract', () {
    final sql = File(
      'supabase/migrations/20261003030031_community_gold_ledger_foundation_v1.sql',
    ).readAsStringSync();

    expect(sql, contains('create table public.bil_gold_accounts'));
    expect(sql, contains('create table public.bil_gold_ledger'));
    expect(sql, contains('private.bil_post_gold_ledger_v1'));
    expect(sql, contains('bil_gold_ledger_owner_idempotency_key'));
    expect(sql, contains('bil_gold_ledger_single_reversal_idx'));
    expect(sql, contains('gold_idempotency_payload_mismatch'));
    expect(sql, contains('gold_insufficient_balance'));
    expect(
      sql,
      contains(
        'alter table public.bil_gold_accounts enable row level security',
      ),
    );
    expect(
      sql,
      contains('alter table public.bil_gold_ledger enable row level security'),
    );
    expect(sql, contains('revoke all on table public.bil_gold_accounts'));
    expect(sql, contains('revoke all on table public.bil_gold_ledger'));
    expect(sql, contains('public.bil_gold_balance_v1()'));
    expect(sql, contains('public.bil_gold_history_v1'));
    expect(sql, isNot(contains('bil_ai_credit_balances')));
    expect(sql, isNot(contains('bil_subscriptions')));
    expect(sql, isNot(contains('bil_entitlements')));
  });
}
