import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('startup evaluates local owner boundary before dashboard routing', () {
    final startup = source('lib/features/startup/startup_page.dart');
    expect(startup, contains('localDataAccountBindingProvider'));
    expect(startup, contains('requiresAccountResolution'));
    expect(startup, contains("'/account-data-conflict'"));
  });

  test(
    'account conflict route preserves data and only offers safe sign out',
    () {
      final router = source('lib/app/router/app_router.dart');
      final page = source('lib/features/auth/account_data_conflict_page.dart');

      expect(router, contains("path: '/account-data-conflict'"));
      expect(router, contains('AccountDataConflictPage'));
      expect(page, contains('auth.signOut()'));
      expect(page, contains("context.go('/account-gateway')"));
      expect(page, contains('No local record has been deleted or uploaded.'));
      expect(page, isNot(contains('bil_sync_records')));
      expect(page, isNot(contains('synchronize(')));
    },
  );

  test('ownership boundary is local-only and fail-closed', () {
    final boundary = source(
      'lib/features/cloud_platform/services/local_data_account_boundary.dart',
    );
    expect(boundary, contains('adoptedGuestData'));
    expect(boundary, contains('matchedExistingOwner'));
    expect(boundary, contains('reboundEmptyStore'));
    expect(boundary, contains('ownerConflict'));
    expect(boundary, contains('cloud.localDataOwner.v1'));
    expect(boundary, isNot(contains('Supabase')));
    expect(boundary, isNot(contains('bil_sync_records')));
  });
  test('normal account switching is isolated by database namespace', () {
    final provider = source('lib/data/database/database_provider.dart');
    final native = source(
      'lib/data/database/connection/database_connection_native.dart',
    );
    final startup = source('lib/features/startup/startup_page.dart');

    expect(provider, contains('AppDatabase(localOwnerId: ownerId)'));
    expect(provider, contains('onAuthStateChange'));
    expect(provider, contains('ref.invalidateSelf()'));
    expect(native, contains('LocalDatabaseScope.databaseFileName'));
    expect(native, contains('canAdoptLegacyDatabase'));
    expect(startup, contains("signedIn ? '/onboarding' : '/account-gateway'"));
  });
}
