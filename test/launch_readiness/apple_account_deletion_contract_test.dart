import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('primary in-app deletion warns about billing and tracks completion', () {
    final page = [
      source('lib/features/settings/account_deletion_page.dart'),
      source('lib/features/settings/account_deletion_copy.dart'),
    ].join('\n');
    expect(page, contains('https://apps.apple.com/account/subscriptions'));
    expect(page, contains('does not cancel an App Store or Google Play'));
    expect(page, contains("'account-data-deletion'"));
    expect(page, contains("workerData['status'] == 'completed'"));
    expect(page, contains('SignOutScope.local'));
    expect(page, contains('within 15 minutes'));
    expect(page, contains('accountUsesAppleSignIn'));
    expect(page, contains('https://support.apple.com/102571'));
    expect(page, contains('does not retain an Apple token'));
    expect(page, contains('optional Apple step'));
    expect(page, isNot(contains('appleid.apple.com/auth/revoke')));
  });

  test('worker removes and verifies Storage before deleting Auth', () {
    final flat = source('supabase/functions/account_data_deletion.ts');
    final canonical = source(
      'supabase/functions/account-data-deletion/index.ts',
    );
    final worker = source(
      'supabase/functions/_shared/account_deletion_worker.ts',
    );
    final storage = source(
      'supabase/functions/_shared/account_deletion_storage.ts',
    );

    expect(flat, contains('handleAccountDeletion'));
    expect(canonical, contains('handleAccountDeletion'));
    expect(storage, contains('profile-avatars'));
    expect(storage, contains('community-post-images'));
    expect(storage, contains('bucket.remove(chunk)'));
    expect(storage, contains('storage_cleanup_incomplete'));
    expect(storage, contains('MAX_OBJECTS_PER_ACCOUNT'));
    expect(
      worker.indexOf('removed = await deleteBilUserStorage'),
      lessThan(worker.indexOf('client.auth.admin.deleteUser')),
    );
    expect(worker, contains('failure_code: "stale_worker_recovered"'));
    expect(worker, contains('failure: "storage_cleanup_failed"'));
  });

  test('database deletion dispatcher disables the unsafe SQL-only path', () {
    final emergency = source(
      'supabase/migrations/20260830034302_disable_unsafe_account_deletion_cron.sql',
    );
    final migration = source(
      'supabase/migrations/20260830053817_account_deletion_storage_cleanup_20260830093000.sql',
    );
    expect(emergency, contains("jobname = 'bil-account-data-deletion-15m'"));
    expect(emergency, contains('cron.unschedule(v_job_id)'));
    expect(emergency, contains('storage_api_account_deletion_worker_required'));
    expect(emergency, isNot(contains('delete from auth.users')));
    expect(emergency, isNot(contains('delete from storage.objects')));
    expect(migration, contains('storage_api_account_deletion_worker_required'));
    expect(migration, contains('bil-account-data-deletion-15m'));
    expect(migration, contains('bil-account-data-deletion-storage-first-15m'));
    expect(migration, contains('bil_account_deletion_worker_url'));
    expect(migration, contains('bil_internal_deletion_secret'));
    expect(migration, contains('bil_supabase_anon_key'));
    expect(migration, isNot(contains('delete from storage.objects')));
  });

  test(
    'public deletion page has timing and direct store cancellation links',
    () {
      final site = source('public_site/app.js');
      expect(site, contains('retries the queued request within 15 minutes'));
      expect(site, contains('https://apps.apple.com/account/subscriptions'));
      expect(
        site,
        contains('https://play.google.com/store/account/subscriptions'),
      );
    },
  );

  test('Sign in with Apple tokenless fallback follows TN3194', () {
    final readiness = source(
      'docs/release/BIL_APPLE_ACCOUNT_DELETION_READINESS_2026-08-30.md',
    );
    expect(readiness, contains('TN3194'));
    expect(readiness, contains('https://support.apple.com/102571'));
    expect(readiness, contains('Delete or Stop Using'));
    expect(readiness, contains('does not block or undo'));
    expect(readiness, contains('unauthenticated'));
    expect(readiness, isNot(contains('revocation blocker')));
  });
}
