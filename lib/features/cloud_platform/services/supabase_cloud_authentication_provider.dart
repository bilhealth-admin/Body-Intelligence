import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/cloud_identity_models.dart';
import '../domain/cloud_operational_models.dart';
import 'cloud_durable_ports.dart';

/// Supabase Auth adapter used by the cloud composition root.
///
/// Passwords are passed directly to the SDK and are never persisted, logged,
/// placed in provider state, or copied into diagnostics.
final class SupabaseCloudAuthenticationProvider
    implements CloudAuthenticationProvider {
  const SupabaseCloudAuthenticationProvider(this.client);

  final SupabaseClient client;

  @override
  Future<CloudAccount> signUp({
    required String email,
    required String secret,
  }) async {
    final response = await client.auth.signUp(email: email, password: secret);
    final user = response.user;
    if (user == null) {
      throw StateError('Cloud account creation was not confirmed.');
    }
    return CloudAccount(
      ownerId: user.id,
      email: user.email ?? email,
      status: CloudAccountStatus.active,
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now().toUtc(),
    );
  }

  @override
  Future<CloudSession> signIn({
    required String email,
    required String secret,
    required String deviceId,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: secret,
    );
    final session = response.session;
    final user = response.user;
    if (session == null || user == null) {
      throw StateError('Authenticated cloud session unavailable.');
    }
    return cloudSessionFromSupabase(session: session, deviceId: deviceId);
  }

  @override
  Future<void> signOut(String sessionId) => client.auth.signOut();

  @override
  Future<void> disableAccount(String ownerId) async {
    _requireCurrentOwner(ownerId);
    // Disabling/deleting another Auth user requires a trusted server. Mobile
    // clients intentionally fail closed instead of embedding a service key.
    throw UnsupportedError(
      'Account disabling requires the BIL trusted server.',
    );
  }

  @override
  Future<void> deleteAccount(String ownerId) async {
    _requireCurrentOwner(ownerId);
    throw UnsupportedError('Account deletion requires the BIL trusted server.');
  }

  void _requireCurrentOwner(String ownerId) {
    if (client.auth.currentUser?.id != ownerId) {
      throw StateError('Authenticated cloud owner mismatch.');
    }
  }

  static CloudSession cloudSessionFromSupabase({
    required Session session,
    required String deviceId,
  }) {
    final issuedAt = DateTime.fromMillisecondsSinceEpoch(
      session.user.lastSignInAt == null
          ? DateTime.now().toUtc().millisecondsSinceEpoch
          : DateTime.parse(session.user.lastSignInAt!).millisecondsSinceEpoch,
      isUtc: true,
    );
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      (session.expiresAt ?? 0) * 1000,
      isUtc: true,
    );
    if (!expiresAt.isAfter(issuedAt)) {
      throw StateError('Supabase session has no usable expiry.');
    }
    return CloudSession(
      // The access/refresh token is deliberately not copied into app state.
      sessionId: 'supabase:${session.user.id}:${session.expiresAt}',
      ownerId: session.user.id,
      deviceId: deviceId,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
    );
  }
}
