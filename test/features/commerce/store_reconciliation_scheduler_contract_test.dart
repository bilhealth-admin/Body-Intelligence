import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20261004231206_store_reconciliation_scheduler_v1.sql';
  const rlsMigrationPath =
      'supabase/migrations/20261004232318_store_reconciliation_scheduler_rls_v1.sql';

  test('store reconciliation scheduler keeps credentials server-owned', () {
    final source = File(migrationPath).readAsStringSync();

    expect(source, contains("vault.create_secret("));
    expect(source, contains("'BIL_RECONCILIATION_SECRET'"));
    expect(source, contains('extensions.gen_random_bytes(32)'));
    expect(source, contains('extensions.digest('));
    expect(
      source,
      contains(
        'revoke all on function '
        'public.bil_validate_store_reconciliation_secret(text)',
      ),
    );
    expect(
      source,
      contains(
        'grant execute on function '
        'public.bil_validate_store_reconciliation_secret(text)\n'
        '  to service_role;',
      ),
    );
    expect(source, isNot(contains('to anon;')));
    expect(source, isNot(contains('to authenticated;')));

    final rlsSource = File(rlsMigrationPath).readAsStringSync();
    expect(rlsSource, contains('enable row level security'));
    expect(
      rlsSource,
      contains('from public, anon, authenticated, service_role;'),
    );
  });

  test('scheduler is cursor-backed and calls only the production function', () {
    final source = File(migrationPath).readAsStringSync();

    expect(
      source,
      contains('private.bil_store_reconciliation_scheduler_state'),
    );
    expect(source, contains('bil_get_store_reconciliation_scheduler_cursor'));
    expect(source, contains('bil_finish_store_reconciliation_scheduler_run'));
    expect(
      source,
      contains(
        'https://tgmanzhqulksykhslrzb.supabase.co/functions/v1/'
        'verify-store-purchase',
      ),
    );
    expect(source, contains("'action', 'reconcile'"));
    expect(source, contains("'source', 'pg_cron'"));
    expect(source, contains("'bil-store-reconciliation-hourly'"));
    expect(source, contains("'7 * * * *'"));
  });
}
