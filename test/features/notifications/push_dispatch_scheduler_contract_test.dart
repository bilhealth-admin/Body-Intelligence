import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production push scheduler is internal, bounded, and disabled by default', () {
    final source = File(
      'supabase/migrations/20260925050000_community_push_dispatch_scheduler.sql',
    ).readAsStringSync();

    expect(source, contains('enabled boolean not null default false'));
    expect(source, contains("name = 'BIL_INTERNAL_DISPATCH_SECRET'"));
    expect(source, contains('pg_try_advisory_xact_lock'));
    expect(source, contains('timeout_milliseconds := 15000'));
    expect(source, contains("'bil-community-push-dispatch-1m'"));
    expect(source, contains('private.bil_push_dispatch_scheduler_audit'));
    expect(
      source,
      contains(
        'revoke all on function private.bil_dispatch_community_push()\n'
        '  from public, anon, authenticated, service_role;',
      ),
    );
  });
}
