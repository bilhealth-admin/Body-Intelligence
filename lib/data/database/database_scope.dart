import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Stable, privacy-preserving local storage namespace for one BIL identity.
///
/// Authenticated accounts receive their own SQLite file. Signed-out/local mode
/// uses a separate guest file. The raw Supabase user id is never written into
/// the filename.
final class LocalDatabaseScope {
  const LocalDatabaseScope._();

  static const guestKey = 'guest';

  static String keyForOwner(String? ownerId) {
    final normalized = ownerId?.trim() ?? '';
    if (normalized.isEmpty) return guestKey;
    final digest = sha256.convert(utf8.encode(normalized)).toString();
    return 'account_${digest.substring(0, 24)}';
  }

  static String databaseFileName(String? ownerId) =>
      'body_intelligence_${keyForOwner(ownerId)}.sqlite';

  /// Legacy `body_intelligence.sqlite` may be adopted only when it is
  /// unowned guest data or already belongs to the active authenticated user.
  static bool canAdoptLegacyDatabase({
    required String? activeOwnerId,
    required String? legacyOwnerId,
  }) {
    final active = _normalize(activeOwnerId);
    final legacy = _normalize(legacyOwnerId);
    if (active == null) return legacy == null;
    return legacy == null || legacy == active;
  }

  static String? _normalize(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
