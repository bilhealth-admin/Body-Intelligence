import 'package:body_intelligence_log/features/community/domain/community_reference_parity.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _projection({bool posts = true, bool followers = true}) =>
    {
      'user_id': '22222222-2222-4222-8222-222222222222',
      'posts_visible': posts,
      'followers_visible': followers,
      'contributor': posts ? true : null,
      'approved_posts': posts ? 8 : null,
      'followers': followers ? 12 : null,
      'likes_received': posts ? 41 : null,
      'comments_received': posts ? 18 : null,
      'qualified_referrals': 2,
      'community_xp': 900,
      'community_level': 4,
      'current_level_min_xp': 700,
      'next_community_level': 5,
      'next_level_min_xp': 1500,
      'earned_badge_count': 1,
      'total_badge_count': 2,
      'badges': [
        {'badge_key': 'profile_complete', 'earned': true},
        {'badge_key': 'referral_builder', 'earned': false},
      ],
      'certification_status': 'not_certified',
    };

void main() {
  for (final posts in [false, true]) {
    for (final followers in [false, true]) {
      test(
        'creator privacy retains hidden nullable values posts=$posts followers=$followers',
        () {
          final creator = CommunityCreatorProfile.fromJson(
            _projection(posts: posts, followers: followers),
          );
          expect(creator.postsVisible, posts);
          expect(creator.followersVisible, followers);
          expect(creator.contributor, posts ? true : null);
          expect(creator.approvedPosts, posts ? 8 : null);
          expect(creator.followers, followers ? 12 : null);
          expect(creator.likesReceived, posts ? 41 : null);
          expect(creator.commentsReceived, posts ? 18 : null);
          expect(creator.communityXp, 900);
          expect(creator.qualifiedReferrals, 2);
          expect(creator.badges, hasLength(2));
        },
      );
    }
  }

  for (final field in ['posts_visible', 'followers_visible']) {
    test('creator projection fails closed without $field', () {
      final json = _projection()..remove(field);
      expect(
        () => CommunityCreatorProfile.fromJson(json),
        throwsFormatException,
      );
    });
  }
  for (final field in [
    'approved_posts',
    'likes_received',
    'comments_received',
    'contributor',
  ]) {
    test('hidden post field $field cannot expose a fabricated value', () {
      final json = _projection(posts: false)
        ..[field] = field == 'contributor' ? false : 0;
      expect(
        () => CommunityCreatorProfile.fromJson(json),
        throwsFormatException,
      );
    });
  }
  test('hidden follower field cannot expose zero', () {
    final json = _projection(followers: false)..['followers'] = 0;
    expect(() => CommunityCreatorProfile.fromJson(json), throwsFormatException);
  });

  for (final badge in [
    'first_moment',
    'contributor',
    'conversation_starter',
    'appreciated',
    'connector',
  ]) {
    test('hidden derived badge $badge is rejected even if not earned', () {
      final json = _projection(posts: false, followers: false)
        ..['badges'] = [
          {'badge_key': badge, 'earned': false},
        ]
        ..['earned_badge_count'] = 0
        ..['total_badge_count'] = 1;
      expect(
        () => CommunityCreatorProfile.fromJson(json),
        throwsFormatException,
      );
    });
  }
}
