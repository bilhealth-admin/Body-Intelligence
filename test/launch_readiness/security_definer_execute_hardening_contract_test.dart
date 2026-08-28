import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SECURITY DEFINER functions cannot inherit anonymous execution', () {
    final sql = File(
      'supabase/migrations/20260815225751_bil_security_definer_execute_hardening.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('alter default privileges in schema public'),
    );
    expect(sql, contains('revoke execute on functions from public'));
    expect(sql, contains("n.nspname = 'public' and p.prosecdef"));
    expect(
      sql,
      contains("'revoke all on function %s from public, anon'"),
    );
    expect(
      sql,
      contains("'grant execute on function %s to service_role'"),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.bil_consume_rate_limit(text, integer, integer)',
      ),
    );
  });
}
