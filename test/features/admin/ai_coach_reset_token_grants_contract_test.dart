import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260904010000_ai_coach_reset_token_grants.sql';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(_migrationPath).readAsStringSync();
  });

  test('reset grant ledger and insert trigger are pair-idempotent', () {
    expect(sql, startsWith('begin;'));
    expect(sql.trimRight(), endsWith('commit;'));
    expect(sql, contains('private.bil_ai_coach_reset_token_grants'));
    expect(sql, contains('primary key (reset_id, owner_id)'));
    expect(sql, contains('check (tokens = 2500)'));
    expect(sql, contains('on conflict (reset_id, owner_id) do nothing'));
    expect(sql, contains('after insert on public.bil_ai_coach_reset_notices'));
    expect(sql, contains('get diagnostics v_inserted = row_count'));
  });

  test('grant changes only granted and never rewrites consumption', () {
    final trigger = _between(
      sql,
      'create or replace function private.bil_grant_ai_coach_reset_tokens()',
      'revoke all on function private.bil_grant_ai_coach_reset_tokens()',
    );

    expect(
      trigger,
      contains('insert into public.bil_ai_credit_balances(owner_id, granted)'),
    );
    expect(
      trigger,
      contains(
        'granted = public.bil_ai_credit_balances.granted + excluded.granted',
      ),
    );
    expect(trigger, isNot(contains('used =')));
    expect(trigger, isNot(contains('reserved =')));
  });

  test('repair grants only the latest unread reset within fourteen days', () {
    final repair = _between(sql, 'with ranked_unread as (', '-- Preserve');

    expect(repair, contains('partition by n.owner_id'));
    expect(repair, contains('order by n.created_at desc, n.reset_id desc'));
    expect(repair, contains('n.seen_at is null'));
    expect(repair, contains("now() - interval '14 days'"));
    expect(repair, contains('where r.owner_rank = 1'));
    expect(repair, contains('returning owner_id, tokens'));
    expect(repair, isNot(contains('used =')));
    expect(repair, isNot(contains('reserved =')));
  });

  test('authored gift copy requires service role and an active admin', () {
    final mutation = _between(
      sql,
      'create or replace function public.bil_enqueue_admin_notification_with_message(',
      'revoke all on function public.bil_enqueue_admin_notification_with_message(',
    );

    expect(mutation, contains("<> 'service_role'"));
    expect(
      mutation,
      contains(
        "v_kind text := lower(trim(coalesce(p_notification_kind, '')));",
      ),
    );
    expect(
      mutation,
      contains("v_message text := trim(coalesce(p_message, ''));"),
    );
    expect(mutation, contains('private.bil_ai_coach_admins'));
    expect(mutation, contains('a.user_id = p_actor_id and a.active'));
    expect(mutation, contains("v_kind not in ('compensation', 'gift')"));
    expect(mutation, contains("p_actor_id,\n    'custom',"));
    expect(mutation, contains('v_message,'));
    expect(mutation, contains('set notification_kind = v_kind'));
    expect(mutation, isNot(contains('set body =')));
    expect(
      sql,
      contains(
        'grant execute on function public.bil_enqueue_admin_notification_with_message(',
      ),
    );
  });

  test('reset wrappers keep the custom message in the atomic reset', () {
    expect(sql, contains('add column if not exists message text'));
    expect(sql, contains('add column if not exists custom_message text'));
    final wrappers = [
      _between(
        sql,
        'create or replace function public.bil_global_reset_ai_coach(',
        'create or replace function public.bil_individual_reset_ai_coach(',
      ),
      _between(
        sql,
        'create or replace function public.bil_individual_reset_ai_coach(',
        'revoke all on function public.bil_global_reset_ai_coach(',
      ),
    ];
    for (final wrapper in wrappers) {
      expect(wrapper, contains('p_message text'));
      expect(wrapper, contains("raise exception 'invalid_reset_message'"));
      expect(wrapper, contains("'boost_tokens_per_recipient', 2500"));
      expect(wrapper, contains("'custom_message_applied', true"));
      expect(wrapper, contains('idempotency_key_request_mismatch'));
    }
    expect(sql, contains('set message = v_message'));
    expect(sql, contains('set body = v_message'));
    expect(
      sql,
      contains(
        'grant execute on function public.bil_global_reset_ai_coach(uuid, text, text)',
      ),
    );
    expect(
      sql,
      contains(
        'revoke execute on function public.bil_global_reset_ai_coach(uuid, text)',
      ),
    );
  });
}

String _between(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(start, greaterThanOrEqualTo(0), reason: startMarker);
  expect(end, greaterThan(start), reason: endMarker);
  return source.substring(start, end);
}
