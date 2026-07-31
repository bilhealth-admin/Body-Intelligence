import 'package:flutter_test/flutter_test.dart';

final class _BleSessionModel {
  _BleSessionModel(Set<String> expected) : expected = Set<String>.of(expected);
  final Set<String> expected;
  final Set<String> completed = <String>{};
  final Set<String> packetFingerprints = <String>{};
  final List<String> packets = <String>[];
  bool replied = false;
  bool cancelled = false;
  bool onPacket(String characteristic, String fingerprint) {
    if (replied ||
        cancelled ||
        !expected.contains(characteristic) ||
        completed.contains(characteristic)) {
      return false;
    }
    completed.add(characteristic);
    if (packetFingerprints.add(fingerprint)) packets.add(fingerprint);
    if (completed.containsAll(expected)) replied = true;
    return true;
  }

  void timeout() {
    if (!replied) replied = true;
  }

  void cancel() {
    cancelled = true;
    if (!replied) replied = true;
  }
}

void main() {
  test(
    'BLE session aggregates every expected characteristic and replies once',
    () {
      final session = _BleSessionModel(<String>{'bp', 'hr', 'oxygen'});
      expect(session.onPacket('bp', '1'), isTrue);
      expect(session.replied, isFalse);
      expect(session.onPacket('bp', '1'), isFalse);
      expect(session.onPacket('hr', '2'), isTrue);
      expect(session.replied, isFalse);
      expect(session.onPacket('oxygen', '3'), isTrue);
      expect(session.replied, isTrue);
      expect(session.onPacket('oxygen', '4'), isFalse);
      expect(session.packets, <String>['1', '2', '3']);
    },
  );
  test('BLE cancellation and timeout terminate without duplicate replies', () {
    final cancelled = _BleSessionModel(<String>{'bp'});
    cancelled.cancel();
    expect(cancelled.onPacket('bp', '1'), isFalse);
    expect(cancelled.replied, isTrue);
    final timed = _BleSessionModel(<String>{'bp'});
    timed.timeout();
    timed.timeout();
    expect(timed.replied, isTrue);
    expect(timed.packets, isEmpty);
  });
}
