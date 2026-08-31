import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../environment/app_environment.dart';
import '../localization/bil_locale_policy.dart';

/// Synchronizes display language only. This value is never authority for
/// access, entitlement, subscription, quota, or administrative decisions.
abstract interface class DisplayLocaleSyncGateway {
  Stream<String?> watchSignedInUserId();

  Future<void> syncLocale(String localeTag);
}

final class SupabaseDisplayLocaleSyncGateway
    implements DisplayLocaleSyncGateway {
  const SupabaseDisplayLocaleSyncGateway(this._client);

  final SupabaseClient _client;

  @override
  Stream<String?> watchSignedInUserId() async* {
    yield _client.auth.currentUser?.id;
    await for (final state in _client.auth.onAuthStateChange) {
      // Re-emit a non-null same-owner session event. It is a safe retry point
      // when a prior best-effort upsert failed while offline or during token
      // recovery. The table primary key keeps successful retries idempotent.
      yield state.session?.user.id;
    }
  }

  @override
  Future<void> syncLocale(String localeTag) async {
    final canonical = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (canonical == null) {
      throw ArgumentError.value(localeTag, 'localeTag', 'unsupported_locale');
    }
    final user = _client.auth.currentUser;
    if (user == null || _client.auth.currentSession == null) return;
    await _client.from('bil_user_locale_preferences').upsert(<String, Object?>{
      'owner_id': user.id,
      'locale_code': canonical,
    }, onConflict: 'owner_id');
  }
}

final displayLocaleSyncGatewayProvider = Provider<DisplayLocaleSyncGateway>((
  ref,
) {
  if (!AppEnvironment.supabaseRuntimeReady) {
    return const NoopDisplayLocaleSyncGateway();
  }
  return SupabaseDisplayLocaleSyncGateway(Supabase.instance.client);
});

final class NoopDisplayLocaleSyncGateway implements DisplayLocaleSyncGateway {
  const NoopDisplayLocaleSyncGateway();

  @override
  Future<void> syncLocale(String localeTag) async {}

  @override
  Stream<String?> watchSignedInUserId() => Stream<String?>.value(null);
}
