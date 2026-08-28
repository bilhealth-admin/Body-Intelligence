import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_runtime_access_gate.dart';

enum CloudSyncConsentAvailability { unavailable, signedOut, available }

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
      granted && availability == CloudSyncConsentAvailability.available;

  bool get canChange => canEnable || canDisable;
}

/// Reads and writes the explicit cloud-sync privacy choice.
///
/// Basic encrypted account continuity is available to every authenticated
/// BIL account. Consent remains explicit because profile, weight, and hydration
/// are sensitive wellness data. Paid AI and analytics capabilities are gated
/// independently and never affect the user's ability to recover core data.
final class CloudSyncConsentRepository {
  CloudSyncConsentRepository({required this._client});

  final SupabaseClient _client;

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

      return CloudSyncConsentState(
        availability: CloudSyncConsentAvailability.available,
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
