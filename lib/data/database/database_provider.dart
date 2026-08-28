import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import 'app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final ownerId = _activeOwnerId();
  final database = AppDatabase(localOwnerId: ownerId);
  var disposed = false;
  var invalidationScheduled = false;

  StreamSubscription<AuthState>? authSubscription;
  if (AppEnvironment.supabaseRuntimeReady) {
    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      final nextOwnerId = state.session?.user.id.trim();
      final normalizedNext = nextOwnerId == null || nextOwnerId.isEmpty
          ? null
          : nextOwnerId;
      if (normalizedNext == ownerId || disposed || invalidationScheduled) {
        return;
      }
      // Supabase may emit the signed-in event while StartupPage is building.
      // Invalidating synchronously from that callback asks ProviderScope to
      // rebuild in the middle of the same frame. Defer the account namespace
      // switch until the current synchronous build has fully unwound.
      invalidationScheduled = true;
      scheduleMicrotask(() {
        if (disposed) return;
        ref.invalidateSelf();
      });
    }, onError: (Object _, StackTrace _) {});
  }

  ref.onDispose(() {
    disposed = true;
    unawaited(authSubscription?.cancel());
    unawaited(database.close());
  });

  return database;
});

String? _activeOwnerId() {
  if (!AppEnvironment.supabaseRuntimeReady) {
    return null;
  }
  final ownerId = Supabase.instance.client.auth.currentUser?.id.trim();
  return ownerId == null || ownerId.isEmpty ? null : ownerId;
}
