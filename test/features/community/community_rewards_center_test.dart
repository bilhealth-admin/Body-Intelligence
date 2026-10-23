import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_rewards.dart';
import 'package:body_intelligence_log/features/community/presentation/community_rewards_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_gold_balance_action.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _RewardsRepository extends CommunityRepository {
  _RewardsRepository(super.client);

  @override
  String get currentUserId => '11111111-1111-4111-8111-111111111111';

  int claimCalls = 0;
  int balance = 50;
  bool claimed = false;

  @override
  Future<CommunityGoldBalance> loadGoldBalance() async =>
      CommunityGoldBalance(balance: balance);

  @override
  Future<List<CommunityGoldLedgerEntry>> loadGoldHistory({
    DateTime? beforeCreatedAt,
    int? beforeId,
    int limit = 30,
  }) async => const <CommunityGoldLedgerEntry>[];

  @override
  Future<List<CommunityQuest>> loadCommunityQuests() async => [
    CommunityQuest(
      questKey: 'qa_profile_quest',
      cadence: CommunityQuestCadence.oneTime,
      titleCopyKey: 'quest_complete_profile_title',
      subtitleCopyKey: 'quest_complete_profile_subtitle',
      actionKind: 'complete_profile',
      targetCount: 1,
      claimMode: CommunityQuestClaimMode.manual,
      goldReward: 25,
      xpReward: 10,
      periodKey: 'once',
      progress: 1,
      state: claimed
          ? CommunityQuestState.claimed
          : CommunityQuestState.readyToClaim,
    ),
  ];

  @override
  Future<CommunityQuestClaimResult> claimCommunityQuest({
    required String questKey,
    required String periodKey,
  }) async {
    claimCalls++;
    claimed = true;
    balance = 75;
    return const CommunityQuestClaimResult(
      status: CommunityQuestClaimStatus.claimed,
      gold: 25,
      xp: 10,
    );
  }
}

void main() {
  late SupabaseClient client;
  setUp(() {
    client = SupabaseClient(
      'https://rewards.invalid',
      'rewards-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() => client.dispose());

  test('reward domain parses Gold and quest states strictly', () {
    final balance = CommunityGoldBalance.fromJson({
      'balance': 1450,
      'updated_at': '2026-10-03T00:00:00Z',
    });
    expect(balance.balance, 1450);

    final quest = CommunityQuest.fromJson({
      'quest_key': 'invite_friend',
      'cadence': 'one_time',
      'title_copy_key': 'quest_invite_friend_title',
      'subtitle_copy_key': 'quest_invite_friend_subtitle',
      'action_kind': 'invite_friend',
      'target_count': 1,
      'claim_mode': 'manual',
      'gold_reward': 100,
      'xp_reward': 25,
      'period_key': 'once',
      'progress': 1,
      'state': 'ready_to_claim',
      'completed_at': '2026-10-03T00:00:00Z',
      'claimed_at': null,
    });
    expect(quest.state, CommunityQuestState.readyToClaim);
    expect(quest.completionRatio, 1);
  });

  testWidgets(
    'Rewards Center claims once and refreshes authoritative balance',
    (tester) async {
      final repository = _RewardsRepository(client);
      await tester.pumpWidget(
        MaterialApp(home: CommunityRewardsPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('community-gold-balance')), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('Complete your Community profile'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('community-quest-claim-qa_profile_quest')),
      );
      await tester.pumpAndSettle();

      expect(repository.claimCalls, 1);
      expect(find.text('75'), findsOneWidget);
      expect(find.text('Claimed'), findsOneWidget);
    },
  );
  testWidgets(
    'Coach coin opens balance and history before explicit post action',
    (tester) async {
      final repository = _RewardsRepository(client);
      var composerVisits = 0;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: CommunityGoldBalanceAction(
                compact: true,
                showEarn: false,
                repository: repository,
              ),
            ),
          ),
          GoRoute(
            path: '/community/rewards',
            builder: (_, _) => CommunityRewardsPage(repository: repository),
          ),
          GoRoute(
            path: '/community/compose',
            builder: (_, state) {
              composerVisits++;
              expect(state.uri.queryParameters['origin'], 'earn');
              return const Scaffold(body: Text('Explicit post composer'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-coach-earn-post')), findsNothing);
      await tester.tap(find.byKey(const Key('ai-coach-bil-gold')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('community-gold-balance')), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('community-ai-reward-notice')),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.byKey(const Key('community-ai-reward-notice')),
        findsOneWidget,
      );
      expect(find.textContaining('AI tokens are not BIL Gold'), findsOneWidget);
      expect(composerVisits, 0);
      expect(repository.claimCalls, 0);
      await tester.ensureVisible(
        find.byKey(const Key('community-earn-create-post')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-earn-create-post')));
      await tester.pumpAndSettle();
      expect(find.text('Explicit post composer'), findsOneWidget);
      expect(composerVisits, 1);
      expect(repository.claimCalls, 0);
      expect(repository.balance, 50);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
