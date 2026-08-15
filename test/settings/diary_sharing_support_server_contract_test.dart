import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/migrations/202608110002_bil_diary_sharing_and_support_contracts.sql',
    ).readAsStringSync().toLowerCase();
  });

  test('diary sharing is owner-private at table level and RPC-authorized', () {
    expect(sql, contains('bil_diary_share_settings enable row level security'));
    expect(
      sql,
      contains('bil_shared_diary_snapshots enable row level security'),
    );
    expect(
      sql,
      contains("visibility in ('private', 'friends', 'public', 'locked')"),
    );
    expect(sql, contains("f.status = 'accepted'"));
    expect(sql, contains('from public.bil_blocks'));
    expect(sql, contains("v_settings.visibility = 'locked'"));
    expect(sql, contains(r"access_key_sha256 ~ '^[0-9a-f]{64}$'"));
    expect(sql, contains('v_viewer = p_owner_id'));
    expect(sql, contains('if not v_allowed then return null'));
    expect(sql, contains('revoke all on public.bil_diary_share_settings'));
    expect(sql, contains('from public, anon'));
  });

  test(
    'publishing is authenticated, bounded, revision-aware, and owner-bound',
    () {
      expect(sql, contains('v_owner uuid := auth.uid()'));
      expect(sql, contains("raise exception 'authentication required'"));
      expect(sql, contains('octet_length(p_payload::text) > 262144'));
      expect(sql, contains('source_revision <= excluded.source_revision'));
      expect(sql, contains('values (v_owner, p_diary_day'));
    },
  );

  test(
    'support queue is truthful, entitlement-derived, and has no SLA claim',
    () {
      expect(sql, contains('bil_support_requests enable row level security'));
      expect(sql, contains("queue_class in ('standard', 'paid')"));
      expect(sql, contains('from public.bil_entitlements e'));
      expect(sql, contains('e.active'));
      expect(sql, contains("then v_queue := 'paid'"));
      expect(sql, isNot(contains('guaranteed')));
      expect(sql, isNot(contains('response time')));
      expect(sql, isNot(contains('sla')));
      expect(
        sql,
        contains(
          'grant select on public.bil_support_requests to authenticated',
        ),
      );
    },
  );
}
