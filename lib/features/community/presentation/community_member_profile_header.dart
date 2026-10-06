part of 'community_hub_page.dart';

class _CommunityMemberProfileHeader extends StatelessWidget {
  const _CommunityMemberProfileHeader({
    required this.visit,
    required this.profile,
    required this.creator,
    required this.coverUrl,
    required this.relationshipBusy,
    required this.followBusy,
    required this.onRequestFriend,
    required this.onToggleFollow,
    required this.onOpenConnections,
  });

  final _CommunityProfileVisit visit;
  final CommunityProfileOverview profile;
  final CommunityCreatorProfile? creator;
  final String? coverUrl;
  final bool relationshipBusy;
  final bool followBusy;
  final VoidCallback onRequestFriend;
  final VoidCallback onToggleFollow;
  final ValueChanged<CommunityProfileConnectionKind> onOpenConnections;

  Future<void> _shareProfile(BuildContext context) async {
    if (!visit.isCurrent()) return;
    final handle = profile.handle;
    final text = [
      profile.displayName,
      if (handle != null) '@$handle',
      communityText(context, 'BIL Community profile', 'ملف مجتمع BIL'),
    ].join('\n');
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } on Object {
      if (!context.mounted || !visit.isCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not open sharing right now.',
              'تعذر فتح المشاركة حاليًا.',
            ),
          ),
        ),
      );
    }
  }

  Widget _heroAction({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .42),
      shape: BoxShape.circle,
    ),
    child: IconButton(
      tooltip: tooltip,
      onPressed: () {
        if (visit.isCurrent()) onPressed();
      },
      color: Colors.white,
      icon: Icon(icon),
    ),
  );

  Widget _metric({
    required BuildContext context,
    required String value,
    required String label,
    VoidCallback? onTap,
  }) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap == null
        ? null
        : () {
            if (visit.isCurrent()) onTap();
          },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cover = coverUrl;

    return Card(
      key: const Key('community-profile-hero'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 168,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                if (cover != null)
                  Image.network(
                    cover,
                    key: const Key('community-profile-cover'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _CommunityProfileCoverFallback(colorScheme: scheme),
                  )
                else
                  _CommunityProfileCoverFallback(colorScheme: scheme),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .05),
                        Colors.black.withValues(alpha: .42),
                      ],
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 10,
                  end: 10,
                  child: profile.isSelf
                      ? FilledButton.tonalIcon(
                          key: const Key('community-edit-profile'),
                          onPressed: () {
                            if (visit.isCurrent()) {
                              context.push('/community/profile');
                            }
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(
                            communityText(
                              context,
                              'Edit profile',
                              'تعديل الملف',
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          children: [
                            _heroAction(
                              context: context,
                              icon: Icons.share_outlined,
                              tooltip: communityText(
                                context,
                                'Share profile',
                                'مشاركة الملف',
                              ),
                              onPressed: () => _shareProfile(context),
                            ),
                            _heroAction(
                              context: context,
                              icon: Icons.mail_outline_rounded,
                              tooltip: communityText(
                                context,
                                'Messages',
                                'الرسائل',
                              ),
                              onPressed: () =>
                                  context.push('/community/messages'),
                            ),
                          ],
                        ),
                ),
                PositionedDirectional(
                  start: 18,
                  bottom: -36,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface,
                      border: Border.all(color: scheme.surface, width: 4),
                    ),
                    child: BilAccountAvatar(
                      radius: 44,
                      networkUrl: profile.avatarUrl,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 48, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (creator?.certificationStatus ==
                        CommunityCreatorCertificationStatus.approved) ...[
                      const SizedBox(width: 5),
                      Icon(
                        Icons.verified_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                    ],
                  ],
                ),
                if (profile.handle != null)
                  Text(
                    '@${profile.handle!}',
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (profile.postCount != null)
                      _metric(
                        context: context,
                        value: profile.postCount.toString(),
                        label: communityText(context, 'Posts', 'المنشورات'),
                      ),
                    if (profile.followerCount != null)
                      _metric(
                        context: context,
                        value: profile.followerCount.toString(),
                        label: communityText(context, 'Followers', 'المتابعون'),
                        onTap: () => onOpenConnections(
                          CommunityProfileConnectionKind.followers,
                        ),
                      ),
                    if (profile.followingCount != null)
                      _metric(
                        context: context,
                        value: profile.followingCount.toString(),
                        label: communityText(context, 'Following', 'يتابع'),
                        onTap: () => onOpenConnections(
                          CommunityProfileConnectionKind.following,
                        ),
                      ),
                  ],
                ),
                if (profile.countryCode case final country?) ...[
                  const SizedBox(height: 2),
                  Text(country, style: theme.textTheme.labelMedium),
                ],
                if (profile.bio?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(profile.bio!, style: theme.textTheme.bodyLarge),
                ],
                if (profile.friendCount != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ActionChip(
                      avatar: const Icon(
                        Icons.people_outline_rounded,
                        size: 18,
                      ),
                      label: Text(
                        '${profile.friendCount} ${communityText(context, 'Friends', 'أصدقاء')}',
                      ),
                      onPressed: () => onOpenConnections(
                        CommunityProfileConnectionKind.friends,
                      ),
                    ),
                  ),
                ],
                if (!profile.isSelf) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _ProfileRelationshipAction(
                        profile: profile,
                        busy: relationshipBusy,
                        onRequestFriend: () {
                          if (visit.isCurrent()) onRequestFriend();
                        },
                      ),
                      if (profile.viewerFollows || profile.allowFollows)
                        OutlinedButton.icon(
                          key: const Key('community-profile-follow-action'),
                          onPressed: followBusy
                              ? null
                              : () {
                                  if (visit.isCurrent()) onToggleFollow();
                                },
                          icon: followBusy
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  profile.viewerFollows
                                      ? Icons.person_remove_outlined
                                      : Icons.person_add_alt_outlined,
                                ),
                          label: Text(
                            profile.viewerFollows
                                ? communityText(context, 'Following', 'يتابع')
                                : communityText(context, 'Follow', 'متابعة'),
                          ),
                        ),
                      if (profile.followsViewer)
                        Chip(
                          avatar: const Icon(
                            Icons.swap_horiz_rounded,
                            size: 17,
                          ),
                          label: Text(
                            communityText(context, 'Follows you', 'يتابعك'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityProfileCoverFallback extends StatelessWidget {
  const _CommunityProfileCoverFallback({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('community-profile-cover-fallback'),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [
          colorScheme.primary,
          colorScheme.primaryContainer,
          colorScheme.tertiaryContainer,
        ],
      ),
    ),
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 26),
        child: Icon(
          Icons.public_rounded,
          size: 84,
          color: colorScheme.onPrimary.withValues(alpha: .22),
        ),
      ),
    ),
  );
}

class _ProfileRelationshipAction extends StatelessWidget {
  const _ProfileRelationshipAction({
    required this.profile,
    required this.busy,
    required this.onRequestFriend,
  });

  final CommunityProfileOverview profile;
  final bool busy;
  final VoidCallback onRequestFriend;

  @override
  Widget build(BuildContext context) => switch (profile.relationship) {
    CommunityRelationshipStatus.none when profile.allowFriendRequests =>
      FilledButton.icon(
        onPressed: busy ? null : onRequestFriend,
        icon: busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add_alt_1_rounded),
        label: Text(communityText(context, 'Add Friend', 'إضافة صديق')),
      ),
    CommunityRelationshipStatus.pending => Chip(
      avatar: const Icon(Icons.schedule_rounded),
      label: Text(
        communityText(context, 'Request pending', 'الطلب قيد الانتظار'),
      ),
    ),
    CommunityRelationshipStatus.incoming => FilledButton.tonalIcon(
      onPressed: () => context.push('/community/connections'),
      icon: const Icon(Icons.mark_email_unread_outlined),
      label: Text(communityText(context, 'Review request', 'مراجعة الطلب')),
    ),
    CommunityRelationshipStatus.accepted => Chip(
      avatar: const Icon(Icons.people_rounded),
      label: Text(communityText(context, 'Friends', 'الأصدقاء')),
    ),
    _ => const SizedBox.shrink(),
  };
}

class _CommunitySelfQuickActions extends StatelessWidget {
  const _CommunitySelfQuickActions({
    required this.draftCount,
    required this.statsAvailable,
    required this.onPosts,
    required this.onDrafts,
    required this.onSaved,
    required this.onStats,
  });

  final int draftCount;
  final bool statsAvailable;
  final VoidCallback onPosts;
  final VoidCallback onDrafts;
  final VoidCallback onSaved;
  final VoidCallback onStats;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 340 && scale <= 18 ? 4 : 2;
        final gap = 8.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        final items = <Widget>[
          _CommunitySelfQuickAction(
            key: const Key('community-self-posts'),
            icon: Icons.article_outlined,
            label: communityText(context, 'My posts', 'منشوراتي'),
            onTap: onPosts,
          ),
          _CommunitySelfQuickAction(
            key: const Key('community-self-drafts'),
            icon: Icons.drafts_outlined,
            label: communityText(context, 'Drafts', 'المسودات'),
            badge: draftCount > 0 ? draftCount.toString() : null,
            onTap: onDrafts,
          ),
          _CommunitySelfQuickAction(
            key: const Key('community-saved-posts'),
            icon: Icons.bookmark_border_rounded,
            label: communityText(context, 'Saved', 'المحفوظات'),
            onTap: onSaved,
          ),
          _CommunitySelfQuickAction(
            key: const Key('community-self-stats'),
            icon: Icons.bar_chart_rounded,
            label: communityText(context, 'Stats', 'الإحصاءات'),
            onTap: statsAvailable ? onStats : null,
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items) SizedBox(width: width, child: item),
          ],
        );
      },
    );
  }
}

class _CommunitySelfQuickAction extends StatelessWidget {
  const _CommunitySelfQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 74),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: badge != null,
                  label: badge == null ? null : Text(badge!),
                  child: Icon(icon, color: scheme.primary, size: 22),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
