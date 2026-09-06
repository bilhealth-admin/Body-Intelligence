import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum UmpConsentPhase { uninitialized, updating, ready, blocked, notApplicable }

enum UmpPrivacyOptionsRequirement { unknown, required, notRequired }

@immutable
final class UmpConsentSnapshot {
  const UmpConsentSnapshot({
    required this.phase,
    required this.canRequestAds,
    required this.privacyOptionsRequirement,
    this.failure,
  });

  const UmpConsentSnapshot.uninitialized()
    : this(
        phase: UmpConsentPhase.uninitialized,
        canRequestAds: false,
        privacyOptionsRequirement: UmpPrivacyOptionsRequirement.unknown,
      );

  final UmpConsentPhase phase;
  final bool canRequestAds;
  final UmpPrivacyOptionsRequirement privacyOptionsRequirement;
  final Object? failure;

  bool get privacyOptionsRequired =>
      privacyOptionsRequirement == UmpPrivacyOptionsRequirement.required;
}

abstract interface class UmpConsentCoordinator {
  bool get isApplicable;
  UmpConsentSnapshot get snapshot;

  Future<UmpConsentSnapshot> refresh({bool force = false});

  /// Re-checks Google's live `canRequestAds` value immediately before an ad
  /// request. A cached ready snapshot is never sufficient at this boundary.
  Future<UmpConsentSnapshot> verifyCanRequestAds();

  Future<UmpConsentSnapshot> showPrivacyOptions();
}

abstract interface class UmpPlatformBridge {
  Future<void> requestConsentInfoUpdate();

  Future<void> loadAndShowConsentFormIfRequired();

  Future<bool> canRequestAds();

  Future<UmpPrivacyOptionsRequirement> getPrivacyOptionsRequirement();

  Future<void> showPrivacyOptionsForm();
}

/// Mobile, fail-closed gate around Google's User Messaging Platform.
///
/// UMP is BIL's sole advertising-consent authority. Product eligibility
/// (registered adult Free versus Premium or Guest) is evaluated separately;
/// no publisher-created preference can substitute for this certified flow.
final class AdMobUmpConsentGate extends ChangeNotifier
    implements UmpConsentCoordinator {
  AdMobUmpConsentGate({
    required this.platform,
    required this.isApplicable,
    this.consentInfoTimeout = const Duration(seconds: 30),
    this.machineReadTimeout = const Duration(seconds: 10),
  }) : assert(consentInfoTimeout > Duration.zero),
       assert(machineReadTimeout > Duration.zero);

  static AdMobUmpConsentGate? _instance;

  static AdMobUmpConsentGate get instance => _instance ??= AdMobUmpConsentGate(
    // Production callers reach this bridge only after BIL's existing account
    // profile has resolved through the product-wide 18+ gate.
    platform: const GoogleMobileAdsUmpPlatformBridge(
      tagForUnderAgeOfConsent: false,
    ),
    isApplicable: supportsPlatform(defaultTargetPlatform, isWeb: kIsWeb),
  );

  static bool supportsPlatform(TargetPlatform platform, {bool isWeb = false}) =>
      !isWeb &&
      (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

  final UmpPlatformBridge platform;

  @override
  final bool isApplicable;

  /// Bounds the SDK callback used to refresh machine-owned consent metadata.
  /// The human consent form that may follow is deliberately not timed out.
  final Duration consentInfoTimeout;

  /// Bounds non-interactive UMP state reads. Human-owned forms remain awaited.
  final Duration machineReadTimeout;

  UmpConsentSnapshot _snapshot = const UmpConsentSnapshot.uninitialized();
  Future<UmpConsentSnapshot>? _inFlight;
  int _operationGeneration = 0;
  int _verificationGeneration = 0;

  @override
  UmpConsentSnapshot get snapshot => _snapshot;

  void _publish(UmpConsentSnapshot value) {
    _snapshot = value;
    notifyListeners();
  }

  @override
  Future<UmpConsentSnapshot> refresh({bool force = false}) {
    if (!isApplicable) {
      const value = UmpConsentSnapshot(
        phase: UmpConsentPhase.notApplicable,
        canRequestAds: false,
        privacyOptionsRequirement: UmpPrivacyOptionsRequirement.unknown,
      );
      _publish(value);
      return Future.value(value);
    }
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    // Ready includes the legitimate user-denied state (`canRequestAds=false`),
    // so it remains cached. Blocked represents a transient machine failure and
    // must be retryable on the next eligible request without a settings detour.
    if (!force && _snapshot.phase == UmpConsentPhase.ready) {
      return Future.value(_snapshot);
    }
    final operation = _refresh();
    _inFlight = operation;
    return operation.whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
  }

  Future<UmpConsentSnapshot> _refresh() async {
    _operationGeneration++;
    _publish(
      const UmpConsentSnapshot(
        phase: UmpConsentPhase.updating,
        canRequestAds: false,
        privacyOptionsRequirement: UmpPrivacyOptionsRequirement.unknown,
      ),
    );
    try {
      // Google's guidance requires a fresh update once per process launch;
      // cached consent strings are never used as BIL's source of truth.
      await _machineCall(
        platform.requestConsentInfoUpdate(),
        operation: 'requestConsentInfoUpdate',
        timeout: consentInfoTimeout,
      );
      // Never time out an interactive consent form. While it is visible,
      // `_inFlight` remains occupied so no refresh or privacy form can overlap.
      await platform.loadAndShowConsentFormIfRequired();
      final privacyOptions = await _machineCall(
        platform.getPrivacyOptionsRequirement(),
        operation: 'getPrivacyOptionsRequirement',
        timeout: machineReadTimeout,
      );
      final canRequest = await _machineCall(
        platform.canRequestAds(),
        operation: 'canRequestAds',
        timeout: machineReadTimeout,
      );
      final value = UmpConsentSnapshot(
        phase: UmpConsentPhase.ready,
        canRequestAds: canRequest,
        privacyOptionsRequirement: privacyOptions,
      );
      _publish(value);
      return value;
    } on Object catch (error) {
      final value = UmpConsentSnapshot(
        phase: UmpConsentPhase.blocked,
        canRequestAds: false,
        privacyOptionsRequirement: UmpPrivacyOptionsRequirement.unknown,
        failure: error,
      );
      _publish(value);
      return value;
    }
  }

  @override
  Future<UmpConsentSnapshot> verifyCanRequestAds() async {
    final verificationGeneration = ++_verificationGeneration;
    final current = await refresh();
    if (!isApplicable || current.phase != UmpConsentPhase.ready) {
      return current;
    }
    final generation = _operationGeneration;
    try {
      final canRequest = await _machineCall(
        platform.canRequestAds(),
        operation: 'canRequestAds',
        timeout: machineReadTimeout,
      );
      if (generation != _operationGeneration) {
        return _supersedingOperationOrSnapshot();
      }
      if (verificationGeneration != _verificationGeneration) {
        return _staleVerificationSnapshot();
      }
      final value = UmpConsentSnapshot(
        phase: UmpConsentPhase.ready,
        canRequestAds: canRequest,
        privacyOptionsRequirement: current.privacyOptionsRequirement,
      );
      _publish(value);
      return value;
    } on Object catch (error) {
      if (generation != _operationGeneration) {
        return _supersedingOperationOrSnapshot();
      }
      if (verificationGeneration != _verificationGeneration) {
        return _staleVerificationSnapshot();
      }
      final value = UmpConsentSnapshot(
        phase: UmpConsentPhase.blocked,
        canRequestAds: false,
        privacyOptionsRequirement: UmpPrivacyOptionsRequirement.unknown,
        failure: error,
      );
      _publish(value);
      return value;
    }
  }

  @override
  Future<UmpConsentSnapshot> showPrivacyOptions() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    if (!isApplicable || !_snapshot.privacyOptionsRequired) {
      return Future.value(_snapshot);
    }
    final operation = _showPrivacyOptions();
    _inFlight = operation;
    return operation.whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
  }

  Future<UmpConsentSnapshot> _showPrivacyOptions() async {
    _operationGeneration++;
    _publish(
      UmpConsentSnapshot(
        phase: UmpConsentPhase.updating,
        canRequestAds: false,
        privacyOptionsRequirement: _snapshot.privacyOptionsRequirement,
      ),
    );
    try {
      // This form belongs to the user and must remain open for as long as the
      // user needs. Machine read limits apply only after the form completes.
      await platform.showPrivacyOptionsForm();
      final privacyOptions = await _machineCall(
        platform.getPrivacyOptionsRequirement(),
        operation: 'getPrivacyOptionsRequirement',
        timeout: machineReadTimeout,
      );
      final canRequest = await _machineCall(
        platform.canRequestAds(),
        operation: 'canRequestAds',
        timeout: machineReadTimeout,
      );
      final value = UmpConsentSnapshot(
        phase: UmpConsentPhase.ready,
        canRequestAds: canRequest,
        privacyOptionsRequirement: privacyOptions,
      );
      _publish(value);
      return value;
    } on Object catch (error) {
      final value = UmpConsentSnapshot(
        phase: UmpConsentPhase.blocked,
        canRequestAds: false,
        privacyOptionsRequirement: UmpPrivacyOptionsRequirement.unknown,
        failure: error,
      );
      _publish(value);
      return value;
    }
  }

  Future<T> _machineCall<T>(
    Future<T> future, {
    required String operation,
    required Duration timeout,
  }) => future.timeout(
    timeout,
    onTimeout: () => throw TimeoutException(
      'UMP machine operation timed out: $operation',
      timeout,
    ),
  );

  Future<UmpConsentSnapshot> _supersedingOperationOrSnapshot() {
    final inFlight = _inFlight;
    return inFlight ?? Future.value(_snapshot);
  }

  UmpConsentSnapshot _staleVerificationSnapshot() {
    final current = _snapshot;
    if (!current.canRequestAds) return current;
    // A newer live verification is authoritative. Until it publishes, an older
    // caller must not inherit the previously cached grant and start an ad load.
    return UmpConsentSnapshot(
      phase: current.phase,
      canRequestAds: false,
      privacyOptionsRequirement: current.privacyOptionsRequirement,
      failure: current.failure,
    );
  }
}

final class UmpPlatformFailure implements Exception {
  const UmpPlatformFailure(this.operation, this.code, this.message);

  final String operation;
  final int code;
  final String message;

  @override
  String toString() => 'UmpPlatformFailure($operation, $code, $message)';
}

/// Thin adapter over google_mobile_ads 9.1.0. It contains no ad-request API.
final class GoogleMobileAdsUmpPlatformBridge implements UmpPlatformBridge {
  const GoogleMobileAdsUmpPlatformBridge({
    required this.tagForUnderAgeOfConsent,
  });

  /// BIL invokes this bridge only for an eligible registered adult Free
  /// account. There is no separate advertising-age preference.
  final bool tagForUnderAgeOfConsent;

  @override
  Future<void> requestConsentInfoUpdate() {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(
        tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
      ),
      () => completer.complete(),
      (error) => completer.completeError(
        UmpPlatformFailure(
          'requestConsentInfoUpdate',
          error.errorCode,
          error.message,
        ),
      ),
    );
    return completer.future;
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() {
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(
          UmpPlatformFailure(
            'loadAndShowConsentFormIfRequired',
            error.errorCode,
            error.message,
          ),
        );
      }
    });
    return completer.future;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<UmpPrivacyOptionsRequirement> getPrivacyOptionsRequirement() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return switch (status) {
      PrivacyOptionsRequirementStatus.required =>
        UmpPrivacyOptionsRequirement.required,
      PrivacyOptionsRequirementStatus.notRequired =>
        UmpPrivacyOptionsRequirement.notRequired,
      PrivacyOptionsRequirementStatus.unknown =>
        UmpPrivacyOptionsRequirement.unknown,
    };
  }

  @override
  Future<void> showPrivacyOptionsForm() {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(
          UmpPlatformFailure(
            'showPrivacyOptionsForm',
            error.errorCode,
            error.message,
          ),
        );
      }
    });
    return completer.future;
  }
}
