import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS Bluetooth manager is created only from a user-initiated action',
    () {
      final source = File(
        'ios/Runner/BILFitnessBleBridge.swift',
      ).readAsStringSync();

      final initializer = source.substring(
        source.indexOf('init(registrar: FlutterPluginRegistrar)'),
        source.indexOf('private func ensureCentralManager'),
      );
      expect(initializer, isNot(contains('CBCentralManager(')));
      expect(
        initializer,
        contains('Registering the Flutter bridge must not itself request'),
      );

      expect(source, contains('private func ensureCentralManager()'));
      expect(
        source,
        contains('CBCentralManagerOptionShowPowerAlertKey: false'),
      );
      expect(source, contains('if call.method == "requestPermissions"'));
      expect(source, contains('_ = ensureCentralManager()'));
      expect(source, contains('let central = ensureCentralManager()'));
    },
  );
}
