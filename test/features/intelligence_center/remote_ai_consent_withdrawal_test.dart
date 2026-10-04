import 'dart:async';

import 'package:body_intelligence_log/features/intelligence_center/services/remote_ai_consent_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

const _allow = <String, Object?>{'granted': true, 'policy_version': '3'};
const _deny = <String, Object?>{'granted': false, 'policy_version': '3'};

void main() {
  test(
    'failed withdrawal blocks cached receipt and survives relaunch per owner',
    () async {
      final disk = <String, bool>{};
      var owner = 'owner-a';
      var reads = 0;
      RemoteAiConsentCoordinator create() => RemoteAiConsentCoordinator(
        owner: () => owner,
        read: () async {
          reads++;
          return _allow;
        },
        write: () async {},
        revoke: () async => throw StateError('offline'),
        readDenial: (key) async => disk[key] ?? false,
        writeDenial: (key, denied) async {
          disk[key] = denied;
        },
      );
      final first = create();
      expect(await first.isGranted(), isTrue);
      final withdrawal = first.revokeAndVerify();
      expect(await first.isGranted(), isFalse);
      await expectLater(withdrawal, throwsStateError);
      expect(disk['owner-a'], isTrue);
      final relaunched = create();
      expect(await relaunched.isGranted(), isFalse);
      expect(reads, 1);
      owner = 'owner-b';
      expect(await relaunched.isGranted(), isTrue);
      owner = 'owner-a';
      expect(await relaunched.isGranted(), isFalse);
    },
  );

  test(
    'only explicit Allow write plus current readback clears durable denial',
    () async {
      final disk = <String, bool>{'owner-a': true};
      var writes = 0;
      final readback = Completer<Object?>();
      final coordinator = RemoteAiConsentCoordinator(
        owner: () => 'owner-a',
        read: () => readback.future,
        write: () async {
          writes++;
        },
        readDenial: (key) async => disk[key] ?? false,
        writeDenial: (key, denied) async {
          disk[key] = denied;
        },
      );
      final allow = coordinator.grantAndVerify();
      await Future<void>.delayed(Duration.zero);
      expect(writes, 1);
      expect(disk['owner-a'], isTrue);
      expect(await coordinator.isGranted(), isFalse);
      readback.complete(_allow);
      expect(await allow, isTrue);
      expect(disk['owner-a'], isFalse);
      expect(await coordinator.isGranted(), isTrue);
    },
  );

  test('failed Allow readback retains withdrawal after relaunch', () async {
    final disk = <String, bool>{'owner-a': true};
    final coordinator = RemoteAiConsentCoordinator(
      owner: () => 'owner-a',
      read: () async => throw StateError('readback unavailable'),
      write: () async {},
      readDenial: (key) async => disk[key] ?? false,
      writeDenial: (key, denied) async {
        disk[key] = denied;
      },
    );
    await expectLater(coordinator.grantAndVerify(), throwsStateError);
    expect(disk['owner-a'], isTrue);
    expect(await coordinator.isGranted(), isFalse);
  });

  test('late Allow cannot undo a newer withdrawal', () async {
    final disk = <String, bool>{};
    final writeStarted = Completer<void>();
    final lateAllow = Completer<void>();
    final coordinator = RemoteAiConsentCoordinator(
      owner: () => 'owner-a',
      read: () async => _deny,
      write: () {
        writeStarted.complete();
        return lateAllow.future;
      },
      revoke: () async {},
      readDenial: (key) async => disk[key] ?? false,
      writeDenial: (key, denied) async {
        disk[key] = denied;
      },
    );
    final allowing = coordinator.grantAndVerify();
    await writeStarted.future;
    expect(await coordinator.revokeAndVerify(), isTrue);
    lateAllow.complete();
    expect(await allowing, isFalse);
    expect(disk['owner-a'], isTrue);
    expect(await coordinator.isGranted(forceServerRead: true), isFalse);
  });

  test('late positive receipt cannot undo immediate withdrawal', () async {
    final readback = Completer<Object?>();
    var reads = 0;
    final coordinator = RemoteAiConsentCoordinator(
      owner: () => 'owner-a',
      read: () {
        reads++;
        return reads == 1 ? readback.future : Future.value(_deny);
      },
      write: () async {},
      revoke: () async {},
    );
    final reading = coordinator.isGranted();
    await Future<void>.delayed(Duration.zero);
    expect(await coordinator.revokeAndVerify(), isTrue);
    readback.complete(_allow);
    expect(await reading, isFalse);
    expect(await coordinator.isGranted(), isFalse);
  });

  test('owner change during Allow cannot unlock new account', () async {
    var owner = 'owner-a';
    final readback = Completer<Object?>();
    final disk = <String, bool>{};
    final coordinator = RemoteAiConsentCoordinator(
      owner: () => owner,
      read: () => readback.future,
      write: () async {},
      readDenial: (key) async => disk[key] ?? false,
      writeDenial: (key, denied) async {
        disk[key] = denied;
      },
    );
    final allowing = coordinator.grantAndVerify();
    await Future<void>.delayed(Duration.zero);
    owner = 'owner-b';
    readback.complete(_allow);
    expect(await allowing, isFalse);
    expect(disk['owner-a'], isTrue);
  });

  test(
    'malformed revoke readback is not reported as verified denial',
    () async {
      final coordinator = RemoteAiConsentCoordinator(
        owner: () => 'owner-a',
        read: () async => const {},
        write: () async {},
        revoke: () async {},
      );
      expect(await coordinator.revokeAndVerify(), isFalse);
      expect(await coordinator.isGranted(), isFalse);
    },
  );

  test('failed durable storage blocks Allow before any remote write', () async {
    var writes = 0;
    final coordinator = RemoteAiConsentCoordinator(
      owner: () => 'owner-a',
      read: () async => _allow,
      write: () async {
        writes++;
      },
      writeDenial: (_, _) async => throw StateError('disk full'),
    );
    await expectLater(coordinator.grantAndVerify(), throwsStateError);
    expect(writes, 0);
    expect(await coordinator.isGranted(), isFalse);
  });
}
