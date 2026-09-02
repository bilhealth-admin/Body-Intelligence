import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closed-test access resolves to paid AI Coach without forging a trial', () {
    final sql = File(
      'supabase/migrations/'
      '20260831074550_closed_test_ai_allowance_resolution.sql',
    ).readAsStringSync();

    final grantPredicate = sql.indexOf(
      'from public.bil_ai_closed_test_grants g',
    );
    final canonicalTrialPredicate = sql.indexOf(
      "and s.lifecycle = 'trial'",
    );

    expect(grantPredicate, greaterThanOrEqualTo(0));
    expect(canonicalTrialPredicate, greaterThan(grantPredicate));
    expect(
      sql.substring(grantPredicate, canonicalTrialPredicate),
      contains("then 'ai_coach'"),
    );
    expect(sql, contains('and g.active'));
    expect(sql, contains('and g.expires_at > now()'));
    expect(sql, isNot(contains("s.product_id = 'bil_closed_test'")));
    expect(
      sql,
      contains(
        'revoke all on function public.bil_resolve_ai_allowance_plan(uuid)',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.bil_resolve_ai_allowance_plan(uuid)\n'
        '  to service_role;',
      ),
    );
  });
}
