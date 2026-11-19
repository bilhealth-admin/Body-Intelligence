import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../app/security/bil_integrity_exception.dart';
import '../../../app/security/bil_integrity_payload.dart';
import '../../../app/security/bil_play_integrity_service.dart';

enum AndroidPurchaseReadiness {
  ready,
  reviewRequired,
  licenseRequired,
  unavailable,
  retired;

  String? get messageCode => switch (this) {
    ready || retired => null,
    reviewRequired => 'play_license_recovered',
    licenseRequired => 'license_unlicensed',
    unavailable => 'play_readiness_unavailable',
  };
}

/// An explicit Buy gate only. It never opens Billing, verifies a receipt,
/// grants benefits, finishes a purchase, or reuses a preflight grant.
final class AndroidStorePurchaseReadiness {
  AndroidStorePurchaseReadiness({
    Future<void> Function(String product, String attempt)? probe,
    Future<bool> Function(BilIntegrityException denial)? recover,
    Future<void> Function(String handle)? release,
    this.timeout = const Duration(seconds: 90),
  }) : _probe = probe ?? _probeProduction,
       _recover = recover ?? BilPlayIntegrityService.instance.recoverLicense,
       _release =
           release ?? BilPlayIntegrityService.instance.releaseLicenseRecovery;

  final Future<void> Function(String, String) _probe;
  final Future<bool> Function(BilIntegrityException) _recover;
  final Future<void> Function(String) _release;
  final Duration timeout;
  static const _uuid = Uuid();
  bool _busy = false;
  static bool _sharedBusy = false;
  int _epoch = 0;

  static Future<void> _probeProduction(String product, String attempt) async {
    // This real one-use grant is deliberately unused. Different action and
    // digest cannot authorize receipt verification. No rollout-disabled bypass.
    await BilPlayIntegrityService.instance.authorize(
      action: 'store.purchase_readiness',
      payloadDigest: bilIntegrityPayloadDigest({
        'purpose': 'purchase_readiness',
        'version': 1,
        'source': 'google_play',
        'product_id': product,
        'attempt': attempt,
      }),
      retainLicenseRecovery: true,
    );
  }

  Future<AndroidPurchaseReadiness> check({
    required String ownerId,
    required String productId,
    required bool Function() isCurrent,
  }) async {
    if (_busy || _sharedBusy || !isCurrent()) {
      return AndroidPurchaseReadiness.retired;
    }
    _busy = true;
    _sharedBusy = true;
    final epoch = ++_epoch;
    final attempt = _uuid.v4();
    bool current() => epoch == _epoch && isCurrent();
    Future<AndroidPurchaseReadiness> run() async {
      try {
        await _probe(productId, attempt);
        return current()
            ? AndroidPurchaseReadiness.ready
            : AndroidPurchaseReadiness.retired;
      } on BilIntegrityException catch (error) {
        final handle = error.recoveryHandle;
        if (error.code != 'license_unlicensed' ||
            handle == null ||
            error.recoveryOwner != ownerId ||
            !current()) {
          if (handle != null) await _release(handle);
          return current()
              ? AndroidPurchaseReadiness.unavailable
              : AndroidPurchaseReadiness.retired;
        }
        try {
          if (!current()) return AndroidPurchaseReadiness.retired;
          final interacted = await _recover(error);
          if (!current()) return AndroidPurchaseReadiness.retired;
          if (!interacted) return AndroidPurchaseReadiness.licenseRequired;
          // GET_LICENSED is not license proof. The provider was invalidated;
          // a NEW token/request and server verdict are mandatory.
          try {
            await _probe(productId, '$attempt-recheck');
          } on BilIntegrityException catch (freshError) {
            final freshHandle = freshError.recoveryHandle;
            if (freshHandle != null) await _release(freshHandle);
            return current()
                ? AndroidPurchaseReadiness.licenseRequired
                : AndroidPurchaseReadiness.retired;
          }
          // Retire this financial intent even if licensed now. Review offer
          // and explicitly tap Buy again; no silent or automatic purchase.
          return current()
              ? AndroidPurchaseReadiness.reviewRequired
              : AndroidPurchaseReadiness.retired;
        } finally {
          await _release(handle);
        }
      }
    }

    try {
      return await run().timeout(timeout);
    } on Object {
      return current()
          ? AndroidPurchaseReadiness.unavailable
          : AndroidPurchaseReadiness.retired;
    } finally {
      if (epoch == _epoch) _epoch++;
      _busy = false;
      _sharedBusy = false;
    }
  }
}
