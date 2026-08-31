import 'package:flutter/foundation.dart';

enum BilRuntimePlatform { android, ios, windows, macos, linux, web, unknown }

enum PlatformCapability {
  localCore,
  nativeHealth,
  fitnessBluetooth,
  cloudSync,
  cloudAi,
  commerce,
  contextualAds,
  storeDistribution,
}

enum CapabilityReadiness { available, configurationRequired, unavailable }

class PlatformCapabilityStatus {
  const PlatformCapabilityStatus({
    required this.capability,
    required this.readiness,
    required this.reason,
  });

  final PlatformCapability capability;
  final CapabilityReadiness readiness;
  final String reason;

  bool get isAvailable => readiness == CapabilityReadiness.available;
}

class PlatformReadinessMatrix {
  const PlatformReadinessMatrix._();

  static BilRuntimePlatform get currentPlatform {
    if (kIsWeb) return BilRuntimePlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => BilRuntimePlatform.android,
      TargetPlatform.iOS => BilRuntimePlatform.ios,
      TargetPlatform.windows => BilRuntimePlatform.windows,
      TargetPlatform.macOS => BilRuntimePlatform.macos,
      TargetPlatform.linux => BilRuntimePlatform.linux,
      _ => BilRuntimePlatform.unknown,
    };
  }

  static PlatformCapabilityStatus status({
    required BilRuntimePlatform platform,
    required PlatformCapability capability,
    bool cloudActivated = false,
    bool aiActivated = false,
    bool commerceActivated = false,
    bool storeConfigured = false,
  }) {
    if (capability == PlatformCapability.localCore) {
      return PlatformCapabilityStatus(
        capability: capability,
        readiness: CapabilityReadiness.available,
        reason:
            'The local-first product core is available without external services.',
      );
    }

    return switch (capability) {
      PlatformCapability.nativeHealth => _nativeHealth(platform),
      PlatformCapability.fitnessBluetooth => _fitnessBluetooth(platform),
      PlatformCapability.cloudSync => _external(
        capability,
        cloudActivated,
        'Cloud synchronization requires an activated provider and verified server boundary.',
      ),
      PlatformCapability.cloudAi => _external(
        capability,
        aiActivated,
        'Cloud AI requires a server-side proxy, consent enforcement, and rate limits.',
      ),
      PlatformCapability.commerce => _external(
        capability,
        commerceActivated,
        'Commerce requires a verified store provider and server-side receipt validation.',
      ),
      PlatformCapability.contextualAds => _external(
        capability,
        false,
        'Contextual ads remain hidden until consent, production identifiers, and a reviewed provider adapter are configured.',
      ),
      PlatformCapability.storeDistribution => _external(
        capability,
        storeConfigured,
        'Store distribution requires registered identifiers, signing, and store-console setup.',
      ),
      PlatformCapability.localCore => throw StateError('Handled above.'),
    };
  }

  static PlatformCapabilityStatus _nativeHealth(BilRuntimePlatform platform) {
    final supported =
        platform == BilRuntimePlatform.android ||
        platform == BilRuntimePlatform.ios;
    return PlatformCapabilityStatus(
      capability: PlatformCapability.nativeHealth,
      readiness: supported
          ? CapabilityReadiness.configurationRequired
          : CapabilityReadiness.unavailable,
      reason: supported
          ? 'Native health support requires platform permissions, entitlements, and device verification.'
          : 'Native health integration is not supported on this runtime platform.',
    );
  }

  static PlatformCapabilityStatus _fitnessBluetooth(
    BilRuntimePlatform platform,
  ) {
    final supported =
        platform != BilRuntimePlatform.web &&
        platform != BilRuntimePlatform.unknown;
    return PlatformCapabilityStatus(
      capability: PlatformCapability.fitnessBluetooth,
      readiness: supported
          ? CapabilityReadiness.configurationRequired
          : CapabilityReadiness.unavailable,
      reason: supported
          ? 'BLE requires runtime permissions, compatible hardware, and provider/device validation.'
          : 'Native BLE is unavailable on this runtime platform.',
    );
  }

  static PlatformCapabilityStatus _external(
    PlatformCapability capability,
    bool activated,
    String pendingReason,
  ) {
    return PlatformCapabilityStatus(
      capability: capability,
      readiness: activated
          ? CapabilityReadiness.available
          : CapabilityReadiness.configurationRequired,
      reason: activated
          ? 'Verified external activation is present.'
          : pendingReason,
    );
  }
}
