part of 'community_rewards_page.dart';

class _GoldBalanceCard extends StatelessWidget {
  const _GoldBalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
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
                    color: const Color(0xFF6B470B),
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
