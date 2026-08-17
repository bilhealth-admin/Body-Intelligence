import 'package:supabase_flutter/supabase_flutter.dart';

import '../../commerce/domain/commerce_entitlement.dart';
import '../../commerce/repositories/server_entitlement_repository.dart';
import 'cloud_runtime_access_gate.dart';

enum CloudSyncConsentAvailability {
  unavailable,
  signedOut,
  premiumRequired,
  available,
}

final class CloudSyncConsentState {
  const CloudSyncConsentState({
    required this.availability,
    this.ownerId,
    this.granted = false,
    this.recordedAt,
  });

  final CloudSyncConsentAvailability availability;
  final String? ownerId;
  final bool granted;
  final DateTime? recordedAt;

  bool get canEnable =>
      availability == CloudSyncConsentAvailability.available && !granted;

  bool get canDisable =>
      granted &&
      (availability == CloudSyncConsentAvailability.available ||
          availability == CloudSyncConsentAvailability.premiumRequired);

  bool get canChange => canEnable || canDisable;
}

/// Reads and writes the explicit cloud-sync privacy choice.
///
/// Turning sync on requires a current server-verified cloud-sync entitlement.
/// Turning it off only requires the authenticated owner so consent can always
/// be revoked even after a subscription expires.
final class CloudSyncConsentRepository {
  CloudSyncConsentRepository({
    required SupabaseClient client,
    ServerEntitlementRepository entitlementRepository =
        const ServerEntitlementRepository(),
  }) : _client = client,
       _entitlementRepository = entitlementRepository;

  final SupabaseClient _client;
  final ServerEntitlementRepository _entitlementRepository;

  Future<CloudSyncConsentState> read() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const CloudSyncConsentState(
        availability: CloudSyncConsentAvailability.signedOut,
      );
    }

    try {
      final rows = await _client
          .from('bil_consent_receipts')
          .select('granted, recorded_at')
          .eq('user_id', user.id)
          .eq('purpose', CloudRuntimeAccessGate.consentPurpose)
          .eq('policy_version', CloudRuntimeAccessGate.consentPolicyVersion)
          .limit(1);
      final row = rows.isEmpty ? null : rows.first;
      final granted = row?['granted'] == true;
      final recordedAt = DateTime.tryParse(
        '${row?['recorded_at'] ?? ''}',
      )?.toUtc();

      final subscription = await _entitlementRepository.current();
      final premium = subscription.grants(CommerceEntitlement.cloudSync);

      return CloudSyncConsentState(
        availability: premium
            ? CloudSyncConsentAvailability.available
            : CloudSyncConsentAvailability.premiumRequired,
        ownerId: user.id,
        granted: granted,
        recordedAt: recordedAt,
      );
    } on Object {
      return CloudSyncConsentState(
        availability: CloudSyncConsentAvailability.unavailable,
        ownerId: user.id,
      );
    }
  }

  Future<void> setGranted(bool granted) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Authentication is required before cloud consent.');
    }

    if (granted) {
      final subscription = await _entitlementRepository.current();
      if (!subscription.grants(CommerceEntitlement.cloudSync)) {
        throw StateError(
          'A server-verified Premium entitlement is required for cloud sync.',
        );
      }
    }

    await _client.rpc(
      'bil_record_consent',
      params: <String, Object?>{
        'p_purpose': CloudRuntimeAccessGate.consentPurpose,
        'p_policy_version': CloudRuntimeAccessGate.consentPolicyVersion,
        'p_granted': granted,
      },
    );
  }
}
