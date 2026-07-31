import '../environment/app_environment.dart';

enum ExternalCapability {
  account,
  sync,
  ai,
  commerce,
  community,
  coach,
  updates,
}

class CapabilityStatus {
  const CapabilityStatus({
    required this.capability,
    required this.available,
    required this.reason,
  });

  final ExternalCapability capability;
  final bool available;
  final String reason;
}

class ExternalCapabilities {
  const ExternalCapabilities._();

  static CapabilityStatus status(ExternalCapability capability) {
    final cloud =
        AppEnvironment.cloudConfigured && AppEnvironment.serverConfigured;
    return switch (capability) {
      ExternalCapability.account => CapabilityStatus(
        capability: capability,
        available: false,
        reason: cloud
            ? 'Configuration found, but verified registration/session activation is not enabled in this build.'
            : 'Requires Supabase client configuration and the BIL server boundary.',
      ),
      ExternalCapability.sync => CapabilityStatus(
        capability: capability,
        available: false,
        reason: cloud
            ? 'Configuration found, but verified outbox/inbox activation is not enabled in this build.'
            : 'Local Mode is active. No data is uploaded.',
      ),
      ExternalCapability.ai => CapabilityStatus(
        capability: capability,
        available: false,
        reason: AppEnvironment.aiConfigured
            ? 'Server endpoint found, but the consent and rate-limit adapter is not activated.'
            : 'Requires a server-side AI proxy. Model secrets are never accepted by the client.',
      ),
      ExternalCapability.commerce => CapabilityStatus(
        capability: capability,
        available: false,
        reason: AppEnvironment.commerceConfigured
            ? 'Payment configuration exists, but verified receipt/webhook activation is pending.'
            : 'Purchases are not configured. No payment details are collected.',
      ),
      ExternalCapability.community ||
      ExternalCapability.coach => CapabilityStatus(
        capability: capability,
        available: false,
        reason:
            'Requires authenticated identities, consent, moderation, and enforced server-side access policies.',
      ),
      ExternalCapability.updates => CapabilityStatus(
        capability: capability,
        available: false,
        reason:
            'Remote signed update configuration is not configured; platform stores remain authoritative.',
      ),
    };
  }
}
