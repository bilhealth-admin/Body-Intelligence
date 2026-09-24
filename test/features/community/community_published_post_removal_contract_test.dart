import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('published-post removal is server-authorized and audited', () {
    final sql = File(
      'supabase/migrations/20260924093000_community_published_post_moderator_removal.sql',
    ).readAsStringSync();
    final repository = File(
      'lib/features/community/data/community_repository.dart',
    ).readAsStringSync();
    final card = File(
      'lib/features/community/presentation/community_post_card.dart',
    ).readAsStringSync();

    expect(sql, contains('security definer'));
    expect(sql, contains('bil_community_moderators'));
    expect(sql, contains("('spam', 'abuse', 'misleading', 'other')"));
    expect(sql, contains("'moderator_remove'"));
    expect(sql, contains('deleted_at = pg_catalog.now()'));
    expect(repository, contains("'bil_remove_published_community_post'"));
    expect(card, contains("value: 'moderate_remove'"));
    expect(card, contains("'Remove post'"));
  });
}
