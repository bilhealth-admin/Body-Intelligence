import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _repositorySource() => [
  'lib/features/community/data/community_repository.dart',
  'lib/features/community/data/community_repository_discovery_mixin.dart',
  'lib/features/community/data/community_repository_profile_moderation_mixin.dart',
  'lib/features/community/data/community_repository_publishing_mixin.dart',
  'lib/features/community/data/community_repository_connections_messaging_mixin.dart',
].map((path) => File(path).readAsStringSync()).join('\n');

void main() {
  final migration = File(
    'supabase/migrations/20260924223453_community_admin_moderation_visibility.sql',
  ).readAsStringSync();
  final repository = _repositorySource();
  final card = File(
    'lib/features/community/presentation/community_post_card.dart',
  ).readAsStringSync();
  final queue = [
    'test/support/legacy_mobile_admin/features/community/presentation/community_post_moderation_page.dart',
    'test/support/legacy_mobile_admin/features/community/presentation/community_post_moderation_load.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');

  test('admin and moderator authority is server-resolved', () {
    expect(migration, contains('private.bil_ai_coach_admins'));
    expect(migration, contains('public.bil_community_moderators'));
    expect(migration, contains('bil_resolve_community_moderation_authority'));
    expect(migration, contains("then 'admin'"));
    expect(migration, contains("then 'moderator'"));
    expect(migration, isNot(contains('p_role')));
  });

  test('hide restore and remove use distinct safe states and audit events', () {
    for (final state in const [
      'visible',
      'hidden_by_moderator',
      'removed_by_moderator',
    ]) {
      expect(migration, contains(state));
    }
    for (final event in const [
      'moderator_hide',
      'moderator_restore',
      'moderator_remove',
    ]) {
      expect(migration, contains(event));
    }
    for (final field in const [
      'actor_role',
      'post_author_id',
      'reason',
      'previous_moderation_status',
      'new_moderation_status',
      'previous_visibility',
      'new_visibility',
    ]) {
      expect(migration, contains("'$field'"));
    }
    expect(migration, contains('only_hidden_post_can_be_restored'));
  });

  test('normal reads and direct updates cannot expose hidden content', () {
    expect(migration, contains("and moderation_visibility = 'visible'"));
    expect(migration, contains("and p.moderation_visibility = 'visible'"));
    expect(migration, contains('moderation_fields_are_server_managed'));
    expect(
      migration,
      contains('revoke all on function public.bil_moderate_published'),
    );
  });

  test(
    'mobile keeps user safeguards while operator controls stay outside lib',
    () {
      expect(repository, contains('hidePublishedPostAsModerator'));
      expect(repository, contains('restoreHiddenPostAsModerator'));
      expect(card, isNot(contains("value: 'moderate_hide'")));
      expect(card, isNot(contains("'Hide post', 'إخفاء المنشور'")));
      expect(card, isNot(contains("'Remove post'")));
      expect(card, isNot(contains("'إزالة المنشور'")));
      expect(queue, contains("'Restore post', 'استعادة المنشور'"));
      expect(queue, contains('loadHiddenPostsForModeration'));
      expect(card, contains("value: 'report'"));
      expect(card, contains("value: 'block'"));
    },
  );
}
