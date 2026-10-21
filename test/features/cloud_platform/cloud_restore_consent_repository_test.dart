import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_consent_local_store.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_consent_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_restore_consent_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RestoreConsentFixture backend;
  late RestoreChoiceMemory choices;
  late CloudRestoreConsentRepository repository;
  setUp(() {
    backend = RestoreConsentFixture();
    choices = RestoreChoiceMemory();
    repository = CloudRestoreConsentRepository.withBackend(
      backend: backend,
      localStore: choices,
    );
  });
  tearDown(() async {
    repository.dispose();
    await backend.owners.close();
  });

  test(
    'unchanged status refresh preserves active sync and confirmation leases',
    () async {
      backend.grants['owner-a'] = {CloudRestoreScope.nutrition: true};
      final first = await repository.read();
      final lease = repository.captureLease(first);
      final refreshed = await repository.read();
      expect(identical(first, refreshed), isTrue);
      expect(repository.isCurrent(lease, CloudRestoreScope.nutrition), isTrue);
      expect(() => repository.captureLease(first), returnsNormally);
      expect(backend.writes, isEmpty);
    },
  );

  test(
    'concurrent settings and sync reads share one current authority',
    () async {
      backend.grants['owner-a'] = {CloudRestoreScope.nutrition: true};
      backend.readBarrier = Completer<void>();
      backend.readStarted = Completer<void>();
      final first = repository.read();
      final second = repository.read();
      await backend.readStarted!.future;
      expect(identical(first, second), isTrue);
      backend.readBarrier!.complete();
      final states = await Future.wait([first, second]);
      expect(
        states.every((s) => s.allows(CloudRestoreScope.nutrition)),
        isTrue,
      );
      expect(identical(states[0], states[1]), isTrue);
    },
  );

  test(
    'a fresh server denial retires the previously granted sync lease',
    () async {
      backend.grants['owner-a'] = {CloudRestoreScope.nutrition: true};
      final lease = repository.captureLease(await repository.read());
      backend.grants['owner-a'] = {CloudRestoreScope.nutrition: false};
      backend.receiptTime = '2026-10-21T00:00:00Z';
      final refreshed = await repository.read();
      expect(refreshed.allows(CloudRestoreScope.nutrition), isFalse);
      expect(repository.isCurrent(lease, CloudRestoreScope.nutrition), isFalse);
    },
  );

  test(
    'a newer receipt with the same grant retires an earlier remote visit',
    () async {
      backend.grants['owner-a'] = {CloudRestoreScope.nutrition: true};
      final lease = repository.captureLease(await repository.read());
      backend.receiptTime = '2026-10-21T00:00:00Z';
      final refreshed = await repository.read();
      expect(refreshed.allows(CloudRestoreScope.nutrition), isTrue);
      expect(repository.isCurrent(lease, CloudRestoreScope.nutrition), isFalse);
      expect(
        repository.isCurrent(
          repository.captureLease(refreshed),
          CloudRestoreScope.nutrition,
        ),
        isTrue,
      );
    },
  );

  test(
    'a failed status refresh remains fail closed for the active lease',
    () async {
      backend.grants['owner-a'] = {CloudRestoreScope.nutrition: true};
      final lease = repository.captureLease(await repository.read());
      backend.failRead = true;
      final failed = await repository.read();
      expect(failed.availability, CloudRestoreConsentAvailability.unavailable);
      expect(failed.grantedScopes, isEmpty);
      expect(repository.isCurrent(lease, CloudRestoreScope.nutrition), isFalse);
      backend.failRead = false;
      final recovered = await repository.read();
      expect(recovered.allows(CloudRestoreScope.nutrition), isTrue);
      expect(repository.isCurrent(lease, CloudRestoreScope.nutrition), isFalse);
    },
  );

  test('loss of server capability retires an earlier granted lease', () async {
    backend.grants['owner-a'] = {CloudRestoreScope.nutrition: true};
    final lease = repository.captureLease(await repository.read());
    backend.unsupported = true;
    expect(
      (await repository.read()).availability,
      CloudRestoreConsentAvailability.unavailable,
    );
    expect(repository.isCurrent(lease, CloudRestoreScope.nutrition), isFalse);
  });

  test(
    'an old read cannot replace the authority of a new A B A visit',
    () async {
      backend.grants['owner-a'] = {CloudRestoreScope.nutrition: true};
      final delayed = Completer<void>();
      backend.readBarrier = delayed;
      backend.readStarted = Completer<void>();
      final oldRead = repository.read();
      await backend.readStarted!.future;
      backend.switchOwner('owner-b');
      backend.switchOwner('owner-a');
      backend.readBarrier = null;
      final fresh = await repository.read();
      final lease = repository.captureLease(fresh);
      delayed.complete();
      expect((await oldRead).grantedScopes, isEmpty);
      expect(repository.isCurrent(lease, CloudRestoreScope.nutrition), isTrue);
      expect(() => repository.captureLease(fresh), returnsNormally);
    },
  );

  test('existing base grant never opts in either additional scope', () async {
    final state = await repository.read();
    expect(state.availability, CloudRestoreConsentAvailability.available);
    expect(state.grantedScopes, isEmpty);
    expect(backend.writes, isEmpty);
    expect(choices.choices, isEmpty);
  });

  test('scopes grant independently and do not change base consent', () async {
    await repository.setGranted(CloudRestoreScope.nutrition, true);
    final state = await repository.read();
    expect(state.allows(CloudRestoreScope.nutrition), isTrue);
    expect(state.allows(CloudRestoreScope.goals), isFalse);
    expect(backend.baseGranted, isTrue);
    expect(backend.writes, [('owner-a', CloudRestoreScope.nutrition, true)]);
  });

  test('missing capability is unavailable even with mirrored opt-in', () async {
    choices.choices['owner-a'] = {CloudRestoreScope.nutrition: true};
    backend.unsupported = true;
    final state = await repository.read();
    expect(state.availability, CloudRestoreConsentAvailability.unavailable);
    expect(state.requestedScopes, {CloudRestoreScope.nutrition});
    expect(state.grantedScopes, isEmpty);
    await expectLater(
      repository.setGranted(CloudRestoreScope.goals, true),
      throwsStateError,
    );
    expect(backend.writes, isEmpty);
  });

  test('base consent is required to grant but never to revoke', () async {
    backend.baseGranted = false;
    backend.grants['owner-a'] = {CloudRestoreScope.goals: true};
    var state = await repository.read();
    expect(
      state.availability,
      CloudRestoreConsentAvailability.baseConsentRequired,
    );
    expect(state.allows(CloudRestoreScope.goals), isFalse);
    await expectLater(
      repository.setGranted(CloudRestoreScope.nutrition, true),
      throwsStateError,
    );
    await repository.setGranted(CloudRestoreScope.goals, false);
    state = await repository.read();
    expect(state.grantedScopes, isEmpty);
    expect(backend.writes, [('owner-a', CloudRestoreScope.goals, false)]);
  });

  test(
    'revocation fences transport before its server request resolves',
    () async {
      backend.grants['owner-a'] = {CloudRestoreScope.nutrition: true};
      final lease = repository.captureLease(await repository.read());
      expect(repository.isCurrent(lease, CloudRestoreScope.nutrition), isTrue);
      backend.writeBarrier = Completer<void>();
      final revoking = repository.setGranted(
        CloudRestoreScope.nutrition,
        false,
      );
      expect(repository.isCurrent(lease, CloudRestoreScope.nutrition), isFalse);
      backend.writeBarrier!.complete();
      await revoking;
    },
  );

  test('failed revoke remains denied after repository restart', () async {
    backend.grants['owner-a'] = {CloudRestoreScope.nutrition: true};
    backend.failWrite = true;
    await expectLater(
      repository.setGranted(CloudRestoreScope.nutrition, false),
      throwsStateError,
    );
    repository.dispose();
    repository = CloudRestoreConsentRepository.withBackend(
      backend: backend,
      localStore: choices,
    );
    expect(
      (await repository.read()).allows(CloudRestoreScope.nutrition),
      isFalse,
    );
    expect(backend.grants['owner-a']![CloudRestoreScope.nutrition], isTrue);
  });

  test('A B A during read drops receipt and cancels captured lease', () async {
    backend.grants['owner-a'] = {CloudRestoreScope.nutrition: true};
    final lease = repository.captureLease(await repository.read());
    backend.readBarrier = Completer<void>();
    final reading = repository.read();
    await Future<void>.delayed(Duration.zero);
    backend.switchOwner('owner-b');
    backend.switchOwner('owner-a');
    backend.readBarrier!.complete();
    final state = await reading;
    expect(state.grantedScopes, isEmpty);
    expect(state.ownerId, isNull);
    expect(repository.isCurrent(lease, CloudRestoreScope.nutrition), isFalse);
  });

  test(
    'confirmation from former account visit cannot submit a grant',
    () async {
      final session = repository.captureLease(await repository.read());
      backend.switchOwner('owner-b');
      backend.switchOwner('owner-a');
      await expectLater(
        repository.setGranted(
          CloudRestoreScope.goals,
          true,
          expectedSession: session,
        ),
        throwsStateError,
      );
      expect(backend.writes, isEmpty);
      expect(choices.choices, isEmpty);
    },
  );

  test(
    'account change during write never reports the new owner confirmed',
    () async {
      backend.writeBarrier = Completer<void>();
      final writing = repository.setGranted(CloudRestoreScope.goals, true);
      final assertion = expectLater(writing, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      backend.switchOwner('owner-b');
      backend.writeBarrier!.complete();
      await assertion;
      expect((await repository.read()).grantedScopes, isEmpty);
      expect(backend.writes.single.$1, 'owner-a');
    },
  );

  test('duplicate choice is rejected while a receipt is pending', () async {
    backend.writeBarrier = Completer<void>();
    final writing = repository.setGranted(CloudRestoreScope.goals, true);
    await expectLater(
      repository.setGranted(CloudRestoreScope.goals, true),
      throwsStateError,
    );
    backend.writeBarrier!.complete();
    await writing;
    expect(backend.writes, hasLength(1));
  });

  test(
    'malformed receipt cannot turn a local intent into authorization',
    () async {
      backend.invalidReceipt = true;
      await expectLater(
        repository.setGranted(CloudRestoreScope.goals, true),
        throwsStateError,
      );
      final state = await repository.read();
      expect(state.requestedScopes, {CloudRestoreScope.goals});
      expect(state.grantedScopes, isEmpty);
    },
  );

  test('signed-out read and write are closed', () async {
    backend.switchOwner(null);
    expect(
      (await repository.read()).availability,
      CloudRestoreConsentAvailability.signedOut,
    );
    await expectLater(
      repository.setGranted(CloudRestoreScope.goals, true),
      throwsStateError,
    );
    expect(backend.writes, isEmpty);
  });

  test(
    'SQLite intent mirror survives reopening and rejects owner mismatch',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await LocalDataAccountBoundary(db).bindAuthenticatedOwner('owner-a');
      final first = AppDatabaseCloudRestoreConsentLocalStore(db);
      await first.write('owner-a', CloudRestoreScope.nutrition, true);
      await first.write('owner-a', CloudRestoreScope.goals, false);
      final second = AppDatabaseCloudRestoreConsentLocalStore(db);
      expect(await second.read('owner-a'), {
        CloudRestoreScope.nutrition: true,
        CloudRestoreScope.goals: false,
      });
      await expectLater(second.read('owner-b'), throwsStateError);
      await expectLater(
        second.write('owner-b', CloudRestoreScope.goals, true),
        throwsStateError,
      );
      expect((await second.read('owner-a'))[CloudRestoreScope.goals], isFalse);
    },
  );
}
