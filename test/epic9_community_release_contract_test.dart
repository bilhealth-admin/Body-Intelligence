import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/dart_library_source.dart';

void main() {
  String source(String path) => path.endsWith('.dart')
      ? readDartLibrarySource(path)
      : File(path).readAsStringSync();

  test(
    'community repository exposes the complete authenticated social loop',
    () {
      final repository = [
        'lib/features/community/data/community_repository.dart',
        'lib/features/community/data/community_feed_repository_mixin.dart',
        'lib/features/community/data/community_social_repository_mixin.dart',
      ].map(source).join('\n');
      for (final contract in <String>[
        'loadMyProfile',
        'saveMyProfile',
        'loadFeed',
        'publishPost',
        'loadFriendshipsWithProfiles',
        'requestFriend',
        'respondToFriendship',
        'removeFriendship',
        'blockMember',
        'loadMessages',
        'sendMessage',
        'markConversationRead',
        'deletePost',
        'report',
      ]) {
        expect(repository, contains(contract), reason: contract);
      }
    },
  );

  test('community routes cover profile discovery relationships and chat', () {
    final router = source('lib/app/router/app_router.dart');
    for (final route in <String>[
      '/community',
      '/community/profile',
      '/community/people',
      '/community/connections',
      '/community/chat/:userId',
    ]) {
      expect(router, contains(route), reason: route);
    }
  });

  test(
    'chat preserves drafts, reports safe errors, and exposes read state',
    () {
      final people = [
        'lib/features/community/presentation/community_people_page.dart',
        'lib/features/community/presentation/community_chat_page.dart',
      ].map(source).join('\n');
      expect(people, contains('bool _sending = false'));
      expect(people, contains('await _repository!.markConversationRead'));
      expect(people, contains('message.isRead'));
      expect(people, contains('Your text is kept'));
      expect(people, contains('AlwaysScrollableScrollPhysics'));
      expect(people, isNot(contains(r'${snapshot.error}')));
      expect(people, isNot(contains('error.message')));
    },
  );

  test(
    'feed and relationship surfaces expose attribution and safety actions',
    () {
      final hub = [
        'lib/features/community/presentation/community_hub_page.dart',
        'lib/features/community/presentation/community_feed_tab.dart',
      ].map(source).join('\n');
      final connections = source(
        'lib/features/community/presentation/community_connections_page.dart',
      );
      expect(hub, contains('post.authorName'));
      expect(hub, contains('deletePost'));
      expect(hub, contains("targetKind: 'post'"));
      expect(connections, contains('_remove'));
      expect(connections, contains('_block'));
      expect(connections, contains('/community/chat/'));
    },
  );

  test('database boundary enforces read receipts blocks and soft deletes', () {
    final migration = source(
      'supabase/migrations/202608040001_bil_community_release_hardening.sql',
    );
    expect(migration, contains('bil_mark_conversation_read'));
    expect(migration, contains('recipient_id = auth.uid()'));
    expect(migration, contains('bil_block_community_member'));
    expect(migration, contains('delete from public.bil_friendships'));
    expect(migration, contains('deleted_by_sender_at is null'));
    expect(migration, contains('deleted_by_recipient_at is null'));
  });
}
