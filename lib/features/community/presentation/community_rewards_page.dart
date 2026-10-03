import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../data/community_repository.dart';
import '../domain/community_rewards.dart';
import 'bil_gold_coin.dart';
import 'community_copy.dart';

class CommunityRewardsPage extends StatefulWidget {
  const CommunityRewardsPage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  State<CommunityRewardsPage> createState() => _CommunityRewardsPageState();
}

class _CommunityRewardsPageState extends State<CommunityRewardsPage>
    with SingleTickerProviderStateMixin {
  static const _historyPageSize = 30;

  CommunityRepository? _repository;
  late Future<_RewardsSnapshot> _snapshot;
  final List<CommunityGoldLedgerEntry> _history = [];
  DateTime? _historyBefore;
  int? _historyBeforeId;
  bool _historyHasMore = false;
  bool _historyLoadingMore = false;
  String? _claimingQuest;
  CommunityQuestCadence? _cadenceFilter;
  _HistoryFilter _historyFilter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? _productionRepository();
    _snapshot = _load();
  }

  CommunityRepository? _productionRepository() {
    if (!AppEnvironment.supabaseRuntimeReady) return null;
    try {
      final supabase = Supabase.instance;
      if (!supabase.isInitialized || supabase.client.auth.currentUser == null) {
        return null;
      }
      return CommunityRepository(supabase.client);
    } on Object {
      return null;
    }
  }

  Future<_RewardsSnapshot> _load() async {
    final repository = _repository;
    if (repository == null) return const _RewardsSnapshot.signedOut();

    final values = await Future.wait<Object>([
      repository.loadGoldBalance(),
      repository.loadCommunityQuests(),
      repository.loadGoldHistory(limit: _historyPageSize),
    ]);
    final balance = values[0] as CommunityGoldBalance;
    final quests = values[1] as List<CommunityQuest>;
    final history = values[2] as List<CommunityGoldLedgerEntry>;

    _history
      ..clear()
      ..addAll(history);
    if (history.isEmpty) {
      _historyBefore = null;
      _historyBeforeId = null;
      _historyHasMore = false;
    } else {
      _historyBefore = history.last.createdAt;
      _historyBeforeId = history.last.id;
      _historyHasMore = history.length == _historyPageSize;
    }
    return _RewardsSnapshot(balance: balance, quests: quests);
  }

  void _retry() {
    final next = _load();
    setState(() => _snapshot = next);
  }

  Future<void> _reloadAfterMutation() async {
    final next = _load();
    setState(() => _snapshot = next);
    try {
      await next;
    } on Object {
      // The page-level error surface remains authoritative.
    }
  }

  Future<void> _claim(CommunityQuest quest) async {
    final repository = _repository;
    if (repository == null || _claimingQuest != null) return;
    setState(() => _claimingQuest = quest.questKey);
    try {
      final result = await repository.claimCommunityQuest(
        questKey: quest.questKey,
        periodKey: quest.periodKey,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (result.status == CommunityQuestClaimStatus.claimed) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.duplicate
                  ? communityText(
                      context,
                      'Reward already claimed.',
                      'تم استلام المكافأة مسبقًا.',
                    )
                  : communityText(
                      context,
                      'Reward claimed.',
                      'تم استلام المكافأة.',
                    ),
            ),
          ),
        );
      } else if (result.status == CommunityQuestClaimStatus.blocked) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'This reward is not available right now.',
                'هذه المكافأة غير متاحة الآن.',
              ),
            ),
          ),
        );
      }
      await _reloadAfterMutation();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Could not claim this reward safely. Try again.',
                'تعذر استلام هذه المكافأة بأمان. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _claimingQuest = null);
    }
  }

  Future<void> _openQuestAction(CommunityQuest quest) async {
    final route = _routeForAction(quest.actionKind);
    if (route == null) return;
    await context.push(route);
    if (mounted) await _reloadAfterMutation();
  }

  String? _routeForAction(String actionKind) => switch (actionKind) {
    'invite_friend' || 'friend_request' => '/community/people',
    'complete_profile' || 'community_profile' => '/community/profile',
    'valuable_post' || 'create_post' || 'community_post' => '/community',
    'community_interaction' => '/community',
    _ => null,
  };

  Future<void> _loadMoreHistory() async {
    final repository = _repository;
    if (repository == null ||
        _historyLoadingMore ||
        !_historyHasMore ||
        _historyBefore == null ||
        _historyBeforeId == null) {
      return;
    }
    setState(() => _historyLoadingMore = true);
    try {
      final next = await repository.loadGoldHistory(
        beforeCreatedAt: _historyBefore,
        beforeId: _historyBeforeId,
        limit: _historyPageSize,
      );
      if (!mounted) return;
      final known = _history.map((entry) => entry.id).toSet();
      setState(() {
        _history.addAll(next.where((entry) => known.add(entry.id)));
        if (next.isEmpty) {
          _historyHasMore = false;
        } else {
          _historyBefore = next.last.createdAt;
          _historyBeforeId = next.last.id;
          _historyHasMore = next.length == _historyPageSize;
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Could not load more history.',
                'تعذر تحميل المزيد من السجل.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _historyLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: Text(communityText(context, 'BIL Rewards', 'مكافآت BIL')),
        bottom: TabBar(
          tabs: [
            Tab(text: communityText(context, 'Earn', 'اكسب')),
            Tab(text: communityText(context, 'History', 'السجل')),
          ],
        ),
      ),
      body: FutureBuilder<_RewardsSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _RewardsMessageState(
              icon: Icons.cloud_off_outlined,
              title: communityText(
                context,
                'Rewards are unavailable',
                'المكافآت غير متاحة',
              ),
              body: communityText(
                context,
                'BIL could not verify your reward state safely.',
                'تعذر على BIL التحقق من حالة مكافآتك بأمان.',
              ),
              onRetry: _retry,
            );
          }
          final data = snapshot.requireData;
          if (data.signedOut) {
            return _RewardsMessageState(
              icon: Icons.lock_person_outlined,
              title: communityText(
                context,
                'Sign in required',
                'تسجيل الدخول مطلوب',
              ),
              body: communityText(
                context,
                'Sign in to view BIL Gold and rewards.',
                'سجّل الدخول لعرض BIL Gold والمكافآت.',
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: _GoldBalanceCard(balance: data.balance.balance),
              ),
              Expanded(
                child: TabBarView(
                  children: [_buildEarnTab(data.quests), _buildHistoryTab()],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _buildEarnTab(List<CommunityQuest> quests) {
    final filtered = _cadenceFilter == null
        ? quests
        : quests
              .where((quest) => quest.cadence == _cadenceFilter)
              .toList(growable: false);
    return RefreshIndicator(
      onRefresh: _reloadAfterMutation,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(communityText(context, 'All', 'الكل')),
                  selected: _cadenceFilter == null,
                  onSelected: (_) => setState(() => _cadenceFilter = null),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(communityText(context, 'Starter', 'البداية')),
                  selected: _cadenceFilter == CommunityQuestCadence.oneTime,
                  onSelected: (_) => setState(
                    () => _cadenceFilter = CommunityQuestCadence.oneTime,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(communityText(context, 'Daily', 'يومي')),
                  selected: _cadenceFilter == CommunityQuestCadence.daily,
                  onSelected: (_) => setState(
                    () => _cadenceFilter = CommunityQuestCadence.daily,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(communityText(context, 'Weekly', 'أسبوعي')),
                  selected: _cadenceFilter == CommunityQuestCadence.weekly,
                  onSelected: (_) => setState(
                    () => _cadenceFilter = CommunityQuestCadence.weekly,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            _EmptyRewards(
              title: communityText(
                context,
                'No active quests right now',
                'لا توجد مهام نشطة الآن',
              ),
              body: communityText(
                context,
                'Reward rules are activated by BIL only after server-side verification and safety checks are ready.',
                'يتم تفعيل قواعد المكافآت من BIL فقط بعد جاهزية التحقق والحماية على الخادم.',
              ),
            )
          else
            for (final quest in filtered) ...[
              _QuestCard(
                quest: quest,
                claiming: _claimingQuest == quest.questKey,
                actionAvailable: _routeForAction(quest.actionKind) != null,
                onGo: () => _openQuestAction(quest),
                onClaim: () => _claim(quest),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final visible = _history
        .where((entry) {
          return switch (_historyFilter) {
            _HistoryFilter.all => true,
            _HistoryFilter.earned => entry.earned,
            _HistoryFilter.used => entry.used,
          };
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: _reloadAfterMutation,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(communityText(context, 'All', 'الكل')),
                selected: _historyFilter == _HistoryFilter.all,
                onSelected: (_) =>
                    setState(() => _historyFilter = _HistoryFilter.all),
              ),
              ChoiceChip(
                label: Text(communityText(context, 'Earned', 'المكتسب')),
                selected: _historyFilter == _HistoryFilter.earned,
                onSelected: (_) =>
                    setState(() => _historyFilter = _HistoryFilter.earned),
              ),
              ChoiceChip(
                label: Text(communityText(context, 'Used', 'المستخدم')),
                selected: _historyFilter == _HistoryFilter.used,
                onSelected: (_) =>
                    setState(() => _historyFilter = _HistoryFilter.used),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            _EmptyRewards(
              title: communityText(
                context,
                'No Gold activity yet',
                'لا يوجد نشاط Gold بعد',
              ),
              body: communityText(
                context,
                'Earned and used BIL Gold entries will appear here.',
                'ستظهر هنا عمليات اكتساب واستخدام BIL Gold.',
              ),
            )
          else
            for (final entry in visible) _GoldHistoryTile(entry: entry),
          if (_historyHasMore)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton.icon(
                onPressed: _historyLoadingMore ? null : _loadMoreHistory,
                icon: _historyLoadingMore
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  communityText(context, 'Load more', 'تحميل المزيد'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoldBalanceCard extends StatelessWidget {
  const _GoldBalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFFFFF6D6), Color(0xFFFFE7A0)],
        ),
        border: Border.all(color: const Color(0xFFE0B33D)),
      ),
      child: Row(
        children: [
          const BilGoldCoin(size: 54),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BIL Gold',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF6B470B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$balance',
                  key: const Key('community-gold-balance'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF402A08),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  communityText(
                    context,
                    'Spendable Community currency',
                    'عملة المجتمع القابلة للاستخدام',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.claiming,
    required this.actionAvailable,
    required this.onGo,
    required this.onClaim,
  });

  final CommunityQuest quest;
  final bool claiming;
  final bool actionAvailable;
  final VoidCallback onGo;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _questTitle(context, quest.titleCopyKey);
    final subtitle = _questSubtitle(context, quest.subtitleCopyKey);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BilGoldCoin(size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _RewardAmount(quest: quest),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: quest.completionRatio,
              minHeight: 7,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 6),
            Text(
              '${quest.progress} / ${quest.targetCount}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: switch (quest.state) {
                CommunityQuestState.go => FilledButton(
                  onPressed: actionAvailable ? onGo : null,
                  child: Text(communityText(context, 'Go', 'ابدأ')),
                ),
                CommunityQuestState.pending => FilledButton.tonal(
                  onPressed: null,
                  child: Text(
                    communityText(context, 'Pending', 'قيد الانتظار'),
                  ),
                ),
                CommunityQuestState.readyToClaim => FilledButton.icon(
                  key: Key('community-quest-claim-${quest.questKey}'),
                  onPressed: claiming ? null : onClaim,
                  icon: claiming
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.redeem_rounded),
                  label: Text(
                    communityText(context, 'Ready to claim', 'جاهزة للاستلام'),
                  ),
                ),
                CommunityQuestState.claimed => Chip(
                  avatar: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(communityText(context, 'Claimed', 'تم الاستلام')),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _questTitle(BuildContext context, String key) => switch (key) {
    'quest_invite_friend_title' => communityText(
      context,
      'Invite a friend',
      'ادعُ صديقًا',
    ),
    'quest_valuable_post_title' => communityText(
      context,
      'Create a valuable post',
      'أنشئ منشورًا قيّمًا',
    ),
    'quest_complete_profile_title' => communityText(
      context,
      'Complete your Community profile',
      'أكمل ملفك في المجتمع',
    ),
    _ => communityText(context, 'Community quest', 'مهمة في المجتمع'),
  };

  static String _questSubtitle(
    BuildContext context,
    String key,
  ) => switch (key) {
    'quest_invite_friend_subtitle' => communityText(
      context,
      'Rewards unlock only after the verified friend relationship qualifies.',
      'تُفتح المكافأة فقط بعد تحقق علاقة الصداقة المؤهلة.',
    ),
    'quest_valuable_post_subtitle' => communityText(
      context,
      'Quality, moderation, and meaningful engagement are checked first.',
      'يتم أولًا التحقق من الجودة والمراجعة والتفاعل الحقيقي.',
    ),
    'quest_complete_profile_subtitle' => communityText(
      context,
      'Set up your public identity and privacy choices.',
      'اضبط هويتك العامة وخيارات الخصوصية.',
    ),
    _ => communityText(
      context,
      'Complete the verified Community action to make progress.',
      'أكمل الإجراء الموثق في المجتمع لإحراز تقدم.',
    ),
  };
}

class _RewardAmount extends StatelessWidget {
  const _RewardAmount({required this.quest});

  final CommunityQuest quest;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      if (quest.goldReward > 0)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BilGoldCoin(size: 18),
            const SizedBox(width: 4),
            Text(
              '+${quest.goldReward}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      if (quest.xpReward > 0)
        Text(
          '+${quest.xpReward} XP',
          style: Theme.of(context).textTheme.labelMedium,
        ),
    ],
  );
}

class _GoldHistoryTile extends StatelessWidget {
  const _GoldHistoryTile({required this.entry});

  final CommunityGoldLedgerEntry entry;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: const BilGoldCoin(size: 34),
    title: Text(_title(context)),
    subtitle: Text(
      MaterialLocalizations.of(
        context,
      ).formatCompactDate(entry.createdAt.toLocal()),
    ),
    trailing: Text(
      '${entry.delta > 0 ? '+' : ''}${entry.delta}',
      style: TextStyle(
        fontWeight: FontWeight.w900,
        color: entry.delta > 0
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );

  String _title(BuildContext context) => switch (entry.sourceKind) {
    'quest_reward' => communityText(
      context,
      'Community quest reward',
      'مكافأة مهمة المجتمع',
    ),
    'ai_coach_spend' => communityText(
      context,
      'AI Coach usage',
      'استخدام مدرب الذكاء الاصطناعي',
    ),
    'reversal' => communityText(context, 'Balance adjustment', 'تسوية الرصيد'),
    _ => communityText(context, 'BIL Gold activity', 'نشاط BIL Gold'),
  };
}

class _EmptyRewards extends StatelessWidget {
  const _EmptyRewards({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        const BilGoldCoin(size: 54),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}

class _RewardsMessageState extends StatelessWidget {
  const _RewardsMessageState({
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
            ),
          ],
        ],
      ),
    ),
  );
}

class _RewardsSnapshot {
  const _RewardsSnapshot({required this.balance, required this.quests})
    : signedOut = false;

  const _RewardsSnapshot.signedOut()
    : balance = const CommunityGoldBalance(balance: 0),
      quests = const <CommunityQuest>[],
      signedOut = true;

  final CommunityGoldBalance balance;
  final List<CommunityQuest> quests;
  final bool signedOut;
}

enum _HistoryFilter { all, earned, used }
