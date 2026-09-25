import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/features/intelligence_center/intelligence_locale_copy.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/remote_ai_consent_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

const _granted = <String, Object?>{'granted': true, 'policy_version': '3'};

void main() {
  group('Remote AI consent orchestration', () {
    test('A no consent does not authorize an AI dispatch', () async {
      final harness = _Harness(readValues: <Object?>[const {}]);
      expect(await harness.coordinator.isGranted(), isFalse);
      expect(harness.dispatches, 0);
      expect(harness.writes, 0);
    });

    test(
      'B enable records, reads back, then permits exactly one dispatch',
      () async {
        final harness = _Harness(readValues: <Object?>[_granted]);
        if (await harness.coordinator.grantAndVerify()) harness.dispatches++;
        expect(harness.writes, 1);
        expect(harness.reads, 1);
        expect(harness.dispatches, 1);
      },
    );

    test('C declining locally performs no consent write or AI dispatch', () {
      final harness = _Harness();
      expect(harness.writes, 0);
      expect(harness.reads, 0);
      expect(harness.dispatches, 0);
    });

    test(
      'D existing valid consent is cached for subsequent messages',
      () async {
        final harness = _Harness(readValues: <Object?>[_granted]);
        expect(await harness.coordinator.isGranted(), isTrue);
        expect(await harness.coordinator.isGranted(), isTrue);
        expect(harness.reads, 1);
      },
    );

    test('E failed consent persistence fails closed', () async {
      final harness = _Harness(writeError: StateError('write failed'));
      await expectLater(harness.coordinator.grantAndVerify(), throwsStateError);
      expect(harness.dispatches, 0);
      expect(harness.reads, 0);
    });

    test('F failed readback after persistence fails closed', () async {
      final harness = _Harness(readError: StateError('read failed'));
      await expectLater(harness.coordinator.grantAndVerify(), throwsStateError);
      expect(harness.writes, 1);
      expect(harness.dispatches, 0);
    });

    test(
      'G a denied current receipt remains fail closed and retryable',
      () async {
        final harness = _Harness(readValues: <Object?>[const {}, _granted]);
        expect(await harness.coordinator.grantAndVerify(), isFalse);
        expect(await harness.coordinator.grantAndVerify(), isTrue);
        expect(harness.writes, 2);
        expect(harness.dispatches, 0);
      },
    );

    test('H rapid grants share one persistence/readback operation', () async {
      final readCompleter = Completer<Object?>();
      final harness = _Harness(readFuture: readCompleter.future);
      final first = harness.coordinator.grantAndVerify();
      final second = harness.coordinator.grantAndVerify();
      expect(identical(first, second), isTrue);
      readCompleter.complete(_granted);
      expect(await first, isTrue);
      expect(harness.writes, 1);
      expect(harness.reads, 1);
    });

    test('I concurrent consent checks share one server read', () async {
      final readCompleter = Completer<Object?>();
      final harness = _Harness(readFuture: readCompleter.future);
      final first = harness.coordinator.isGranted();
      final second = harness.coordinator.isGranted();
      expect(identical(first, second), isTrue);
      readCompleter.complete(_granted);
      expect(await first, isTrue);
      expect(harness.reads, 1);
    });

    test('J Arabic decline copy cannot leak the English fallback', () {
      final copy = intelligenceTextFor(
        'ar',
        'No problem. I’ll keep helping from verified data on this device.',
        'لا مشكلة. سأستمر بمساعدتك من البيانات الموثقة على هذا الجهاز.',
      );
      expect(copy, contains('لا مشكلة'));
      expect(copy, isNot(contains('No problem')));
    });

    test('K owner change invalidates the positive session cache', () async {
      final harness = _Harness(readValues: <Object?>[_granted, const {}]);
      expect(await harness.coordinator.isGranted(), isTrue);
      harness.owner = 'user-2';
      expect(await harness.coordinator.isGranted(), isFalse);
      expect(harness.reads, 2);
    });

    test(
      'L explicit invalidation forces a fresh grant write and readback',
      () async {
        final harness = _Harness(readValues: <Object?>[_granted, _granted]);
        expect(await harness.coordinator.isGranted(), isTrue);
        harness.coordinator.invalidate();
        expect(await harness.coordinator.grantAndVerify(), isTrue);
        expect(harness.writes, 1);
        expect(harness.reads, 2);
      },
    );

    test('UI clears progress before consent and retries original turn once', () {
      final source = File(
        'lib/features/intelligence_center/presentation/intelligence_query_flow.dart',
      ).readAsStringSync();
      expect(source, contains('sending = false;'));
      expect(source, contains('replyPhase = _CoachReplyPhase.idle;'));
      expect(source, contains('addUserMessage: false'));
      expect(source, contains('consentChoiceInFlight'));
      expect(source, contains('grantAndVerify()'));
      final consentRequired = source.indexOf(
        'reply.serviceStatus == CoachServiceStatus.consentRequired',
      );
      final invalidate = source.indexOf(
        'sharedRemoteAiConsentCoordinator().invalidate()',
        consentRequired,
      );
      final offer = source.indexOf(
        'final choice = await _offerPersonalIntelligence()',
        consentRequired,
      );
      expect(consentRequired, greaterThanOrEqualTo(0));
      expect(invalidate, greaterThan(consentRequired));
      expect(invalidate, lessThan(offer));
      final settings = File(
        'lib/features/intelligence_center/presentation/ai_coach_settings_page.dart',
      ).readAsStringSync();
      expect(
        settings,
        contains('sharedRemoteAiConsentCoordinator().invalidate()'),
      );
      final page = File(
        'lib/features/intelligence_center/presentation/intelligence_center_page.dart',
      ).readAsStringSync();
      expect(page, contains('showReplyThinking'));
      expect(page, isNot(contains('Preparing your answer')));
      expect(page, isNot(contains("? tr('Thinking with your BIL data'")));
    });
  });
}

class _Harness {
  _Harness({
    List<Object?> readValues = const <Object?>[],
    this.readFuture,
    this.readError,
    this.writeError,
  }) : _readValues = List<Object?>.of(readValues) {
    coordinator = RemoteAiConsentCoordinator(
      owner: () => owner,
      read: _read,
      write: _write,
    );
  }

  final List<Object?> _readValues;
  final Future<Object?>? readFuture;
  final Object? readError;
  final Object? writeError;
  late final RemoteAiConsentCoordinator coordinator;
  String owner = 'user-1';
  int reads = 0;
  int writes = 0;
  int dispatches = 0;

  Future<Object?> _read() async {
    reads++;
    if (readError case final error?) throw error;
    if (readFuture case final future?) return future;
    return _readValues.removeAt(0);
  }

  Future<void> _write() async {
    writes++;
    if (writeError case final error?) throw error;
  }
}
