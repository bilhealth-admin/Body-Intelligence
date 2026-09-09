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
    expect(swift, contains('normalizedProductType.hasPrefix("watch")'));
    expect(swift, contains('sourceName'));
    expect(swift, contains('normalizedDevice.contains("apple watch")'));
    expect(swift, contains('attributes["wearableKind"] = "apple_watch"'));
  });
}
