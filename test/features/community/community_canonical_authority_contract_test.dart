import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all privileged Community RPCs use canonical server authority', () {
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.replaceAll('\\', '/').endsWith(
            '_final_hardening_cloud_consent_community_authority.sql',
          ),
        )
        .toList(growable: false);
    expect(
      migrations,
      hasLength(1),
      reason: 'Community authority must have one canonical migration source.',
    );
    final source = migrations.single.readAsStringSync();

    const privilegedRpcs = <String>[
      'bil_list_pending_community_posts',
      'bil_list_open_community_reports',
      'bil_moderate_community_report',
      'bil_list_reviewable_products',
      'bil_finalize_food_submission',
      'bil_moderate_community_post',
      'bil_can_moderate_community_post_image',
    ];

    for (final rpc in privilegedRpcs) {
      expect(
        source,
        contains(RegExp('function public\\.$rpc', caseSensitive: false)),
      );
    }
    expect(
      RegExp(
        'private\\.bil_resolve_community_moderation_authority',
      ).allMatches(source).length,
      greaterThanOrEqualTo(privilegedRpcs.length),
    );
    expect(source, contains('moderator_or_administrator_required'));
    expect(source, isNot(contains("raise exception 'moderator_required'")));
  });
}
