import 'dart:convert';
import 'package:crypto/crypto.dart';

enum CoachMemorySyncDecision { create, update, delete, verified, conflict }

/// Retention is separate from permission to present a fact as current and
/// explicitly confirmed. Expired/inferred records are never promoted here.
bool isCurrentConfirmedCoachMemory(Map<String, Object?> value, DateTime now) {
  final text = value['text'];
  if (value['source'] != 'explicit_user_confirmation' ||
      value['status'] != 'confirmed' ||
      text is! String ||
      text.trim().isEmpty ||
      text.length > 500 ||
      DateTime.tryParse('${value['updatedAt']}') == null) {
    return false;
  }
  final expiry = value['expiresAt'];
  return expiry == null ||
      (expiry is String && DateTime.tryParse(expiry)?.isAfter(now) == true);
}

String coachMemoryFactDigest(Map<String, Object?> value) {
  final facts = <String, Object?>{};
  for (final key in const [
    'id',
    'text',
    'kind',
    'status',
    'source',
    'confidence',
    'savedAt',
    'expiresAt',
  ]) {
    if (value[key] == null) continue;
    var field = value[key];
    if (key == 'confidence' && field is num) field = field.toDouble();
    if (const {'savedAt', 'expiresAt'}.contains(key) && field is String) {
      field = DateTime.tryParse(field)?.toUtc().toIso8601String() ?? field;
    }
    facts[key] = field;
  }
  return sha256.convert(utf8.encode(jsonEncode(facts))).toString();
}

/// A three-way comparison: wall-clock ordering never authorizes overwriting
/// another device's edit. A local deletion must match the reviewed fact/base.
CoachMemorySyncDecision decideCoachMemorySync({
  required Map<String, Object?>? local,
  required Map<String, Object?>? remote,
  required String? remoteVersion,
  bool remoteDeleted = false,
  String? baselineVersion,
  String? baselineDigest,
}) {
  bool sameVersion(String? a, String? b) {
    final first = a == null ? null : DateTime.tryParse(a);
    final second = b == null ? null : DateTime.tryParse(b);
    return first != null && second != null && first.isAtSameMomentAs(second);
  }

  if (local == null) {
    if (remote == null || remoteDeleted) {
      return CoachMemorySyncDecision.verified;
    }
    return sameVersion(baselineVersion, remoteVersion) &&
            baselineDigest == coachMemoryFactDigest(remote)
        ? CoachMemorySyncDecision.delete
        : CoachMemorySyncDecision.conflict;
  }
  if (remote == null) {
    return baselineVersion == null
        ? CoachMemorySyncDecision.create
        : CoachMemorySyncDecision.conflict;
  }
  if (remoteDeleted) return CoachMemorySyncDecision.conflict;
  final digest = coachMemoryFactDigest(remote);
  if (digest == coachMemoryFactDigest(local)) {
    return CoachMemorySyncDecision.verified;
  }
  return sameVersion(baselineVersion, remoteVersion) && baselineDigest == digest
      ? CoachMemorySyncDecision.update
      : CoachMemorySyncDecision.conflict;
}
