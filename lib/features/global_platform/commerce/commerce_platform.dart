import 'package:crypto/crypto.dart';

import '../core/global_platform_core.dart';

final class Entitlement {
  Entitlement({
    required this.id,
    required this.features,
    required DateTime validUntil,
    required this.source,
    required this.accountId,
  }) : validUntil = validUntil.toUtc();
  final String id, source, accountId;
  final Set<String> features;
  final DateTime validUntil;
}

final class ReceiptVerificationResult {
  const ReceiptVerificationResult({
    required this.valid,
    required this.transactionId,
    required this.accountId,
    required this.productId,
    required this.expiresAt,
    required this.revoked,
  });
  final bool valid, revoked;
  final String transactionId, accountId, productId;
  final DateTime? expiresAt;
}

abstract interface class StoreReceiptVerifier {
  String get providerId;
  Future<ReceiptVerificationResult> verify(List<int> receipt);
  Future<List<List<int>>> restore(String accountId);
}

final class CommerceRuntime {
  CommerceRuntime({
    required this.store,
    required this.audit,
    required this.verifiers,
    required this.productFeatures,
  });
  final GlobalDurableStore store;
  final GlobalAuditSink audit;
  final List<StoreReceiptVerifier> verifiers;
  final Map<String, Set<String>> productFeatures;

  Future<Entitlement?> validate({
    required List<int> receipt,
    required DateTime at,
  }) async {
    final fingerprint = sha256.convert(receipt).toString();
    if (await store.get('receipt_ledger', fingerprint) != null) return null;
    for (final verifier in verifiers) {
      final result = await verifier.verify(receipt);
      if (!result.valid || result.revoked) continue;
      final features = productFeatures[result.productId];
      if (features == null) continue;
      final validUntil = result.expiresAt ?? DateTime.utc(9999, 12, 31);
      final entitlement = Entitlement(
        id: result.transactionId,
        features: features,
        validUntil: validUntil,
        source: verifier.providerId,
        accountId: result.accountId,
      );
      await store.put('receipt_ledger', fingerprint, <String, Object?>{
        'provider': verifier.providerId,
        'transactionId': result.transactionId,
        'verifiedAt': at.toUtc().toIso8601String(),
      });
      await store.put('entitlements', entitlement.id, <String, Object?>{
        'accountId': entitlement.accountId,
        'features': features.toList()..sort(),
        'until': validUntil.toIso8601String(),
        'source': verifier.providerId,
      });
      await audit.record(
        GlobalAuditEvent(
          action: 'commerce.entitlement.granted',
          subjectId: result.accountId,
          at: at,
          metadata: <String, Object?>{
            'transaction': result.transactionId,
            'provider': verifier.providerId,
          },
        ),
      );
      return entitlement;
    }
    return null;
  }

  Future<int> restore({required String accountId, required DateTime at}) async {
    var count = 0;
    for (final verifier in verifiers) {
      for (final receipt in await verifier.restore(accountId)) {
        if (await validate(receipt: receipt, at: at) != null) count++;
      }
    }
    return count;
  }

  Future<bool> has(String accountId, String feature, DateTime at) async =>
      (await store.list('entitlements')).any(
        (entitlement) =>
            entitlement['accountId'] == accountId &&
            (entitlement['features']! as List<Object?>).contains(feature) &&
            DateTime.parse(entitlement['until']! as String).isAfter(at.toUtc()),
      );
}
