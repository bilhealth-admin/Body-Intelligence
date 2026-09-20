import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/features/auth/apple_credential_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppleCredentialLifecycleController', () {
    test('migrates Apple subject to owner-scoped secure storage', () async {
      final store = _MemoryIdentifierStore();
      String? checkedIdentifier;
      var signOuts = 0;
      final controller = AppleCredentialLifecycleController(
        identifierStore: store,
        readCurrentSession: () => const BilAppleCredentialSession(
          ownerId: 'owner-a',
          appleUserIdentifier: 'apple-subject-a',
        ),
        readCredentialState: (identifier) async {
          checkedIdentifier = identifier;
          return BilAppleCredentialState.authorized;
        },
        signOutLocal: (_) async {
          signOuts += 1;
          return true;
        },
      );

      await controller.reconcile();

      expect(checkedIdentifier, 'apple-subject-a');
      expect(store.values, <String, String>{'owner-a': 'apple-subject-a'});
      expect(signOuts, 0);
    });

    for (final deniedState in <BilAppleCredentialState>[
      BilAppleCredentialState.revoked,
      BilAppleCredentialState.notFound,
    ]) {
      test('$deniedState clears only the matching local session', () async {
        final store = _MemoryIdentifierStore()
          ..values['owner-a'] = 'apple-subject-a';
        BilAppleCredentialSession? current = const BilAppleCredentialSession(
          ownerId: 'owner-a',
        );
        final signedOutOwners = <String>[];
        var invalidations = 0;
        final controller = AppleCredentialLifecycleController(
          identifierStore: store,
          readCurrentSession: () => current,
          readCredentialState: (_) async => deniedState,
          signOutLocal: (expectedOwnerId) async {
            signedOutOwners.add(expectedOwnerId);
            current = null;
            return true;
          },
          onSessionInvalidated: () => invalidations += 1,
        );

        await controller.reconcile();

        expect(signedOutOwners, <String>['owner-a']);
        expect(store.values, isEmpty);
        expect(invalidations, 1);
      });
    }

    test('does not sign out an account switched during Apple lookup', () async {
      final store = _MemoryIdentifierStore()
        ..values['owner-a'] = 'apple-subject-a';
      var current = const BilAppleCredentialSession(ownerId: 'owner-a');
      final lookupStarted = Completer<void>();
      final lookupResult = Completer<BilAppleCredentialState>();
      var signOuts = 0;
      final controller = AppleCredentialLifecycleController(
        identifierStore: store,
        readCurrentSession: () => current,
        readCredentialState: (_) {
          lookupStarted.complete();
          return lookupResult.future;
        },
        signOutLocal: (_) async {
          signOuts += 1;
          return true;
        },
      );

      final reconciliation = controller.reconcile();
      await lookupStarted.future;
      current = const BilAppleCredentialSession(ownerId: 'owner-b');
      lookupResult.complete(BilAppleCredentialState.revoked);
      await reconciliation;

      expect(signOuts, 0);
      expect(store.values['owner-a'], 'apple-subject-a');
    });

    test(
      'does not navigate when sign-out loses the final owner race',
      () async {
        final store = _MemoryIdentifierStore()
          ..values['owner-a'] = 'apple-subject-a';
        var invalidations = 0;
        final controller = AppleCredentialLifecycleController(
          identifierStore: store,
          readCurrentSession: () =>
              const BilAppleCredentialSession(ownerId: 'owner-a'),
          readCredentialState: (_) async => BilAppleCredentialState.revoked,
          signOutLocal: (_) async => false,
          onSessionInvalidated: () => invalidations += 1,
        );

        await controller.reconcile();

        expect(store.values['owner-a'], 'apple-subject-a');
        expect(invalidations, 0);
      },
    );

    test(
      'secure-store migration failure invalidates the Apple session',
      () async {
        final store = _MemoryIdentifierStore()..throwOnWrite = true;
        var current = const BilAppleCredentialSession(ownerId: 'owner-a');
        var credentialLookups = 0;
        var invalidations = 0;
        final errors = <Object>[];
        final controller = AppleCredentialLifecycleController(
          identifierStore: store,
          readCurrentSession: () => current.appleUserIdentifier == null
              ? const BilAppleCredentialSession(
                  ownerId: 'owner-a',
                  appleUserIdentifier: 'legacy-apple-subject',
                )
              : current,
          readCredentialState: (_) async {
            credentialLookups += 1;
            return BilAppleCredentialState.authorized;
          },
          signOutLocal: (_) async {
            current = const BilAppleCredentialSession(ownerId: '');
            return true;
          },
          onSessionInvalidated: () => invalidations += 1,
          onError: (error, _) => errors.add(error),
        );

        await controller.reconcile();

        expect(credentialLookups, 0);
        expect(invalidations, 1);
        expect(errors, hasLength(1));
      },
    );

    test('secure-store read failure invalidates the Apple session', () async {
      final store = _MemoryIdentifierStore()..throwOnRead = true;
      var current = const BilAppleCredentialSession(ownerId: 'owner-a');
      var invalidations = 0;
      final errors = <Object>[];
      final controller = AppleCredentialLifecycleController(
        identifierStore: store,
        readCurrentSession: () => current,
        readCredentialState: (_) async => BilAppleCredentialState.authorized,
        signOutLocal: (_) async {
          current = const BilAppleCredentialSession(ownerId: '');
          return true;
        },
        onSessionInvalidated: () => invalidations += 1,
        onError: (error, _) => errors.add(error),
      );

      await controller.reconcile();

      expect(invalidations, 1);
      expect(errors, hasLength(1));
    });

    test('Keychain cleanup failure never suppresses UI invalidation', () async {
      final store = _MemoryIdentifierStore()
        ..values['owner-a'] = 'apple-subject-a'
        ..throwOnDelete = true;
      var current = const BilAppleCredentialSession(ownerId: 'owner-a');
      var invalidations = 0;
      final errors = <Object>[];
      final controller = AppleCredentialLifecycleController(
        identifierStore: store,
        readCurrentSession: () => current,
        readCredentialState: (_) async => BilAppleCredentialState.revoked,
        signOutLocal: (_) async {
          current = const BilAppleCredentialSession(ownerId: '');
          return true;
        },
        onSessionInvalidated: () => invalidations += 1,
        onError: (error, _) => errors.add(error),
      );

      await controller.reconcile();

      expect(invalidations, 1);
      expect(errors, hasLength(1));
    });

    test('provider errors do not invent a revoked credential', () async {
      final store = _MemoryIdentifierStore()
        ..values['owner-a'] = 'apple-subject-a';
      final errors = <Object>[];
      var signOuts = 0;
      final controller = AppleCredentialLifecycleController(
        identifierStore: store,
        readCurrentSession: () =>
            const BilAppleCredentialSession(ownerId: 'owner-a'),
        readCredentialState: (_) async => throw StateError('offline'),
        signOutLocal: (_) async {
          signOuts += 1;
          return true;
        },
        onError: (error, _) => errors.add(error),
      );

      await controller.reconcile();

      expect(signOuts, 0);
      expect(store.values['owner-a'], 'apple-subject-a');
      expect(errors.single, isA<StateError>());
    });

    test(
      'missing identifier leaves the valid local session untouched',
      () async {
        final store = _MemoryIdentifierStore();
        var lookups = 0;
        var signOuts = 0;
        final controller = AppleCredentialLifecycleController(
          identifierStore: store,
          readCurrentSession: () =>
              const BilAppleCredentialSession(ownerId: 'owner-a'),
          readCredentialState: (_) async {
            lookups += 1;
            return BilAppleCredentialState.notFound;
          },
          signOutLocal: (_) async {
            signOuts += 1;
            return true;
          },
        );

        await controller.reconcile();

        expect(lookups, 0);
        expect(signOuts, 0);
      },
    );
  });

  test(
    'local invalidation returns before a slow logout network call',
    () async {
      String? currentOwner = 'owner-a';
      final networkCompletion = Completer<void>();

      final invalidated = await invalidateMatchingLocalSession(
        expectedOwnerId: 'owner-a',
        readCurrentOwnerId: () => currentOwner,
        signOutLocal: () {
          currentOwner = null;
          return networkCompletion.future;
        },
      ).timeout(const Duration(milliseconds: 100));

      expect(invalidated, isTrue);
      networkCompletion.complete();
    },
  );

  test('local invalidation never signs out a replacement account', () async {
    var currentOwner = 'owner-b';
    var signOuts = 0;

    final invalidated = await invalidateMatchingLocalSession(
      expectedOwnerId: 'owner-a',
      readCurrentOwnerId: () => currentOwner,
      signOutLocal: () async {
        signOuts += 1;
      },
    );

    expect(invalidated, isFalse);
    expect(signOuts, 0);
  });

  test('secure storage key is account scoped and normalized', () {
    expect(
      SecureAppleCredentialIdentifierStore.storageKey(' owner-a '),
      'bil.auth.apple-user-id.v1.owner-a',
    );
    expect(
      SecureAppleCredentialIdentifierStore.storageKey('owner-b'),
      isNot(SecureAppleCredentialIdentifierStore.storageKey('owner-a')),
    );
    expect(
      SecureAppleCredentialIdentifierStore.pendingCleanupKey(' owner-a '),
      'bil.auth.apple-user-id-pending-cleanup.v1.owner-a',
    );
  });

  test('legacy Apple sessions recover the provider subject only', () {
    const appleSubject = '000123.apple.subject';
    final user = User(
      id: 'owner-a',
      appMetadata: const <String, dynamic>{
        'providers': <String>['apple'],
      },
      userMetadata: const <String, dynamic>{},
      aud: 'authenticated',
      createdAt: '2026-09-04T00:00:00Z',
      identities: const <UserIdentity>[
        UserIdentity(
          id: 'supabase-row-id',
          userId: 'owner-a',
          identityData: <String, dynamic>{'sub': appleSubject},
          identityId: 'supabase-identity-id',
          provider: 'apple',
          createdAt: null,
          lastSignInAt: null,
        ),
      ],
    );

    expect(supabaseSessionAuthenticatedWithApple(user), isTrue);
    expect(appleSubjectForSupabaseUser(user), appleSubject);
    expect(
      appleSubjectForSupabaseUser(
        User(
          id: 'owner-b',
          appMetadata: const <String, dynamic>{'provider': 'email'},
          userMetadata: const <String, dynamic>{},
          aud: 'authenticated',
          createdAt: '2026-09-04T00:00:00Z',
        ),
      ),
      isNull,
    );
  });

  test('linked Apple identity does not own a later email session', () {
    final user = User(
      id: 'owner-a',
      appMetadata: const <String, dynamic>{
        'provider': 'apple',
        'providers': <String>['apple', 'email'],
      },
      userMetadata: const <String, dynamic>{},
      aud: 'authenticated',
      createdAt: '2026-09-01T00:00:00Z',
      lastSignInAt: '2026-09-04T10:00:00.000Z',
      identities: const <UserIdentity>[
        UserIdentity(
          id: 'apple-row',
          userId: 'owner-a',
          identityData: <String, dynamic>{'sub': 'apple-subject'},
          identityId: 'apple-identity',
          provider: 'apple',
          createdAt: '2026-09-01T00:00:00Z',
          lastSignInAt: '2026-09-03T09:00:00Z',
        ),
        UserIdentity(
          id: 'email-row',
          userId: 'owner-a',
          identityData: <String, dynamic>{},
          identityId: 'email-identity',
          provider: 'email',
          createdAt: '2026-09-01T00:00:00Z',
          lastSignInAt: '2026-09-04T10:00:00Z',
        ),
      ],
    );

    expect(supabaseSessionAuthenticatedWithApple(user), isFalse);
  });

  test('linked Apple identity owns the session when timestamps match', () {
    final user = User(
      id: 'owner-a',
      appMetadata: const <String, dynamic>{
        'provider': 'email',
        'providers': <String>['email', 'apple'],
      },
      userMetadata: const <String, dynamic>{},
      aud: 'authenticated',
      createdAt: '2026-09-01T00:00:00Z',
      lastSignInAt: '2026-09-04T10:00:00.123456Z',
      identities: const <UserIdentity>[
        UserIdentity(
          id: 'email-row',
          userId: 'owner-a',
          identityData: <String, dynamic>{},
          identityId: 'email-identity',
          provider: 'email',
          createdAt: '2026-09-01T00:00:00Z',
          lastSignInAt: '2026-09-03T09:00:00Z',
        ),
        UserIdentity(
          id: 'apple-row',
          userId: 'owner-a',
          identityData: <String, dynamic>{'sub': 'apple-subject'},
          identityId: 'apple-identity',
          provider: 'apple',
          createdAt: '2026-09-01T00:00:00Z',
          lastSignInAt: '2026-09-04T12:00:00.123456+02:00',
        ),
      ],
    );

    expect(supabaseSessionAuthenticatedWithApple(user), isTrue);
  });

  test('native revocation bridge and Flutter lifecycle remain wired', () {
    final bridge = File(
      'ios/Runner/BILAppleSignInLifecycleBridge.swift',
    ).readAsStringSync();
    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final lifecycle = File(
      'lib/features/auth/apple_credential_lifecycle.dart',
    ).readAsStringSync();
    final auth = File(
      'lib/features/auth/supabase_auth_service.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final deletion = File(
      'lib/features/settings/account_deletion_page.dart',
    ).readAsStringSync();

    expect(
      bridge,
      contains('ASAuthorizationAppleIDProvider.credentialRevokedNotification'),
    );
    expect(bridge, contains('credentialRevoked'));
    expect(bridge, contains('hasPendingRevocation'));
    expect(delegate, contains('BILAppleSignInLifecycleBridge'));
    expect(project, contains('BILAppleSignInLifecycleBridge.swift in Sources'));
    expect(lifecycle, contains('SignInWithApple.getCredentialState'));
    expect(lifecycle, contains('AppLifecycleState.resumed'));
    expect(lifecycle, contains('SignOutScope.local'));
    expect(lifecycle, contains('readPendingCleanupOwners'));
    expect(lifecycle, contains('_retryPendingDeletionCleanup'));
    expect(main, contains('BilAppleCredentialLifecycleCoordinator'));
    expect(auth, contains('credential.userIdentifier?.trim()'));
    expect(auth, contains('credential.authorizationCode.trim()'));
    expect(auth, contains('SupabaseAppleAuthorizationCodeRegistrar'));
    expect(auth, contains("'apple-sign-in-token'"));
    expect(auth, contains("'authorization_code': authorizationCode"));
    expect(auth, contains("'identity_token': identityToken"));
    expect(auth, contains("'raw_nonce': rawNonce"));
    expect(auth, contains('SecureAppleCredentialIdentifierStore'));
    expect(
      auth,
      isNot(contains('AppleIDAuthorizationScopes.fullName')),
      reason: 'BIL must not request a one-shot Apple name it does not retain.',
    );
    expect(deletion, contains('SecureAppleCredentialIdentifierStore'));
    expect(deletion, contains('.delete('));
  });
}

final class _MemoryIdentifierStore implements AppleCredentialIdentifierStore {
  final values = <String, String>{};
  bool throwOnRead = false;
  bool throwOnWrite = false;
  bool throwOnDelete = false;

  @override
  Future<void> delete(String ownerId) async {
    if (throwOnDelete) throw StateError('delete failed');
    values.remove(ownerId);
  }

  @override
  Future<String?> read(String ownerId) async {
    if (throwOnRead) throw StateError('read failed');
    return values[ownerId];
  }

  @override
  Future<void> write(String ownerId, String userIdentifier) async {
    if (throwOnWrite) throw StateError('write failed');
    values[ownerId] = userIdentifier;
  }
}
