import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native BLE release exposes approved fitness profiles only', () {
    final swift = File(
      'ios/Runner/BILFitnessBleBridge.swift',
    ).readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILFitnessBleBridge.kt',
    ).readAsStringSync();
    for (final token in ['181D', '181B', '180D']) {
      expect(swift, contains(token));
      expect(kotlin, contains(token));
    }
    for (final forbidden in ['1810', '1808', '1822', '1809']) {
      expect(swift, isNot(contains(forbidden)));
      expect(kotlin, isNot(contains(forbidden)));
    }
    final dart = File(
      'lib/features/global_platform/fitness_devices/native_ble_fitness_bridge.dart',
    ).readAsStringSync();
    for (final characteristic in ['2A9D', '2A9C', '2A37']) {
      expect(dart, contains(characteristic));
    }
    for (final forbidden in ['2A35', '2A18', '2A5F', '2A6E']) {
      expect(swift, isNot(contains(forbidden)));
      expect(kotlin, isNot(contains(forbidden)));
      expect(dart, isNot(contains(forbidden)));
    }
    for (final source in [swift, kotlin, dart]) {
      expect(source, contains('bil.global/fitness_ble'));
      expect(source, isNot(contains('bil.global/medical_ble')));
    }
    expect(
      File('ios/Runner/AppDelegate.swift').readAsStringSync(),
      contains('BILFitnessBleBridge.register'),
    );
    expect(
      File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/MainActivity.kt',
      ).readAsStringSync(),
      contains('BILFitnessBleBridge'),
    );
    expect(File('ios/Runner/BILMedicalBleBridge.swift').existsSync(), isFalse);
    expect(
      File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILMedicalBleBridge.kt',
      ).existsSync(),
      isFalse,
    );
    expect(
      Directory('lib/features/global_platform/medical_devices').existsSync(),
      isFalse,
    );
  });

  test('native BLE connection and discovery timeouts are truthful', () {
    final swift = File(
      'ios/Runner/BILFitnessBleBridge.swift',
    ).readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILFitnessBleBridge.kt',
    ).readAsStringSync();

    expect(swift, contains('args["timeoutMs"]'));
    expect(swift, contains('.milliseconds(timeoutMs)'));
    expect(swift, isNot(contains('deadline:.now()+3')));

    final pairStart = kotlin.indexOf('private fun pair(');
    final pairEnd = kotlin.indexOf('private fun disconnect(', pairStart);
    final pair = kotlin.substring(pairStart, pairEnd);
    expect(pair, contains('connectGatt('));
    expect(pair, contains('BluetoothProfile.STATE_CONNECTED'));
    expect(kotlin, contains('connectedSessions[id] === active'));
  });

  test('native BLE permission gates run before adapter state checks', () {
    final swift = File(
      'ios/Runner/BILFitnessBleBridge.swift',
    ).readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILFitnessBleBridge.kt',
    ).readAsStringSync();

    final kotlinHandler = kotlin.substring(
      kotlin.indexOf('init {'),
      kotlin.indexOf('private fun hasPermission'),
    );
    final androidRequest = kotlinHandler.indexOf(
      'call.method == "requestPermissions"',
    );
    final androidPermissionGate = kotlinHandler.indexOf(
      'if (!hasPermission())',
    );
    final androidAdapter = kotlinHandler.indexOf(
      'val adapter = manager.adapter',
    );
    expect(androidRequest, greaterThanOrEqualTo(0));
    expect(androidPermissionGate, greaterThan(androidRequest));
    expect(androidAdapter, greaterThan(androidPermissionGate));
    expect(
      kotlinHandler.indexOf('adapter.isEnabled'),
      greaterThan(androidAdapter),
    );

    final swiftHandler = swift.substring(
      swift.indexOf('private func handle('),
      swift.indexOf('private func requestBluetoothPermission('),
    );
    final iosRequest = swiftHandler.indexOf(
      'call.method == "requestPermissions"',
    );
    final iosPermissionGate = swiftHandler.indexOf(
      'guard CBManager.authorization == .allowedAlways',
    );
    final iosAdapterState = swiftHandler.indexOf(
      'guard central.state == .poweredOn',
    );
    expect(iosRequest, greaterThanOrEqualTo(0));
    expect(iosPermissionGate, greaterThan(iosRequest));
    expect(iosAdapterState, greaterThan(iosPermissionGate));
    expect(swift, contains('case .notDetermined:'));
    expect(
      swift,
      contains(
        'func centralManagerDidUpdateState(_ central:CBCentralManager) {\n'
        '    resolvePermissionRequestIfPossible()',
      ),
    );
  });
}
