part of 'verified_store_purchase_service.dart';

enum StoreRestorePhase { operation, sync, enumeration, callback, coalescedWait }

enum StoreRestoreFailure { sync, unverified, callback, platform, unexpected }

/// Fixed support categories only. Native messages/details may contain a JWS;
/// neither is inspected, retained, formatted, hashed or transmitted here.
final class StoreRestoreDiagnostic {
  const StoreRestoreDiagnostic(this.phase, this.failure);

  factory StoreRestoreDiagnostic.fromNativeCode(
    StoreRestorePhase phase,
    String code,
  ) => StoreRestoreDiagnostic(phase, switch (code) {
    'storekit2_failed_to_sync_to_app_store' => StoreRestoreFailure.sync,
    'storekit2_restore_failed' => StoreRestoreFailure.unverified,
    _ => StoreRestoreFailure.platform,
  });

  final StoreRestorePhase phase;
  final StoreRestoreFailure failure;

  String get supportCode {
    final stage = switch (phase) {
      StoreRestorePhase.operation => 'OP',
      StoreRestorePhase.sync => 'SYNC',
      StoreRestorePhase.enumeration => 'ENUM',
      StoreRestorePhase.callback => 'CALLBACK',
      StoreRestorePhase.coalescedWait => 'WAIT',
    };
    final reason = switch (failure) {
      StoreRestoreFailure.sync => '01',
      StoreRestoreFailure.unverified => '02',
      StoreRestoreFailure.callback => '03',
      StoreRestoreFailure.platform => '98',
      StoreRestoreFailure.unexpected => '99',
    };
    return 'BIL-RS-$stage-$reason';
  }

  Map<String, String> toSafeMap() => {
    'phase': phase.name,
    'reason': failure.name,
    'support_code': supportCode,
  };
}

final class _StoreRestoreAttempt {
  _StoreRestoreAttempt(this.visit, this.benefitRevision);

  final StoreAccountSnapshot visit;
  final int benefitRevision;
  StoreRestorePhase phase = StoreRestorePhase.operation;
  StoreRestoreDiagnostic? failure;
  bool sawReceipt = false;
}

extension _VerifiedStoreRestoreDiagnostics on VerifiedStorePurchaseService {
  void _clearRestoreDiagnostic() => _restoreAttempt = null;

  bool _isCurrentRestoreAttempt(_StoreRestoreAttempt attempt) =>
      !_disposed &&
      _restoring &&
      identical(_restoreAttempt, attempt) &&
      _storeVisit.isCurrent(attempt.visit);

  String? _currentRestoreSupportCode() {
    final attempt = _restoreAttempt;
    if (_disposed ||
        messageCode != 'restore_failed' ||
        attempt == null ||
        !_storeVisit.isCurrent(attempt.visit)) {
      return null;
    }
    return attempt.failure?.supportCode;
  }

  void _recordRestoreFailure(
    _StoreRestoreAttempt attempt,
    StoreRestoreDiagnostic diagnostic,
  ) {
    if (_isCurrentRestoreAttempt(attempt)) attempt.failure = diagnostic;
  }

  void _recordRestoreCallbackFailure() {
    final attempt = _restoreAttempt;
    if (attempt == null) return;
    _recordRestoreFailure(
      attempt,
      const StoreRestoreDiagnostic(
        StoreRestorePhase.callback,
        StoreRestoreFailure.callback,
      ),
    );
  }

  void _observeRestoreReceipt() {
    final attempt = _restoreAttempt;
    if (attempt != null && _isCurrentRestoreAttempt(attempt)) {
      attempt.sawReceipt = true;
    }
  }

  bool _restoreResultHasPriority(_StoreRestoreAttempt attempt) {
    if (!_isCurrentRestoreAttempt(attempt)) return false;
    // A previous cached membership is not proof for this Restore. Only the
    // same visit's newly published verified benefit, explicit ownership
    // rejection or this attempt's actual receipt-verification failure wins.
    return _restoreOwnershipConflict ||
        (verifiedBenefitRevision > attempt.benefitRevision &&
            benefitOwnerId == attempt.visit.ownerId) ||
        (attempt.sawReceipt && messageCode == 'restore_verification_failed');
  }
}
