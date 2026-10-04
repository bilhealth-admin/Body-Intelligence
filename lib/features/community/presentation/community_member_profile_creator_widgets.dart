part of 'community_hub_page.dart';

class _CommunityCreatorPanel extends StatelessWidget {
  const _CommunityCreatorPanel({
    required this.creator,
    required this.isSelf,
    this.goldBalance,
    this.quests = const <CommunityQuest>[],
  });

  final CommunityCreatorProfile creator;
  final bool isSelf;
  final CommunityGoldBalance? goldBalance;
  final List<CommunityQuest> quests;

  String _badgeLabel(BuildContext context, String key) => switch (key) {
    'profile_complete' => communityText(
      context,
      'Profile complete',
      'ملف مكتمل',
    ),
    'first_moment' => communityText(context, 'First moment', 'أول لحظة'),
    'contributor' => communityText(context, 'Contributor', 'مساهم'),
    'conversation_starter' => communityText(
      context,
      'Conversation starter',
      'مبادر بالمحادثات',
    ),
    'appreciated' => communityText(context, 'Appreciated', 'محط تقدير'),
    'connector' => communityText(context, 'Connector', 'صانع روابط'),
    'referral_builder' => communityText(
      context,
      'Community builder',
      'بنّاء المجتمع',
    ),
    _ => key,
  };

  Future<void> _openBadges(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            communityText(sheetContext, 'Community badges', 'شارات المجتمع'),
            style: Theme.of(
              sheetContext,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          for (final badge in creator.badges)
            ListTile(
              key: Key('community-creator-badge-${badge.badgeKey}'),
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(
                  badge.earned
                      ? Icons.verified_rounded
                      : Icons.lock_outline_rounded,
                ),
              ),
              title: Text(_badgeLabel(sheetContext, badge.badgeKey)),
              trailing: Text(
                badge.earned
                    ? communityText(sheetContext, 'Earned', 'مكتسبة')
                    : communityText(sheetContext, 'Locked', 'مقفلة'),
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> _openCreatorCenter(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                communityText(
                  sheetContext,
                  'Creator Center',
                  'مركز صانع المحتوى',
                ),
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              _CreatorMetricRow(
                icon: Icons.article_outlined,
                label: communityText(
                  sheetContext,
                  'Approved moments',
                  'اللحظات المعتمدة',
                ),
                value: creator.approvedPosts.toString(),
              ),
              _CreatorMetricRow(
                icon: Icons.people_outline_rounded,
                label: communityText(sheetContext, 'Followers', 'المتابعون'),
                value: creator.followers.toString(),
              ),
              _CreatorMetricRow(
                icon: Icons.favorite_border_rounded,
                label: communityText(
                  sheetContext,
                  'Likes received',
                  'الإعجابات المستلمة',
                ),
                value: creator.likesReceived.toString(),
              ),
              _CreatorMetricRow(
                icon: Icons.mode_comment_outlined,
                label: communityText(
                  sheetContext,
                  'Comments received',
                  'التعليقات المستلمة',
                ),
                value: creator.commentsReceived.toString(),
              ),
              _CreatorMetricRow(
                icon: Icons.group_add_outlined,
                label: communityText(
                  sheetContext,
                  'Qualified referrals',
                  'الدعوات المؤهلة',
                ),
                value: creator.qualifiedReferrals.toString(),
              ),
            ],
          ),
        ),
      );

  Future<void> _openCertification(BuildContext context) async {
    final status = creator.certificationStatus;
    final (title, body, icon) = switch (status) {
      CommunityCreatorCertificationStatus.approved => (
        communityText(context, 'Certified creator', 'صانع محتوى معتمد'),
        communityText(
          context,
          'This certification is verified by BIL server authority.',
          'هذا الاعتماد موثّق بواسطة سلطة خادم BIL.',
        ),
        Icons.verified_rounded,
      ),
      CommunityCreatorCertificationStatus.revoked => (
        communityText(context, 'Certification revoked', 'تم سحب الاعتماد'),
        communityText(
          context,
          'This profile does not currently hold an active certification.',
          'هذا الملف لا يحمل اعتمادًا نشطًا حاليًا.',
        ),
        Icons.gpp_bad_outlined,
      ),
      CommunityCreatorCertificationStatus.notCertified => (
        communityText(context, 'Not certified', 'غير معتمد'),
        communityText(
          context,
          'No BIL creator certification has been granted to this profile.',
          'لم يُمنح هذا الملف اعتماد صانع محتوى من BIL.',
        ),
        Icons.workspace_premium_outlined,
      ),
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(icon),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(communityText(dialogContext, 'Close', 'إغلاق')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextLevel = creator.nextCommunityLevel;
    final nextXp = creator.nextLevelMinXp;
    final badgeCount = '${creator.earnedBadgeCount}/${creator.totalBadgeCount}';
    final levelLabel = 'Lv ${creator.communityLevel}';
    final progressText = nextLevel == null || nextXp == null
        ? communityText(
            context,
            'Highest configured Community level reached',
            'تم بلوغ أعلى مستوى مجتمع مُعد حاليًا',
          )
        : communityText(
                context,
                '{xp} XP · Next: Lv {level} at {target} XP',
                '{xp} XP · التالي: المستوى {level} عند {target} XP',
              )
              .replaceAll('{xp}', creator.communityXp.toString())
              .replaceAll('{level}', nextLevel.toString())
              .replaceAll('{target}', nextXp.toString());

    return Card(
      key: const Key('community-creator-panel'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (creator.contributor)
                  Chip(
                    avatar: const Icon(Icons.edit_note_rounded, size: 18),
                    label: Text(communityText(context, 'Contributor', 'مساهم')),
                  ),
                Chip(
                  avatar: const Icon(
                    Icons.workspace_premium_outlined,
                    size: 18,
                  ),
                  label: Text(levelLabel),
                ),
                ActionChip(
                  key: const Key('community-creator-badges'),
                  avatar: const Icon(Icons.emoji_events_outlined, size: 18),
                  onPressed: () => _openBadges(context),
                  label: Text(
                    '$badgeCount ${communityText(context, 'Badges', 'شارات')}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              key: const Key('community-level-progress'),
              value: creator.levelProgress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 8),
            Text(progressText, style: Theme.of(context).textTheme.bodySmall),
            if (isSelf) ...[
              const SizedBox(height: 18),
              Text(
                communityText(context, 'Creator tools', 'أدوات صانع المحتوى'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _CreatorToolTile(
                    key: const Key('community-creator-center'),
                    icon: Icons.dashboard_customize_outlined,
                    label: communityText(
                      context,
                      'Creator Center',
                      'مركز صانع المحتوى',
                    ),
                    onTap: () => _openCreatorCenter(context),
                  ),
                  _CreatorToolTile(
                    key: const Key('community-creator-rewards'),
                    icon: Icons.monetization_on_outlined,
                    label: communityText(
                      context,
                      'Creator Rewards',
                      'مكافآت صانع المحتوى',
                    ),
                    onTap: () => context.push('/community/rewards'),
                  ),
                  _CreatorToolTile(
                    key: const Key('community-creator-certification'),
                    icon: Icons.verified_user_outlined,
                    label: communityText(context, 'Certification', 'الاعتماد'),
                    onTap: () => _openCertification(context),
                  ),
                  _CreatorToolTile(
                    key: const Key('community-creator-home'),
                    icon: Icons.public_rounded,
                    label: communityText(
                      context,
                      'Community home',
                      'الصفحة الرئيسية للمجتمع',
                    ),
                    onTap: () => context.go('/community'),
                  ),
                ],
              ),
              if (goldBalance != null || quests.isNotEmpty) ...[
                const SizedBox(height: 14),
                _CommunityCreatorRewardsSnapshot(
                  balance: goldBalance,
                  quests: quests,
                ),
              ],
              if (nextLevel != null && nextXp != null) ...[
                const SizedBox(height: 18),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: .45),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                communityText(
                                  context,
                                  'Task Center',
                                  'مركز المهام',
                                ),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              Text(
                                communityText(
                                      context,
                                      'Progress toward Lv {level} · {target} XP target',
                                      'التقدم نحو المستوى {level} · الهدف {target} XP',
                                    )
                                    .replaceAll('{level}', nextLevel.toString())
                                    .replaceAll('{target}', nextXp.toString()),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          key: const Key('community-task-center-open'),
                          onPressed: () => context.push('/community/rewards'),
                          child: Text(communityText(context, 'Open', 'فتح')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CommunityCreatorRewardsSnapshot extends StatelessWidget {
  const _CommunityCreatorRewardsSnapshot({
    required this.balance,
    required this.quests,
  });

  final CommunityGoldBalance? balance;
  final List<CommunityQuest> quests;

  @override
  Widget build(BuildContext context) {
    final activeQuests = quests
        .where((quest) => quest.state != CommunityQuestState.claimed)
        .toList(growable: false);
    final readyCount = quests
        .where((quest) => quest.state == CommunityQuestState.readyToClaim)
        .length;
    final topQuest = activeQuests.isEmpty
        ? quests.firstOrNull
        : activeQuests.first;

    return DecoratedBox(
      key: const Key('community-creator-rewards-snapshot'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .34),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BilGoldCoin(size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        communityText(
                          context,
                          'Creator rewards',
                          'مكافآت صانع المحتوى',
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (balance != null)
                        Text(
                          '${balance!.balance} BIL Gold',
                          key: const Key('community-creator-gold-balance'),
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (readyCount > 0)
                  Badge(
                    label: Text('$readyCount'),
                    child: const Icon(Icons.card_giftcard_rounded),
                  ),
                IconButton(
                  key: const Key('community-creator-rewards-open'),
                  tooltip: communityText(
                    context,
                    'Open rewards',
                    'فتح المكافآت',
                  ),
                  onPressed: () => context.push('/community/rewards'),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            if (topQuest case final quest?) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                key: const Key('community-creator-quest-progress'),
                value: quest.completionRatio,
                minHeight: 7,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _creatorQuestLabel(context, quest),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${quest.progress}/${quest.targetCount}',
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _creatorQuestLabel(BuildContext context, CommunityQuest quest) =>
      switch (quest.titleCopyKey) {
        'quest_invite_friend_title' => communityText(
          context,
          'Invite a friend',
          'دعوة صديق',
        ),
        'quest_valuable_post_title' => communityText(
          context,
          'Create a valuable post',
          'إنشاء منشور قيّم',
        ),
        'quest_complete_profile_title' => communityText(
          context,
          'Complete your Community profile',
          'أكمل ملف المجتمع',
        ),
        _ => communityText(
          context,
          'Community reward task',
          'مهمة مكافآت المجتمع',
        ),
      };
}

class _CreatorToolTile extends StatelessWidget {
  const _CreatorToolTile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Ink(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CreatorMetricRow extends StatelessWidget {
  const _CreatorMetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    trailing: Text(
      value,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    ),
  );
}

class _CommunityProfileReviewTile extends StatelessWidget {
  const _CommunityProfileReviewTile({required this.review});

  final CommunityProfileReview review;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.rate_review_outlined)),
      title: Text(review.canonicalName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (review.brand?.trim().isNotEmpty == true) Text(review.brand!),
          if (review.reviewNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(review.reviewNote!),
          ],
        ],
      ),
      trailing: Text(
        review.productKind,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ),
  );
}
