import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Request suppression only. These hashes and deadlines never grant access,
/// acknowledge a receipt, or extend a subscription/credit balance.
final class StoreVerificationRequestPolicy {
  StoreVerificationRequestPolicy({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static final shared = StoreVerificationRequestPolicy();
  final DateTime Function() _clock;
  final _retryAt = <String, DateTime>{};
  final _settled = <String, DateTime>{};
  static const _maximumEntries = 512;
  static const _settledReplayAge = Duration(hours: 1);

  bool isBackedOff(String? ownerId) {
    if (ownerId == null) return false;
    final now = _clock().toUtc();
    _prune(_retryAt, now);
    return _retryAt[_ownerKey(ownerId)]?.isAfter(now) == true;
  }

  void observeFailure({
    required String ownerId,
    required int status,
    required Object? body,
  }) {
    if ((status != 429 && status != 503) ||
        body is! Map ||
        body['error'] != 'rate_limited') {
      return;
    }
    // functions_client exposes status/details but not response headers. The
    // server therefore also publishes Retry-After in this allowlisted field.
    final supplied = body['retry_after_seconds'];
    final seconds = supplied is int && supplied >= 1 && supplied <= 3600
        ? supplied
        : 300; // Bounded compatibility with the previous 503 response.
    final now = _clock().toUtc();
    final key = _ownerKey(ownerId);
    final next = now.add(Duration(seconds: seconds));
    final prior = _retryAt[key];
    if (prior == null || next.isAfter(prior)) _retryAt[key] = next;
    _prune(_retryAt, now);
  }

  bool isSettledReplay(String key) {
    final now = _clock().toUtc();
    _prune(_settled, now);
    return _settled[key]?.isAfter(now) == true;
  }

  /// Call only after server verification AND successful native finish (or
  /// verified absence of an unfinished native transaction).
  void rememberSettled(String key) {
    final now = _clock().toUtc();
    _settled[key] = now.add(_settledReplayAge);
    _prune(_settled, now);
  }

  void resetForTesting() {
    _retryAt.clear();
    _settled.clear();
  }

  static String _ownerKey(String owner) =>
      sha256.convert(utf8.encode(owner)).toString();

  static void _prune(Map<String, DateTime> values, DateTime now) {
    values.removeWhere((_, until) => !until.isAfter(now));
    while (values.length > _maximumEntries) {
      values.remove(values.keys.first);
    }
  }
}

/// Include the exact signed/native verification payload and status as well as
/// the transaction ID. A new signed revocation/renewal payload must be verified
/// even when the native transaction ID is unchanged. No raw receipt is stored.
String storeReceiptReplayKey({
  required String ownerId,
  required String source,
  required String productId,
  required String? purchaseId,
  required String status,
  required String verificationData,
}) => sha256
    .convert(
      utf8.encode(
        jsonEncode([
          ownerId,
          source,
          productId,
          purchaseId,
          status,
          sha256.convert(utf8.encode(verificationData)).toString(),
        ]),
      ),
    )
    .toString();
