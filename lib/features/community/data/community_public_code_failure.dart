import 'package:supabase_flutter/supabase_flutter.dart';

/// A small, user-safe classification for failures while creating a BIL Code.
///
/// The server intentionally returns compact, stable error identifiers. Keep
/// them inside this data boundary so presentation can guide the member without
/// exposing database or authorization details.
enum CommunityPublicCodeFailureKind {
  authenticationRequired,
  profileRequired,
  communityUnavailable,
  unavailable,
}

final class CommunityPublicCodeFailure implements Exception {
  const CommunityPublicCodeFailure(this.kind);

  const CommunityPublicCodeFailure.authenticationRequired()
    : kind = CommunityPublicCodeFailureKind.authenticationRequired;

  const CommunityPublicCodeFailure.profileRequired()
    : kind = CommunityPublicCodeFailureKind.profileRequired;

  const CommunityPublicCodeFailure.communityUnavailable()
    : kind = CommunityPublicCodeFailureKind.communityUnavailable;

  const CommunityPublicCodeFailure.unavailable()
    : kind = CommunityPublicCodeFailureKind.unavailable;

  final CommunityPublicCodeFailureKind kind;

  factory CommunityPublicCodeFailure.fromError(Object error) {
    if (error is CommunityPublicCodeFailure) return error;
    if (error is AuthException) {
      return const CommunityPublicCodeFailure.authenticationRequired();
    }

    final text = switch (error) {
      PostgrestException() => '${error.code ?? ''} ${error.message}',
      _ => error.toString(),
    }.toLowerCase();
    if (text.contains('community_profile_required')) {
      return const CommunityPublicCodeFailure.profileRequired();
    }
    if (text.contains('authentication_required') ||
        text.contains('sign-in required')) {
      return const CommunityPublicCodeFailure.authenticationRequired();
    }
    if (text.contains('community_unavailable') ||
        text.contains('community_access_suspended')) {
      return const CommunityPublicCodeFailure.communityUnavailable();
    }
    return const CommunityPublicCodeFailure.unavailable();
  }
}
