import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android keeps verified GATT only until a remote disconnect clears it',
    () {
      final bridge = File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/'
        'BILFitnessBleBridge.kt',
      ).readAsStringSync();
      final readStart = bridge.indexOf('private fun read(');
      final packetStart = bridge.indexOf('private fun onPacket(', readStart);
      expect(readStart, greaterThanOrEqualTo(0));
      expect(packetStart, greaterThan(readStart));
      final read = bridge.substring(readStart, packetStart);

      expect(read, contains('val owner = operationGatt'));
      expect(read, contains('val keepVerifiedConnection ='));
      expect(
        read,
        contains(
          'error == null && owner != null && sessions[address] === owner &&',
        ),
      );
      expect(read, contains('connectedSessions[address] === owner'));
      expect(read, contains('if (!keepVerifiedConnection && owner != null)'));
      expect(read, contains('sessions.remove(address, owner)'));
      expect(read, contains('connectedSessions.remove(address, owner)'));
      expect(read, contains('closeGattSafely(owner)'));

      final disconnectedStart = read.indexOf(
        'else if (state == BluetoothProfile.STATE_DISCONNECTED)',
      );
      final disconnectedEnd = read.indexOf(
        'override fun onServicesDiscovered',
        disconnectedStart,
      );
      expect(disconnectedStart, greaterThanOrEqualTo(0));
      expect(disconnectedEnd, greaterThan(disconnectedStart));
      final disconnected = read.substring(disconnectedStart, disconnectedEnd);
      expect(disconnected, contains('connectedSessions.remove(address, gatt)'));
      expect(disconnected, contains('sessions.remove(address, gatt)'));
      expect(
        RegExp(
          r'connectedSessions\.remove\(address, gatt\)',
        ).allMatches(disconnected),
        hasLength(2),
      );
      expect(
        RegExp(r'sessions\.remove\(address, gatt\)').allMatches(disconnected),
        hasLength(2),
      );
      expect(
        RegExp(
          r'closeGattSafely\(gatt, disconnectFirst = false\)',
        ).allMatches(disconnected),
        hasLength(2),
      );
      expect(
        disconnected.indexOf('sessions.remove(address, gatt)'),
        lessThan(disconnected.indexOf('return')),
      );

      expect(
        bridge,
        contains(
          'private fun closeGattSafely(gatt: BluetoothGatt, '
          'disconnectFirst: Boolean = true)',
        ),
      );
      expect(bridge, contains('gatt.disconnect()'));
      expect(bridge, contains('gatt.close()'));
    },
  );
}
