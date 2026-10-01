import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('community helper RPCs remain actor scoped and fail closed', () {
    final sql = File(
      'supabase/migrations/20261001031127_harden_community_helper_rpc_scope.sql',
    ).readAsStringSync();

    expect(sql, contains('v_actor_id uuid := (select auth.uid())'));
    expect(
      sql,
      contains("v_role text := coalesce((select auth.jwt()->>'role'), '')"),
    );
    expect(
      sql,
      contains('p_excluded_user_id is distinct from v_actor_id'),
    );
    expect(sql, contains('community_moderator_lookup_scope_denied'));
    expect(sql, contains("using errcode = '42501'"));

    expect(sql, contains("friendship.status = 'accepted'"));
    expect(sql, contains('friendship.requester_id = v_actor_id'));
    expect(sql, contains('friendship.addressee_id = v_actor_id'));
    expect(sql, contains('if v_actor_id is null then'));
    expect(sql, contains('return false;'));
  });
}
