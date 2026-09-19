import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('post soft-delete uses the atomic owner-checked RPC', () {
    final source = File(
      'lib/features/community/data/community_post_cloud_store.dart',
    ).readAsStringSync();

    expect(source, contains("'bil_delete_community_post'"));
    expect(source, contains("params: {'p_post_id': postId}"));
    expect(source, contains('if (deleted != true)'));
  });

  test('post deletion uses the owner-checked database RPC', () {
    final source = File(
      'lib/features/community/data/community_post_cloud_store.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260919090000_fix_community_post_owner_delete_policy.sql',
    ).readAsStringSync();

    expect(source, contains("'bil_delete_community_post'"));
    expect(source, contains("params: {'p_post_id': postId}"));
    expect(source, contains('if (deleted != true)'));
    expect(migration, contains('bil_delete_community_post(p_post_id uuid)'));
    expect(migration, contains('author_id = auth.uid()'));
    expect(migration, contains('deleted_at is null'));
    expect(migration, contains('grant execute on function'));
    expect(migration, isNot(contains('with check')));
  });
}
