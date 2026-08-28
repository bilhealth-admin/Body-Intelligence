enum DeviceVerificationLevel {
  testedInAutomatedMock,
  implementationReadyDeviceRequired,
  unsupported,
}

final class HealthDeviceCompatibility {
  const HealthDeviceCompatibility({
    required this.id,
    required this.platforms,
    required this.protocol,
    required this.dataTypes,
    required this.verification,
    required this.minimumVersion,
  });

  final String id;
  final Set<String> platforms;
  final String protocol;
  final Set<String> dataTypes;
  final DeviceVerificationLevel verification;
  final String minimumVersion;
}

/// Release truth: this is a protocol matrix, not a claim that every product
/// advertising Bluetooth is compatible. Real-device certification remains an
/// external release gate for each hardware/OS combination.
abstract final class BilDeviceCompatibilityMatrix {
  static const List<HealthDeviceCompatibility> entries = [
    HealthDeviceCompatibility(
      id: 'android-health-connect',
      platforms: {'Android'},
      protocol: 'Health Connect SDK',
      dataTypes: {'steps', 'activeEnergy', 'workout', 'weight'},
      verification: DeviceVerificationLevel.implementationReadyDeviceRequired,
      minimumVersion: 'Android 9 with Health Connect; Android 14 integrated',
    ),
    HealthDeviceCompatibility(
      id: 'apple-healthkit',
      platforms: {'iOS'},
      protocol: 'HealthKit',
      dataTypes: {'steps', 'activeEnergy', 'workout', 'weight'},
      verification: DeviceVerificationLevel.implementationReadyDeviceRequired,
      minimumVersion: 'iOS 15+',
    ),
    HealthDeviceCompatibility(
      id: 'bluetooth-sig-health-profiles',
      platforms: {'Android', 'iOS'},
      protocol: 'BLE GATT SIG 181D/181B/180D',
      dataTypes: {'weight', 'bodyComposition', 'heartRate'},
      verification: DeviceVerificationLevel.implementationReadyDeviceRequired,
      minimumVersion: 'Android 8+ / iOS 15+',
    ),
  ];

  static bool isAdvertisable(String id) {
    final match = entries.where((entry) => entry.id == id);
    return match.isNotEmpty &&
        match.single.verification != DeviceVerificationLevel.unsupported;
  }
}
