import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/domain/community_topics.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_post_moderation_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/community_interaction_test_support.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _ModerationRepository extends CommunityRepository {
  _ModerationRepository()
    : super(
        SupabaseClient(
          'https://moderation.invalid',
          'moderation-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  static const authorId = '11111111-1111-4111-8111-111111111111';
  static const moderatorId = '22222222-2222-4222-8222-222222222222';
  static const postId = '33333333-3333-4333-8333-333333333333';

  bool includePendingPost = true;
  int moderationCalls = 0;
  CommunityPostModerationDecision? lastDecision;

  CommunityPost get pendingPost => CommunityPost(
    id: postId,
    authorId: authorId,
    authorName: 'Pending author',
    body: 'A post that requires a human decision',
    createdAt: DateTime.utc(2026, 9, 4),
    moderationStatus: CommunityPostModerationStatus.pending,
  );

  @override
  String get currentUserId => moderatorId;

  @override
  Future<List<CommunityPost>> loadPendingPostsForModeration({
    int limit = 100,
  }) async => includePendingPost ? [pendingPost] : const [];

  @override
  Future<List<CommunityPost>> loadHiddenPostsForModeration({
    int limit = 100,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> loadOpenModerationReports() async =>
      const [];

  @override
  Future<CommunityPostModerationResult> moderatePost({
    required String postId,
    required CommunityPostModerationDecision decision,
  }) async {
    moderationCalls++;
    lastDecision = decision;
    includePendingPost = false;
    return CommunityPostModerationResult(
      postId: postId,
      decision: decision,
      duplicate: false,
      tokensGranted: decision == CommunityPostModerationDecision.approved
          ? 5
          : 0,
    );
  }
}

final class _OwnerFeedRepository extends CommunityRepository {
  _OwnerFeedRepository()
    : super(
        SupabaseClient(
          'https://owner-feed.invalid',
          'owner-feed-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  static const ownerId = '44444444-4444-4444-8444-444444444444';

  @override
  String get currentUserId => ownerId;

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => [
    CommunityPost(
      id: '55555555-5555-4555-8555-555555555555',
      authorId: ownerId,
      authorName: 'Post owner',
      body: 'Only I can see this while it is reviewed',
      createdAt: DateTime.utc(2026, 9, 4),
      moderationStatus: CommunityPostModerationStatus.pending,
    ),
  ];

  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async => const [];
}

final class _ModerationRefreshRepository extends _ModerationRepository {
  static const nextPostId = '55555555-5555-4555-8555-555555555555';

  int feedLoads = 0;
  int queueLoads = 0;
  final mutations = <(String, String, String)>[];
  Completer<List<CommunityPost>>? feedReadback;
  Completer<List<CommunityPost>>? queueReadback;

  CommunityPost get initialFeedPost => CommunityPost(
    id: _ModerationRepository.postId,
    authorId: _ModerationRepository.authorId,
    authorName: 'Another member',
    body: 'Original published post',
    createdAt: DateTime.utc(2026, 9, 4),
    moderationStatus: CommunityPostModerationStatus.approved,
  );

  CommunityPost get nextFeedPost => CommunityPost(
    id: nextPostId,
    authorId: _ModerationRepository.authorId,
    authorName: 'Another member',
    body: 'Next server post',
    createdAt: DateTime.utc(2026, 9, 3),
    moderationStatus: CommunityPostModerationStatus.approved,
  );

  @override
  Future<bool> isCommunityModerator() async => true;

  @override
  Future<CommunityProfileOverview?> loadMyProfileOverview() async => null;

  @override
  Future<List<CommunityTopic>> loadCommunityTopics() async => const [];

  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> loadMyFoodSubmissions() async => const [];

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) async => const CommunityPolicyState.unavailable();

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) {
    feedLoads++;
    return feedReadback?.future ??
        Future<List<CommunityPost>>.value([initialFeedPost]);
  }

  @override
  Future<List<CommunityPost>> loadPendingPostsForModeration({int limit = 100}) {
    queueLoads++;
    return queueReadback?.future ??
        super.loadPendingPostsForModeration(limit: limit);
  }

  @override
  Future<void> removePublishedPostAsModerator({
    required String postId,
    required String reason,
  }) async {
    mutations.add(('remove', postId, reason));
  }

  @override
  Future<void> hidePublishedPostAsModerator({
    required String postId,
    required String reason,
  }) async {
    mutations.add(('hide', postId, reason));
  }
}

void main() {
  group('moderation refresh rebuilds from the new readback', () {
    late _ModerationRefreshRepository repository;

    // Supabase JSON/process lifecycle belongs to the real runner zone.
    setUp(() {
      repository = _ModerationRefreshRepository();
    });

    tearDown(() async {
      await repository.communitySocialClient.dispose();
    });

    for (final action in ['remove', 'hide']) {
      testWidgets('feed $action succeeds and renders its refreshed result', (
        tester,
      ) async {
        final readback = Completer<List<CommunityPost>>();
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: CommunityHubPage(
                repository: repository,
                entryWelcomeHandled: true,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(repository.feedLoads, 1);

          repository.feedReadback = readback;
          final actions = find.byKey(
            const Key(
              'community-post-actions-33333333-3333-4333-8333-333333333333',
            ),
          );
          await tapCommunityControl(tester, actions);
          await tester.pumpAndSettle();

          await tester.tap(
            find.text(action == 'remove' ? 'Remove post' : 'Hide post'),
          );
          await tester.pumpAndSettle();
          expect(repository.mutations, isEmpty);

          await tester.tap(find.widgetWithText(SimpleDialogOption, 'spam'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(repository.mutations, [
            (action, _ModerationRepository.postId, 'spam'),
          ]);
          expect(repository.feedLoads, 2);

          readback.complete([repository.nextFeedPost]);
          await tester.pumpAndSettle();

          await revealCommunityControl(
            tester,
            find.byKey(
              const Key(
                'community-post-actions-55555555-5555-4555-8555-555555555555',
              ),
            ),
          );
          expect(find.text('Next server post'), findsOneWidget);
          expect(actions, findsNothing);
          expect(repository.feedLoads, 2);
          expect(repository.mutations, hasLength(1));
          // Feed catches the framework error. No uncaught exception alone
          // would miss the false failure message after a successful mutation.
          expect(
            find.text(
              action == 'remove'
                  ? 'Post removed by moderation.'
                  : 'Post hidden by moderation.',
            ),
            findsOneWidget,
          );
          expect(
            find.text('Could not complete that action safely. Try again.'),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        } finally {
          if (!readback.isCompleted) {
            readback.complete(const []);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      });
    }

    testWidgets('queue refresh renders the completed replacement future', (
      tester,
    ) async {
      final readback = Completer<List<CommunityPost>>();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: CommunityPostModerationPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        expect(repository.queueLoads, 1);
        expect(
          find.text('A post that requires a human decision'),
          findsOneWidget,
        );

        repository.queueReadback = readback;
        await tester.tap(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.refresh_rounded),
          ),
        );
        await tester.pump();
        expect(repository.queueLoads, 2);

        readback.complete(const []);
        await tester.pumpAndSettle();

        expect(repository.queueLoads, 2);
        expect(repository.moderationCalls, 0);
        expect(
          find.text('A post that requires a human decision'),
          findsNothing,
        );
        expect(find.text('The moderation queue is clear.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        if (!readback.isCompleted) {
          readback.complete(const []);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });
  });

  test('migration makes post review private, atomic, and idempotent', () {
    final sql = File(
      'supabase/migrations/20260904030000_community_post_human_moderation.sql',
    ).readAsStringSync().toLowerCase();

    final backfill = sql.indexOf("set moderation_status = 'approved'");
    final pendingDefault = sql.indexOf(
      "alter column moderation_status set default 'pending'",
    );
    final moderatorPreflight = sql.indexOf('moderator_preflight');
    expect(backfill, greaterThanOrEqualTo(0));
    expect(pendingDefault, greaterThan(backfill));
    expect(moderatorPreflight, greaterThanOrEqualTo(0));
    expect(pendingDefault, greaterThan(moderatorPreflight));
    expect(sql, contains('kademcom@yahoo.com'));
    expect(sql, contains('from auth.users account'));
    expect(sql, contains('v_matching_accounts <> 1'));
    expect(sql, contains('community_moderation_preflight_failed'));
    expect(sql, contains('community_moderation_unavailable'));
    expect(sql, contains('bil_has_community_moderators'));
    expect(sql, contains("current_user in ('anon', 'authenticated')"));
    expect(sql, contains("moderation_status = 'approved'"));
    expect(sql, contains('author_id = (select auth.uid())'));
    expect(sql, contains('bil_list_pending_community_posts'));
    expect(sql, contains('bil_moderate_community_post'));
    expect(sql, contains('security definer'));
    expect(sql, contains('for update'));
    expect(sql, contains('moderator_cannot_review_own_post'));
    expect(sql, contains('post_id uuid primary key'));
    expect(sql, contains('on conflict (post_id) do nothing'));
    expect(sql, contains("if v_decision = 'approved' then"));
    expect(sql, contains('bil_community_post_reward_policy'));
    expect(sql, contains('max_rewarded_posts_per_owner_per_utc_day'));
    expect(sql, contains('bil_community_post_reward_usage'));
    expect(sql, contains('for update'));
    expect(sql, contains("v_reward_reason := 'daily_cap_reached'"));
    expect(sql, contains("check (tokens in (0, 5))"));
    expect(sql, contains("'daily_reward_cap'"));
    expect(
      sql,
      contains(
        'granted = public.bil_ai_credit_balances.granted + excluded.granted',
      ),
    );
    expect(sql, contains('bil_post_moderator_attention'));
    expect(sql, contains('bil_report_moderator_attention'));
    expect(sql, contains("'bil://community/moderation'"));
    expect(sql, contains("'community_post_review:' || new.id::text"));
    expect(sql, contains("'community_report_review:' || new.id::text"));
    expect(sql, contains('bil_can_moderate_community_post_image'));
    expect(sql, isNot(contains('new.body')));
    expect(sql, isNot(contains('new.reason')));
  });

  test('repository requests moderation status and uses guarded RPCs', () {
    final store = File(
      'lib/features/community/data/community_post_cloud_store.dart',
    ).readAsStringSync();
    final repository = [
      'lib/features/community/data/community_repository.dart',
      'lib/features/community/data/community_repository_profile_moderation_mixin.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    expect(store, contains('moderation_status,'));
    expect(store, contains('moderation_visibility,reviewed_at'));
    expect(store, contains("'moderation_status': 'pending'"));
    expect(store, contains("'bil_list_pending_community_posts'"));
    expect(repository, contains("'bil_is_community_moderator'"));
    expect(repository, contains("'bil_moderate_community_post'"));
  });

  test('post status copy remains native in all five Community locales', () {
    for (final locale in const ['fr', 'es', 'tr']) {
      expect(
        communityTextForLanguage(locale, 'Pending review', 'بانتظار المراجعة'),
        isNot('Pending review'),
        reason: locale,
      );
      expect(
        communityTextForLanguage(
          locale,
          'Community moderation',
          'مراجعة المجتمع',
        ),
        isNot('Community moderation'),
        reason: locale,
      );
    }
  });

  testWidgets('moderator queue offers approve and reject and saves once', (
    tester,
  ) async {
    final repository = _ModerationRepository();
    await tester.pumpWidget(
      MaterialApp(home: CommunityPostModerationPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Posts awaiting human review'), findsOneWidget);
    expect(find.text('A post that requires a human decision'), findsOneWidget);
    expect(
      find.byKey(
        const Key(
          'community-moderation-approve-33333333-3333-4333-8333-333333333333',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'community-moderation-reject-33333333-3333-4333-8333-333333333333',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Approve').first);
    await tester.pumpAndSettle();
    expect(find.text('Approve this post?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('community-post-moderation-confirm')),
    );
    await tester.pumpAndSettle();

    expect(repository.moderationCalls, 1);
    expect(repository.lastDecision, CommunityPostModerationDecision.approved);
    expect(
      find.text('Post approved. 5 BIL AI Boost tokens were granted once.'),
      findsOneWidget,
    );
  });

  testWidgets('post owner sees the pending state in their feed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CommunityHubPage(repository: _OwnerFeedRepository())),
    );
    await tester.pumpAndSettle();

    await revealCommunityControl(
      tester,
      find.text('Only I can see this while it is reviewed'),
    );
    expect(
      find.text('Only I can see this while it is reviewed'),
      findsOneWidget,
    );
    expect(find.text('Pending review'), findsOneWidget);
    expect(
      find.byKey(
        const Key('community-post-status-55555555-5555-4555-8555-555555555555'),
      ),
      findsOneWidget,
    );
  });
}
