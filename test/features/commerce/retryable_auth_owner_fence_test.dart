import 'dart:async';

import 'package:body_intelligence_log/features/auth/retryable_auth_session.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/retryable_auth_fixture.dart';

void main() {
  for (final optedIn in [false, true]) {
    test('same-owner retryable auth failure read opt-in=$optedIn', () async {
      final auth = RetryableAuthFixture();
      final client = RetryableSupabaseFixture(auth);
      final held = Completer<void>();
      final pending = CommunityOwnerOperation.run(
        client: client,
        ownerId: auth.currentUser!.id,
        retainSessionOnRetryableAuthReadError: optedIn,
        action: (_) async {
          await held.future;
          return 7;
        },
      );
      final outcome = expectLater(
        pending,
        optedIn
            ? completion(7)
            : throwsA(isA<CommunityOwnerOperationCancelled>()),
      );
      auth.fail(AuthRetryableFetchException(statusCode: '503'));
      held.complete();
      await outcome;
      await auth.changes.close();
    });
  }

  test('retryable error never revives A B A or a closed visit', () async {
    for (final changeOwner in [true, false]) {
      final auth = RetryableAuthFixture();
      final client = RetryableSupabaseFixture(auth);
      var visitCurrent = true;
      final held = Completer<void>();
      final pending = CommunityOwnerOperation.run(
        client: client,
        ownerId: auth.currentUser!.id,
        isCurrentOwner: () => visitCurrent,
        retainSessionOnRetryableAuthReadError: true,
        action: (_) async {
          await held.future;
          return 7;
        },
      );
      final outcome = expectLater(
        pending,
        throwsA(isA<CommunityOwnerOperationCancelled>()),
      );
      if (changeOwner) {
        auth.owner('offline-owner-b');
        auth.owner('offline-owner-a');
      } else {
        visitCurrent = false;
      }
      auth.fail(AuthRetryableFetchException(statusCode: '503'));
      held.complete();
      await outcome;
      await auth.changes.close();
    }
  });

  test('strict child remains strict inside opted-in metadata read', () async {
    final auth = RetryableAuthFixture();
    final client = RetryableSupabaseFixture(auth);
    final held = Completer<void>();
    final pending = CommunityOwnerOperation.run(
      client: client,
      ownerId: auth.currentUser!.id,
      retainSessionOnRetryableAuthReadError: true,
      action: (_) => CommunityOwnerOperation.run(
        client: client,
        ownerId: auth.currentUser!.id,
        action: (_) async {
          await held.future;
          return 7;
        },
      ),
    );
    final outcome = expectLater(
      pending,
      throwsA(isA<CommunityOwnerOperationCancelled>()),
    );
    auth.fail(AuthRetryableFetchException(statusCode: '503'));
    held.complete();
    await outcome;
    await auth.changes.close();
  });

  test('opted-in child cannot relax strict parent', () async {
    final auth = RetryableAuthFixture();
    final client = RetryableSupabaseFixture(auth);
    final held = Completer<void>();
    final pending = CommunityOwnerOperation.run(
      client: client,
      ownerId: auth.currentUser!.id,
      action: (_) => CommunityOwnerOperation.run(
        client: client,
        ownerId: auth.currentUser!.id,
        retainSessionOnRetryableAuthReadError: true,
        action: (_) async {
          await held.future;
          return 7;
        },
      ),
    );
    final outcome = expectLater(
      pending,
      throwsA(isA<CommunityOwnerOperationCancelled>()),
    );
    auth.fail(AuthRetryableFetchException(statusCode: '503'));
    held.complete();
    await outcome;
    await auth.changes.close();
  });

  test(
    'unknown error, auth rejection, no session and different owner deny',
    () async {
      final auth = RetryableAuthFixture();
      for (final error in [
        StateError('synthetic unknown'),
        const AuthException('unauthorized', statusCode: '401'),
        AuthRetryableFetchException(statusCode: '401'),
        AuthRetryableFetchException(statusCode: '403'),
      ]) {
        expect(
          isSameOwnerRetryableAuthReadFailure(
            error,
            auth: auth,
            previousOwnerId: 'offline-owner-a',
          ),
          isFalse,
        );
      }
      auth.session = null;
      expect(
        isSameOwnerRetryableAuthReadFailure(
          AuthRetryableFetchException(statusCode: '503'),
          auth: auth,
          previousOwnerId: 'offline-owner-a',
        ),
        isFalse,
      );
      auth.session = RetryableAuthFixture.sessionFor('offline-owner-b');
      expect(
        isSameOwnerRetryableAuthReadFailure(
          AuthRetryableFetchException(statusCode: '503'),
          auth: auth,
          previousOwnerId: 'offline-owner-a',
        ),
        isFalse,
      );
      await auth.changes.close();
    },
  );
}
