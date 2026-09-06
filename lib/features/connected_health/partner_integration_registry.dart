import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../global_platform/health_data/unified_health_data_integration.dart';

enum PartnerIntegrationState {
  nativeBridge,
  deviceBridge,
  configurationRequired,
  noAdapter,
}

class PartnerIntegrationCapability {
  const PartnerIntegrationCapability({
    required this.id,
    required this.category,
    required this.state,
    required this.dataTypes,
    required this.reasonCode,
    this.officialSetupUrl,
  });

  final String id;
  final String category;
  final PartnerIntegrationState state;
  final Set<String> dataTypes;
  final String reasonCode;
  final String? officialSetupUrl;

  bool get canConnect =>
      state == PartnerIntegrationState.nativeBridge ||
      state == PartnerIntegrationState.deviceBridge;
}

/// Registry of product integrations that are reachable in the shipping app.
/// Provider API classes alone do not count as registered integrations: OAuth,
/// credentials, token storage, callback routing and composition wiring must all
/// exist before [canConnect] may become true.
abstract final class PartnerIntegrationRegistry {
  static final List<PartnerIntegrationCapability> capabilities =
      List<PartnerIntegrationCapability>.unmodifiable([
        PartnerIntegrationCapability(
          id: 'health-connect',
          category: 'Health platform',
          state: PartnerIntegrationState.nativeBridge,
          dataTypes: BilHealthScope.healthConnectReadTypeNames,
          reasonCode: 'android_native_bridge',
        ),
        PartnerIntegrationCapability(
          id: 'healthkit',
          category: 'Health platform',
          state: PartnerIntegrationState.nativeBridge,
          dataTypes: BilHealthScope.appleHealthReadTypeNames,
          reasonCode: 'ios_native_bridge',
        ),
        PartnerIntegrationCapability(
          id: 'fitness-ble',
          category: 'Fitness device',
          state: PartnerIntegrationState.deviceBridge,
          dataTypes: {'weight', 'bodyComposition', 'heartRate'},
          reasonCode: 'fitness_sig_gatt_profiles_device_verification_required',
        ),
        PartnerIntegrationCapability(
          id: 'garmin',
          category: 'Partner account',
          state: PartnerIntegrationState.configurationRequired,
          dataTypes: {},
          reasonCode: 'oauth_credentials_and_runtime_registration_missing',
          officialSetupUrl: 'https://connect.garmin.com/start/',
        ),
        PartnerIntegrationCapability(
          id: 'fitbit',
          category: 'Partner account',
          state: PartnerIntegrationState.configurationRequired,
          dataTypes: {},
          reasonCode: 'oauth_credentials_and_runtime_registration_missing',
          officialSetupUrl:
              'https://support.google.com/googlehealth/answer/14236818?hl=en',
        ),
        PartnerIntegrationCapability(
          id: 'samsung-health',
          category: 'Partner account',
          state: PartnerIntegrationState.noAdapter,
          dataTypes: {},
          reasonCode: 'no_registered_adapter',
          officialSetupUrl: 'https://www.samsung.com/us/apps/samsung-health/',
        ),
      ]);

  /// The consumer capabilities page lists only connections that can actually
  /// operate on the current device: its native health store plus BLE.
  static List<PartnerIntegrationCapability> forTargetPlatform(
    TargetPlatform platform, {
    bool isWeb = false,
  }) {
    if (isWeb) return const <PartnerIntegrationCapability>[];
    final ids = switch (platform) {
      TargetPlatform.android => const {'health-connect', 'fitness-ble'},
      TargetPlatform.iOS => const {'healthkit', 'fitness-ble'},
      _ => const <String>{},
    };
    return List<PartnerIntegrationCapability>.unmodifiable(
      capabilities.where((entry) => ids.contains(entry.id)),
    );
  }

  static PartnerIntegrationCapability byId(String id) =>
      capabilities.singleWhere((entry) => entry.id == id);

  static bool isVerifiedOfficialSetupUri(String id, Uri uri) {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) {
      return false;
    }
    final capability = capabilities.where((entry) => entry.id == id);
    if (capability.length != 1) return false;
    return capability.single.officialSetupUrl == uri.toString();
  }
}

final partnerIntegrationRegistryProvider =
    Provider<List<PartnerIntegrationCapability>>(
      (_) => PartnerIntegrationRegistry.forTargetPlatform(
        defaultTargetPlatform,
        isWeb: kIsWeb,
      ),
    );
