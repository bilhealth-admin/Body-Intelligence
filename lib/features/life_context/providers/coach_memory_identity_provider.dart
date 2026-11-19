import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../data/database/database_provider.dart';
import '../../auth/retryable_auth_session.dart';
import '../../profile/providers/profile_auth_identity_provider.dart'
    show ProfileAuthIdentity;

/// Local-memory identity I/O only. No entitlement or remote AI dependency.
final coachMemoryAuthClientProvider = Provider<GoTrueClient?>((ref) {
  // Re-resolve an initially unavailable SDK after a real namespace transition.
  ref.watch(databaseProvider);
  if (!AppEnvironment.supabaseRuntimeReady) return null;
  return Supabase.instance.client.auth;
});

/// A typed same-lifetime transport error does not prevent reading local facts.
/// All actual auth events, including null and A -> B -> A, remain authoritative.
final coachMemoryIdentityProvider = StreamProvider<ProfileAuthIdentity>((ref) {
  final auth = ref.watch(coachMemoryAuthClientProvider);
  if (auth == null) return Stream.value(const ProfileAuthIdentity.local());
  return Stream<ProfileAuthIdentity>.multi((events) {
    var previousOwnerId = auth.currentUser?.id;
    var identityKnown = true;
    events.add(ProfileAuthIdentity(ownerId: previousOwnerId, email: null));
    final subscription = auth.onAuthStateChange.listen(
      (state) {
        previousOwnerId = state.session?.user.id;
        identityKnown = true;
        events.add(ProfileAuthIdentity(ownerId: previousOwnerId, email: null));
      },
      onError: (Object error, StackTrace stack) {
        final sameOwnedSession = isSameOwnerRetryableAuthReadFailure(
          error,
          auth: auth,
          previousOwnerId: previousOwnerId,
        );
        // Guest local memory never requires an authenticated grant. Retain an
        // ALREADY observed guest only for the same narrow transport category.
        final sameLocalGuest =
            previousOwnerId == null &&
            auth.currentUser == null &&
            auth.currentSession == null &&
            error is AuthRetryableFetchException &&
            error.statusCode != '401' &&
            error.statusCode != '403';
        if (identityKnown && (sameOwnedSession || sameLocalGuest)) return;
        identityKnown = false;
        previousOwnerId = null;
        events.addError(error, stack);
      },
      onDone: () {
        identityKnown = false;
        events.addError(StateError('coach_memory_auth_stream_closed'));
        events.close();
      },
    );
    events.onCancel = subscription.cancel;
  });
  // A fatal error cannot silently reseed the same SDK cache as a new identity.
  // A subsequent real AuthState event or replaced client can recover normally.
}, retry: (_, _) => null);
