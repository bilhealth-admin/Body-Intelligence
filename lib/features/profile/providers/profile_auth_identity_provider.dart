import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';

@immutable
class ProfileAuthIdentity {
  const ProfileAuthIdentity({required this.ownerId, required this.email});

  const ProfileAuthIdentity.local() : ownerId = null, email = null;

  final String? ownerId;
  final String? email;

  bool get isAuthenticated => ownerId != null;

  String hydrationKey(String profileId) => '${ownerId ?? 'local'}:$profileId';

  static ProfileAuthIdentity fromUser(User? user) {
    final owner = user?.id.trim();
    final email = user?.email?.trim();
    return ProfileAuthIdentity(
      ownerId: owner == null || owner.isEmpty ? null : owner,
      email: email == null || email.isEmpty ? null : email,
    );
  }
}

/// Resolves the email shown on Profile without allowing an account-scoped
/// cache to cover the currently authenticated member.
String resolveAuthoritativeProfileEmail({
  required ProfileAuthIdentity authIdentity,
  required String? cachedEmail,
}) {
  final cached = cachedEmail?.trim() ?? '';
  if (!authIdentity.isAuthenticated) return cached;
  return authIdentity.email?.trim() ?? '';
}

/// Emits the authenticated profile identity across sign-in/sign-out switches.
/// Local cached identity is deliberately not part of this authority boundary.
final profileAuthIdentityProvider = StreamProvider<ProfileAuthIdentity>((
  ref,
) async* {
  if (!AppEnvironment.supabaseRuntimeReady) {
    yield const ProfileAuthIdentity.local();
    return;
  }
  final auth = Supabase.instance.client.auth;
  yield ProfileAuthIdentity.fromUser(auth.currentUser);
  await for (final state in auth.onAuthStateChange) {
    yield ProfileAuthIdentity.fromUser(state.session?.user);
  }
});
