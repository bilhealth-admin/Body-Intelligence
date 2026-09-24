import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260925123000_community_admin_moderation_visibility.sql',
  ).readAsStringSync();
  final repository = File(
    'lib/features/community/data/community_repository.dart',
  ).readAsStringSync();
  final card = File(
    'lib/features/community/presentation/community_post_card.dart',
  ).readAsStringSync();
  final queue = File(
    'lib/features/community/presentation/community_post_moderation_page.dart',
  ).readAsStringSync();

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

  test('Flutter exposes localized hide remove and restore actions', () {
    expect(repository, contains('hidePublishedPostAsModerator'));
    expect(repository, contains('restoreHiddenPostAsModerator'));
    expect(card, contains("value: 'moderate_hide'"));
    expect(card, contains("'Hide post', 'إخفاء المنشور'"));
    expect(card, contains("'Remove post'"));
    expect(card, contains("'إزالة المنشور'"));
    expect(queue, contains("'Restore post', 'استعادة المنشور'"));
    expect(queue, contains('loadHiddenPostsForModeration'));
  });
}
