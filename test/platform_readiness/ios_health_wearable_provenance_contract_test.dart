import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HealthKit bridge marks only evidenced Apple Watch records', () {
    final swift = File(
      'ios/Runner/BILGlobalHealthBridge.swift',
    ).readAsStringSync();

    expect(swift, contains('sample.device?.name'));
    expect(swift, contains('sample.device?.model'));
    expect(swift, contains('sample.device?.manufacturer'));
    expect(swift, contains('sample.sourceRevision.productType'));
    expect(swift, contains('normalizedDevice.contains("apple watch")'));
    expect(swift, contains('attributes["wearableKind"] = "apple_watch"'));
  });

  test('HealthKit does not overlap native syncs after a Dart timeout', () {
    final swift = File(
      'ios/Runner/BILGlobalHealthBridge.swift',
    ).readAsStringSync();

    expect(swift, contains('private var readChangesInFlight = false'));
    expect(swift, contains('operation_in_progress'));
    expect(swift, contains('var nextNameIndex = 0'));
    expect(swift, contains('func executeNext()'));
    expect(swift, contains('readChangesInFlight = false'));
    expect(swift, contains('case "cancelReadChanges"'));
    expect(swift, contains('store.stop(query)'));
  });
}
