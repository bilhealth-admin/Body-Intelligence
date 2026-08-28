import 'package:supabase_flutter/supabase_flutter.dart';

import '../../commerce/domain/commerce_entitlement.dart';
import '../../commerce/repositories/server_entitlement_repository.dart';
import 'local_data_account_boundary.dart';

enum CloudRuntimeAccessDisposition {
  ready,
  notAuthenticated,
  localOwnerMismatch,
  entitlementMissing,
  consentMissing,
  unavailable,
}

final class CloudRuntimeAccessDecision {
  const CloudRuntimeAccessDecision(
    this.disposition, {
    this.ownerId,
    this.consentGrantedAt,
  });

  final CloudRuntimeAccessDisposition disposition;
  final String? ownerId;
  final DateTime? consentGrantedAt;

  bool get isReady => disposition == CloudRuntimeAccessDisposition.ready;
}

/// Production activation gate for health-record cloud synchronization.
///
/// No caller is allowed to create or run a network sync runtime until all four
/// independent authorities agree: authenticated owner, local-data owner,
/// cloud-sync capability, and explicit cloud-sync consent. The basic
/// capability is part of Free so account continuity is never paywalled.
final class CloudRuntimeAccessGate {
  CloudRuntimeAccessGate({
    required this._client,
    required this._accountBoundary,
    this._entitlementRepository = const ServerEntitlementRepository(),
  });

  static const consentPurpose = 'cloud_sync';
  static const consentPolicyVersion = '1';

  final SupabaseClient _client;
  final LocalDataAccountBoundary _accountBoundary;
  final ServerEntitlementRepository _entitlementRepository;

  Future<CloudRuntimeAccessDecision> evaluate() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const CloudRuntimeAccessDecision(
        CloudRuntimeAccessDisposition.notAuthenticated,
      );
    }
    final ownerId = user.id;
    final localOwner = await _accountBoundary.readBoundOwnerId();
    if (localOwner != ownerId) {
      return CloudRuntimeAccessDecision(
        CloudRuntimeAccessDisposition.localOwnerMismatch,
        ownerId: ownerId,
      );
    }

    final subscription = await _entitlementRepository.current();
    if (!subscription.grants(CommerceEntitlement.cloudSync)) {
      return CloudRuntimeAccessDecision(
        CloudRuntimeAccessDisposition.entitlementMissing,
        ownerId: ownerId,
      );
    }

    try {
      final rows = await _client
          .from('bil_consent_receipts')
          .select('granted, recorded_at')
          .eq('user_id', ownerId)
          .eq('purpose', consentPurpose)
          .eq('policy_version', consentPolicyVersion)
          .eq('granted', true)
          .limit(1);
      if (rows.isEmpty) {
        return CloudRuntimeAccessDecision(
          CloudRuntimeAccessDisposition.consentMissing,
          ownerId: ownerId,
        );
      }
      final grantedAt = DateTime.tryParse(
        '${rows.first['recorded_at']}',
      )?.toUtc();
      if (grantedAt == null) {
        return CloudRuntimeAccessDecision(
          CloudRuntimeAccessDisposition.unavailable,
          ownerId: ownerId,
        );
      }
      return CloudRuntimeAccessDecision(
        CloudRuntimeAccessDisposition.ready,
        ownerId: ownerId,
        consentGrantedAt: grantedAt,
      );
    } on Object {
      return CloudRuntimeAccessDecision(
        CloudRuntimeAccessDisposition.unavailable,
        ownerId: ownerId,
      );
    }
  }

  Future<void> recordConsent({required bool granted}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Authentication is required before cloud consent.');
    }
    await _client.rpc(
      'bil_record_consent',
      params: <String, Object?>{
        'p_purpose': consentPurpose,
        'p_policy_version': consentPolicyVersion,
        'p_granted': granted,
      },
    );
  }
}
