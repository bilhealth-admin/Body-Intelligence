import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StoreReviewMoment { dailyCheckIn, diaryCompleted, planSaved }

enum StoreReviewOutcome {
  unsupported,
  notYetEligible,
  coolingDown,
  unavailable,
  requested,
  failed,
}

abstract interface class StoreReviewGateway {
  Future<bool> isAvailable();

  Future<void> requestReview();
}

final class NativeStoreReviewGateway implements StoreReviewGateway {
  NativeStoreReviewGateway({InAppReview? review})
    : _review = review ?? InAppReview.instance;

  final InAppReview _review;

  @override
  Future<bool> isAvailable() => _review.isAvailable();

  @override
  Future<void> requestReview() => _review.requestReview();
}

/// Records meaningful success moments and asks the operating system for its
/// native review sheet only when the user has had enough time to judge BIL.
///
/// There is deliberately no custom pre-prompt, sentiment question, star UI or
/// promise that a prompt will appear. Google Play and StoreKit apply their own
/// private quotas and remain the final authority over presentation.
final class StoreReviewPromptService {
  StoreReviewPromptService({
    required this._gateway,
    DateTime Function()? now,
    Future<SharedPreferences> Function()? preferences,
    bool Function()? isSupportedPlatform,
    this.presentationDelay = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now,
       _preferences = preferences ?? SharedPreferences.getInstance,
       _isSupportedPlatform = isSupportedPlatform ?? _defaultSupportedPlatform;

  static const minimumExperience = Duration(days: 7);
  static const minimumSuccessfulDays = 5;
  static const promptCooldown = Duration(days: 180);

  static const _firstSuccessKey = 'bil_store_review_first_success_ms';
  static const _successfulDaysKey = 'bil_store_review_success_days_v1';
  static const _lastAttemptKey = 'bil_store_review_last_attempt_ms';

  final StoreReviewGateway _gateway;
  final DateTime Function() _now;
  final Future<SharedPreferences> Function() _preferences;
  final bool Function() _isSupportedPlatform;
  final Duration presentationDelay;
  bool _requestInFlight = false;

  Future<StoreReviewOutcome> recordPositiveMoment(
    StoreReviewMoment moment,
  ) async {
    if (!_isSupportedPlatform()) return StoreReviewOutcome.unsupported;

    final now = _now().toUtc();
    final preferences = await _preferences();
    final firstSuccessMs = preferences.getInt(_firstSuccessKey);
    if (firstSuccessMs == null) {
      await preferences.setInt(_firstSuccessKey, now.millisecondsSinceEpoch);
    }

    final successfulDays = _readSuccessfulDays(preferences)..add(_dayKey(now));
    await preferences.setString(
      _successfulDaysKey,
      jsonEncode(successfulDays.toList()..sort()),
    );

    final firstSuccess = DateTime.fromMillisecondsSinceEpoch(
      firstSuccessMs ?? now.millisecondsSinceEpoch,
      isUtc: true,
    );
    if (now.difference(firstSuccess) < minimumExperience ||
        successfulDays.length < minimumSuccessfulDays) {
      return StoreReviewOutcome.notYetEligible;
    }

    final lastAttemptMs = preferences.getInt(_lastAttemptKey);
    if (lastAttemptMs != null) {
      final lastAttempt = DateTime.fromMillisecondsSinceEpoch(
        lastAttemptMs,
        isUtc: true,
      );
      if (now.difference(lastAttempt) < promptCooldown) {
        return StoreReviewOutcome.coolingDown;
      }
    }
    if (_requestInFlight) return StoreReviewOutcome.coolingDown;

    _requestInFlight = true;
    try {
      if (!await _gateway.isAvailable()) {
        return StoreReviewOutcome.unavailable;
      }
      if (presentationDelay > Duration.zero) {
        await Future<void>.delayed(presentationDelay);
      }
      // Persist before crossing the platform boundary so a lifecycle change or
      // process death cannot cause a duplicate request on the next success.
      await preferences.setInt(_lastAttemptKey, now.millisecondsSinceEpoch);
      await _gateway.requestReview();
      return StoreReviewOutcome.requested;
    } catch (_) {
      return StoreReviewOutcome.failed;
    } finally {
      _requestInFlight = false;
    }
  }

  static Set<String> _readSuccessfulDays(SharedPreferences preferences) {
    final encoded = preferences.getString(_successfulDaysKey);
    if (encoded == null || encoded.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return <String>{};
      return decoded.whereType<String>().toSet();
    } on FormatException {
      return <String>{};
    }
  }

  static String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static bool _defaultSupportedPlatform() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}

final storeReviewPromptServiceProvider = Provider<StoreReviewPromptService>((
  ref,
) {
  return StoreReviewPromptService(gateway: NativeStoreReviewGateway());
});
