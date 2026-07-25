import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native bridges are registered and do not return invariant empty payloads',
    () {
      final swift = File(
        'ios/Runner/BILGlobalHealthBridge.swift',
      ).readAsStringSync();
      final appDelegate = File(
        'ios/Runner/AppDelegate.swift',
      ).readAsStringSync();
      final kotlin = File(
        'android/app/src/main/kotlin/com/example/body_intelligence_log/BILGlobalHealthBridge.kt',
      ).readAsStringSync();
      final activity = File(
        'android/app/src/main/kotlin/com/example/body_intelligence_log/MainActivity.kt',
      ).readAsStringSync();
      expect(swift, contains('HKAnchoredObjectQuery'));
      expect(swift, contains('requestAuthorization'));
      expect(swift, contains('enableBackgroundDelivery'));
      expect(swift, isNot(contains('result([[String: Any]]())')));
      expect(appDelegate, contains('BILGlobalHealthBridge.register'));
      expect(kotlin, contains('HealthConnectClient'));
      expect(kotlin, contains('getChangesToken'));
      expect(kotlin, contains('DeletionChange'));
      expect(kotlin, isNot(contains('emptyList<Map<String, Any>>()')));
      expect(activity, contains('BILGlobalHealthBridge('));
    },
  );

  test('product main initializes the global native composition root', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('GlobalNativeIntegrationHost.instance.initialize()'));
  });
}
