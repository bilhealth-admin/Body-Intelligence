import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile discovery exposes only bounded public identity fields', () {
    final sql = File(
      'supabase/migrations/20260823002000_community_profile_discovery_rpc.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('security definer'));
    expect(sql, contains('auth.uid() is not null'));
    expect(sql, contains('p.discoverable = true'));
    expect(sql, contains('p.allow_friend_requests = true'));
    expect(sql, contains('from public.bil_blocks'));
    expect(sql, contains('least(greatest(coalesce(p_limit, 30), 1), 30)'));
    expect(sql, contains('user_id uuid'));
    expect(sql, contains('display_name text'));
    expect(sql, contains('avatar_url text'));
    expect(sql, contains('locale_code text'));
    expect(sql, isNot(contains('bio text')));
    expect(sql, isNot(contains('email')));
    expect(
      sql,
      contains(
        'revoke all on function public.bil_search_community_profiles(text, integer)',
      ),
    );
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
  });

  test(
    'client search uses the bounded discovery rpc rather than table RLS',
    () {
      final source = File(
        'lib/features/community/data/community_repository.dart',
      ).readAsStringSync();

      final methodStart = source.indexOf('searchProfiles(String query)');
      final nextMethod = source.indexOf('User get _user', methodStart);
      final method = source.substring(methodStart, nextMethod);
      expect(method, contains("'bil_search_community_profiles'"));
      expect(method, isNot(contains("from('bil_public_profiles')")));
      expect(method, isNot(contains("row['bio']")));
    },
  );

  test('connection identities are disclosed only to relationship parties', () {
    final sql = File(
      'supabase/migrations/202608240001_community_connection_identity_and_message_realtime.sql',
    ).readAsStringSync().toLowerCase();
    final repository = File(
      'lib/features/community/data/community_repository.dart',
    ).readAsStringSync();

    expect(sql, contains('bil_list_community_connections'));
    expect(sql, contains('security definer'));
    expect(sql, contains('auth.uid() is not null'));
    expect(sql, contains('auth.uid() in (f.requester_id, f.addressee_id)'));
    expect(sql, contains("f.status in ('pending', 'accepted')"));
    expect(sql, contains('from public.bil_blocks'));
    expect(sql, contains('display_name text'));
    expect(sql, contains('avatar_url text'));
    expect(sql, isNot(contains('email')));
    expect(
      repository,
      contains("_client.rpc('bil_list_community_connections')"),
    );
  });
}
