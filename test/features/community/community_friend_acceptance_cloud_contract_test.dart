import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Community cloud records profile-less requests and friend acceptance', () {
    final requestSql = File(
      'supabase/migrations/20261003011205_community_profileless_friend_request_e2e_20261003.sql',
    ).readAsStringSync();
    final acceptanceSql = File(
      'supabase/migrations/20261003014554_community_friend_acceptance_attention_push_v2.sql',
    ).readAsStringSync();

    expect(
      requestSql,
      isNot(contains("raise exception 'community_profile_required'")),
    );
    expect(requestSql, contains('allow_friend_requests'));
    expect(requestSql, contains('bil_consume_rate_limit'));
    expect(acceptanceSql, contains('bil_community_notifications'));
    expect(
      acceptanceSql,
      contains("old.status='pending' and new.status='accepted'"),
    );
    expect(acceptanceSql, contains('bil://community/notifications'));
    expect(acceptanceSql, contains("'community_updates'"));
    expect(acceptanceSql, contains('bil_register_push_token_v2'));
    expect(acceptanceSql, contains('bil_set_push_delivery_categories_v2'));
    expect(acceptanceSql, contains('friend_accepted_enabled'));
    expect(acceptanceSql, contains('alter publication supabase_realtime'));
  });
}
