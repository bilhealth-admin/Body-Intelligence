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
      final iosSpeech = File(
        'ios/Runner/BILSpeechBridge.swift',
      ).readAsStringSync();
      final iosTts = File(
        'ios/Runner/BILTextToSpeechBridge.swift',
      ).readAsStringSync();
      final xcodeProject = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final kotlin = File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILGlobalHealthBridge.kt',
      ).readAsStringSync();
      final activity = File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/MainActivity.kt',
      ).readAsStringSync();
      expect(swift, contains('HKAnchoredObjectQuery'));
      expect(swift, contains('requestAuthorization'));
      expect(swift, contains('enableBackgroundDelivery'));
      expect(swift, contains('foreground-refresh-only'));
      expect(swift, isNot(contains('result([[String: Any]]())')));
      expect(appDelegate, contains('BILGlobalHealthBridge.register'));
      expect(appDelegate, contains('BILSpeechBridge(messenger:'));
      expect(appDelegate, contains('BILTextToSpeechBridge(messenger:'));
      expect(iosSpeech, contains('SFSpeechRecognizer'));
      expect(iosTts, contains('AVSpeechSynthesizer'));
      expect(xcodeProject, contains('BILSpeechBridge.swift in Sources'));
      expect(xcodeProject, contains('BILTextToSpeechBridge.swift in Sources'));
      expect(kotlin, contains('HealthConnectClient'));
      expect(kotlin, contains('getChangesToken'));
      expect(kotlin, contains('DeletionChange'));
      expect(kotlin, contains('foreground-refresh-only'));
      expect(kotlin, isNot(contains('workmanager-scheduler')));
      expect(kotlin, isNot(contains('emptyList<Map<String, Any>>()')));
      expect(activity, contains('BILGlobalHealthBridge('));
    },
  );

  test('optional global runtime stays off the launch hot path', () {
    final main = File('lib/main.dart').readAsStringSync();
    final connected = File(
      'lib/features/connected_health/providers/connected_health_provider.dart',
    ).readAsStringSync();
    expect(
      main,
      isNot(contains('GlobalNativeIntegrationHost.instance.initialize()')),
    );
    expect(connected, contains('DeferredConnectedHealthGateway'));
    expect(connected, contains('await host.initialize()'));
  });
}
