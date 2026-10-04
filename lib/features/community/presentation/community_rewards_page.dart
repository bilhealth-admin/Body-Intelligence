import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../data/community_repository.dart';
import '../domain/community_rewards.dart';
import 'bil_gold_coin.dart';
import 'community_copy.dart';

part 'community_rewards_cards.dart';

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
  int _loadGeneration = 0;
  bool _refreshing = false;
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
    final generation = ++_loadGeneration;
    _refreshing = true;
    _historyLoadingMore = false;
    try {
      final values = await Future.wait<Object>([
        repository.loadGoldBalance(),
        repository.loadCommunityQuests(),
        repository.loadGoldHistory(limit: _historyPageSize),
      ]);
      final balance = values[0] as CommunityGoldBalance;
      final quests = values[1] as List<CommunityQuest>;
      final history = values[2] as List<CommunityGoldLedgerEntry>;
      if (!mounted || generation != _loadGeneration) {
        return _RewardsSnapshot(balance: balance, quests: quests);
      }
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
    } finally {
      if (generation == _loadGeneration) _refreshing = false;
    }
  }

  void _retry() {
    final next = _load();
    setState(() {
      _snapshot = next;
    });
  }

  Future<void> _reloadAfterMutation() async {
    final next = _load();
    setState(() {
      _snapshot = next;
    });
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
        _refreshing ||
        !_historyHasMore ||
        _historyBefore == null ||
        _historyBeforeId == null) {
      return;
    }
    final generation = _loadGeneration;
    setState(() => _historyLoadingMore = true);
    try {
      final next = await repository.loadGoldHistory(
        beforeCreatedAt: _historyBefore,
        beforeId: _historyBeforeId,
        limit: _historyPageSize,
      );
      if (!mounted || generation != _loadGeneration) return;
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
      if (mounted && generation == _loadGeneration) {
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
      if (mounted && generation == _loadGeneration) {
        setState(() => _historyLoadingMore = false);
      }
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
