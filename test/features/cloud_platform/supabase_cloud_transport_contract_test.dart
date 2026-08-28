import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud ledger migration is owner scoped and RPC authenticated', () {
    final sql = File(
      'supabase/migrations/202608100002_bil_cloud_ledger_sync.sql',
    ).readAsStringSync();
    expect(sql, contains('enable row level security'));
    expect(sql, contains('owner_id = auth.uid()'));
    expect(sql, contains('security invoker'));
    expect(sql, contains("raise exception 'authentication_required'"));
    expect(sql, contains('jsonb_array_length(p_operations) > 100'));
    expect(sql, contains('device_revision_mismatch'));
    expect(sql, contains('bil_cloud_operations'));
    expect(
      sql,
      contains("change_sequence = nextval('public.bil_cloud_change_sequence')"),
    );
    expect(sql, contains("raise exception 'invalid_operation_id'"));
    expect(sql, contains('grant execute on function public.bil_sync_records'));
  });

  test('Supabase transport implements the real CloudTransport boundary', () {
    final source = File(
      'lib/features/cloud_platform/services/supabase_cloud_transport.dart',
    ).readAsStringSync();
    expect(source, contains('implements CloudTransport'));
    expect(source, contains("client.rpc(\n      'bil_sync_records'"));
    expect(source, contains('user.id != ownerId'));
    expect(source, contains('session.deviceId != deviceId'));
    expect(
      source,
      contains('Cross-account or cross-device sync batch rejected.'),
    );
    expect(source, contains('Cross-account BIL cloud response.'));
    expect(source, contains('CloudSyncBatchResult'));
  });

  test(
    'production schema compatibility keeps both cloud column pairs valid',
    () {
      final sql = File(
        'supabase/migrations/'
        '20260822070041_bil_cloud_sync_legacy_column_compatibility.sql',
      ).readAsStringSync();
      expect(sql, contains('device_id, revision_device_id'));
      expect(sql, contains('client_updated_at, updated_at'));
      expect(sql, contains('device_id = excluded.device_id'));
      expect(sql, contains('client_updated_at = excluded.client_updated_at'));
      expect(sql, contains("raise exception 'device_revoked'"));
      expect(sql, contains('jsonb_array_length(p_operations) > 100'));
      expect(sql, contains('security invoker'));
    },
  );
}
