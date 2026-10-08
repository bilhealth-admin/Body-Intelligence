import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

String _readProfileActivity() => [
  'lib/features/community/home_profile/community_profile_activity_slivers.dart',
  'lib/features/community/home_profile/community_profile_activity_media.dart',
].map(_read).join('\n');

void main() {
  test('Profile exposes Posts Replies Media Likes with distinct sources', () {
    // Runtime implementation is split across same-library Dart parts to
    // respect the architecture size ceiling. Verify the combined contract.
    final profile = _readProfileActivity();
    final data = _read(
      'lib/features/community/home_profile/community_profile_activity_repository.dart',
    );

    for (final tab in ['posts', 'replies', 'media', 'likes']) {
      expect(profile, contains('community-profile-tab-$tab'));
    }
    expect(profile, contains('for (final media in post.mediaItems)'));
    expect(
      profile,
      contains(
        r'community-profile-media-${entry.post.id}-${entry.media.position}',
      ),
    );
    expect(profile, contains('_loadProfileReplies(reset: true)'));
    expect(profile, contains('_loadProfileLikes(reset: true)'));
    expect(data, contains("'bil_community_profile_replies_v1'"));
    expect(data, contains("'bil_community_profile_likes_v1'"));
    expect(data, contains('loadPostsByIds(postIds)'));
  });

  test('Replies and Likes privacy is fail closed in client and SQL', () {
    final data = _read(
      'lib/features/community/home_profile/community_profile_activity_repository.dart',
    );
    final sql = _read(
      'tool/qa_parallel/bil08/sql/20261007_bil08_community_profile_activity_v1.sql',
    );

    expect(data, contains('if (userId != repository.currentUserId)'));
    expect(data, contains('CommunityProfileLikesPrivateException'));
    expect(sql, contains('p_user_id <> v_viewer'));
    expect(sql, contains('profile.show_posts'));
    expect(sql, contains('bil_social_profile_visible_v2(p_user_id)'));
    expect(sql, contains('comment.deleted_at is null'));
    expect(sql, contains('comment.removed_at is null'));
    expect(sql, contains('root.deleted_at is null'));
    expect(sql, contains('root.removed_at is null'));
    expect(sql, contains('bil_social_post_visible_v2(comment.post_id)'));
    expect(sql, contains("raise exception 'community_profile_likes_private'"));
    expect(sql, contains('bil_social_post_visible_v2(post_like.post_id)'));
  });

  test('Home Feed cards and polls retain permanent owner visit fences', () {
    final home = _read(
      'lib/features/community/home_profile/community_home_owner_scope.dart',
    );
    final feedScope = _read(
      'lib/features/community/home_profile/community_feed_owner_scope.dart',
    );
    final feed = _read(
      'lib/features/community/presentation/community_feed_tab.dart',
    );
    final paging = _read(
      'lib/features/community/presentation/community_feed_pagination.dart',
    );

    expect(home, contains('_homeVisitEpoch'));
    expect(home, contains('_deliveredOwnerId'));
    expect(home, contains('epoch != _homeVisitEpoch'));
    expect(home, contains('currentSdkOwner == nextOwner'));
    expect(feedScope, contains('parentVisit?.call() ?? true'));
    expect(feed, contains('ownerIsCurrent: visit.isCurrent'));
    expect(feed, contains('ownerChanges: visit.changes'));
    expect(feed, contains('_captureFeedVisit()'));
    expect(paging, contains('await visit.run(() async {'));
  });

  test('Future-return setState regression stays closed', () {
    final feed = _read(
      'lib/features/community/presentation/community_feed_tab.dart',
    );
    final moderation = _read(
      'lib/features/community/presentation/community_post_moderation_page.dart',
    );

    expect(feed, isNot(contains('setState(() => _feed = refreshedFeed)')));
    expect(moderation, isNot(contains('setState(() => _queue = refreshed)')));
    expect(
      moderation,
      contains('setState(() {\n      _queue = refreshed;\n    });'),
    );
  });

  test('Saved and Drafts remain separate surfaces', () {
    final hub = _read(
      'lib/features/community/presentation/community_hub_page.dart',
    );
    final navigation = _read(
      'lib/features/community/presentation/community_navigation_sheet.dart',
    );
    final drafts = _read(
      'lib/features/community/presentation/community_member_profile_drafts.dart',
    );

    expect(navigation, contains("'/community/drafts'"));
    expect(navigation, contains("'saved'"));
    expect(hub, contains('CommunitySavedPostsPage'));
    final profile = _read(
      'lib/features/community/presentation/community_member_profile_page.dart',
    );
    // Draft navigation lives in the split profile part; the hub still owns
    // the Saved surface. Check both destinations without asserting a stale
    // implementation-file location.
    expect(profile, contains("context.push('/community/drafts')"));
    expect(drafts, isNot(contains('CommunitySavedPostsPage')));
  });

  test('Rich four-image and poll paths remain reachable', () {
    final media = _read(
      'lib/features/community/presentation/community_post_widgets.dart',
    );
    final poll = _read(
      'lib/features/community/presentation/community_poll_panel.dart',
    );
    // Runtime implementation is split across same-library Dart parts to
    // respect the architecture size ceiling. Verify the combined contract.
    final profile = _readProfileActivity();

    expect(media, contains('media.take(4)'));
    expect(media, contains(r'community-post-media-${post.id}-3'));
    expect(poll, contains('voteCommunityPoll'));
    expect(poll, contains('ownerIsCurrent'));
    expect(profile, contains('for (final media in post.mediaItems)'));
  });
}
