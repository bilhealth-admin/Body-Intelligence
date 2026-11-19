import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RetryableAuthFixture extends Fake implements GoTrueClient {
  RetryableAuthFixture([String? owner = 'offline-owner-a']) {
    session = owner == null ? null : sessionFor(owner);
  }

  final changes = StreamController<AuthState>.broadcast(sync: true);
  Session? session;

  static Session sessionFor(String owner) => Session(
    accessToken: 'public-synthetic-token',
    tokenType: 'bearer',
    refreshToken: 'public-synthetic-refresh',
    user: User(
      id: owner,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );

  @override
  Session? get currentSession => session;

  @override
  User? get currentUser => session?.user;

  @override
  Stream<AuthState> get onAuthStateChange => changes.stream;

  void owner(String? value) {
    session = value == null ? null : sessionFor(value);
    changes.add(
      AuthState(
        value == null ? AuthChangeEvent.signedOut : AuthChangeEvent.signedIn,
        session,
      ),
    );
  }

  void fail(Object error) => changes.addError(error, StackTrace.current);
}

class RetryableSupabaseFixture extends Fake implements SupabaseClient {
  RetryableSupabaseFixture(this.auth);

  @override
  final GoTrueClient auth;
}
