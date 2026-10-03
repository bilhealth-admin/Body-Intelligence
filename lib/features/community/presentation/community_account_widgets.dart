part of 'community_hub_page.dart';

/// Personal tools live with the member's profile, not above every feed post.
/// This is an account surface, never a public profile or a health-data summary.
class _CommunityProfileHeader extends StatelessWidget {
  const _CommunityProfileHeader({
    required this.repository,
    required this.profile,
    required this.onRefresh,
  });
  final CommunityRepository repository;
  final Future<CommunityProfileOverview?> profile;
  final VoidCallback onRefresh;

  Future<void> _edit(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await context.push('/community/profile');
    if (context.mounted) onRefresh();
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<CommunityProfileOverview?>(
    future: profile,
    builder: (context, snapshot) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final profile = snapshot.data;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [scheme.primary.withValues(alpha: .10), scheme.surface],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BilAccountAvatar(
                      radius: 35,
                      networkUrl: profile?.avatarUrl,
                    ),
                    const Spacer(),
                    IconButton.outlined(
                      key: const Key('community-edit-profile'),
                      onPressed: () => _edit(context),
                      tooltip: communityText(
                        context,
                        'Community profile',
                        'ملف المجتمع',
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  profile?.displayName ?? communityText(context, 'You', 'أنت'),
                  style: theme.textTheme.titleLarge,
                  textDirection: BilWrittenLanguageResolver.directionFor(
                    profile?.displayName ?? '',
                    fallback: Directionality.of(context),
                  ),
                ),
                if (profile?.handle?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    '@${profile!.handle}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ],
                if (profile?.bio?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    profile!.bio!,
                    style: theme.textTheme.bodyMedium,
                    textDirection: BilWrittenLanguageResolver.directionFor(
                      profile.bio!,
                      fallback: Directionality.of(context),
                    ),
                  ),
                ],
                if (profile != null) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (profile.postCount != null)
                        _CommunityProfileMetric(
                          icon: Icons.article_outlined,
                          value: '${profile.postCount}',
                          label: communityText(context, 'Posts', 'المنشورات'),
                        ),
                      if (profile.friendCount != null)
                        _CommunityProfileMetric(
                          icon: Icons.people_outline_rounded,
                          value: '${profile.friendCount}',
                          label: communityText(context, 'Friends', 'الأصدقاء'),
                        ),
                      if (profile.communityLevel != null)
                        _CommunityProfileMetric(
                          icon: Icons.workspace_premium_outlined,
                          value: 'Lv ${profile.communityLevel}',
                          label: communityText(
                            context,
                            'Community level',
                            'مستوى المجتمع',
                          ),
                        ),
                      if (profile.communityXp != null)
                        _CommunityProfileMetric(
                          icon: Icons.auto_graph_rounded,
                          value: '${profile.communityXp} XP',
                          label: 'Community XP',
                        ),
                      if (profile.goldBalance != null)
                        _CommunityProfileMetric(
                          icon: Icons.monetization_on_outlined,
                          value: '${profile.goldBalance}',
                          label: 'BIL Gold',
                        ),
                    ],
                  ),
                ],
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (snapshot.hasError)
                  TextButton.icon(
                    key: const Key('community-account-profile-retry'),
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      communityText(context, 'Retry', 'إعادة المحاولة'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                key: const Key('community-saved-posts'),
                onPressed: () => pushCommunityPage<void>(
                  context,
                  CommunitySavedPostsPage(repository: repository),
                ),
                icon: const Icon(Icons.bookmark_border_rounded, size: 19),
                label: Text(
                  communityText(context, 'Saved posts', 'المنشورات المحفوظة'),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('community-account-connections'),
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  context.push('/community/connections');
                },
                icon: const Icon(Icons.people_outline_rounded, size: 19),
                label: Text(communityText(context, 'Friends', 'الأصدقاء')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            communityText(context, 'My posts', 'منشوراتي'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Divider(color: scheme.outlineVariant, height: 1),
        ],
      );
    },
  );
}

class _CommunityProfileMetric extends StatelessWidget {
  const _CommunityProfileMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: $value',
      child: Container(
        constraints: const BoxConstraints(minWidth: 88),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityAccountMenu extends StatefulWidget {
  const _CommunityAccountMenu({
    required this.repository,
    required this.onProfileChanged,
  });
  final CommunityRepository repository;
  final VoidCallback onProfileChanged;

  @override
  State<_CommunityAccountMenu> createState() => _CommunityAccountMenuState();
}

class _CommunityAccountMenuState extends State<_CommunityAccountMenu> {
  late final Future<bool> _moderator = widget.repository.isCommunityModerator();

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _moderator,
    builder: (context, snapshot) => PopupMenuButton<String>(
      tooltip: communityText(context, 'Community actions', 'إجراءات المجتمع'),
      position: PopupMenuPosition.under,
      icon: const Icon(Icons.tune_rounded),
      onSelected: (route) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await context.push(route);
        if (context.mounted && route == '/community/profile') {
          widget.onProfileChanged();
        }
      },
      itemBuilder: (context) => [
        _communityAction(
          context,
          '/community/profile',
          'Community profile',
          'ملف المجتمع',
        ),
        _communityAction(
          context,
          '/community/connections',
          'Friends and requests',
          'الأصدقاء والطلبات',
        ),
        _communityAction(
          context,
          '/community/people',
          'Find people',
          'البحث عن أصدقاء',
        ),
        _communityAction(
          context,
          '/community/safety',
          'Safety and policy',
          'الأمان والسياسة',
        ),
        // Food-review authorization is distinct from Community moderation.
        _communityAction(
          context,
          '/community/food-review',
          'Review foods',
          'مراجعة الأغذية',
        ),
        if (snapshot.data == true)
          _communityAction(
            context,
            '/community/moderation',
            'Community moderation',
            'مراجعة المجتمع',
          ),
      ],
    ),
  );
}
