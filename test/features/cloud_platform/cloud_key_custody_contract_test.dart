import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud key custody migration uses Vault and authenticated-only RPC', () {
    final source = File(
      'supabase/migrations/20260817103823_bil_cloud_key_custody.sql',
    ).readAsStringSync();

    expect(source, contains('vault.create_secret'));
    expect(source, contains('vault.decrypted_secrets'));
    expect(source, contains('extensions.gen_random_bytes(32)'));
    expect(source, contains("'cloud_sync'"));
    expect(
      source,
      contains(
        'grant execute on function public.bil_get_or_create_cloud_key() to authenticated',
      ),
    );
    expect(
      source,
      contains(
        'revoke all on public.bil_cloud_key_refs from public, anon, authenticated',
      ),
    );
  });

  test('existing-cloud-key RPC enforces consent-only read and no key creation', () {
    final source = File(
      'supabase/migrations/20260901000000_bil_existing_cloud_key_recovery.sql',
    ).readAsStringSync();

    expect(source, contains('public.bil_get_existing_cloud_key()'));
    expect(source, contains('extensions, pg_temp'));
    expect(source, contains("where purpose = 'cloud_sync'"));
    expect(source, contains('vault_secret_id'));
    expect(source, contains('vault.decrypted_secrets'));
    expect(source, contains('return null'));
    expect(
      source,
      contains(
        'revoke all on function public.bil_get_existing_cloud_key() from public, anon',
      ),
    );
    expect(
      source,
      contains(
        'grant execute on function public.bil_get_existing_cloud_key() to authenticated',
      ),
    );
    expect(source, isNot(contains('vault.create_secret')));
  });

  test('client key cache uses secure storage, not SharedPreferences', () {
    final source = File(
      'lib/features/cloud_platform/services/cloud_account_key_repository.dart',
    ).readAsStringSync();
    expect(source, contains('flutter_secure_storage'));
    expect(source, isNot(contains('SharedPreferences')));
    expect(source, contains('bil_get_or_create_cloud_key'));
  });
}
