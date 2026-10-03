part of 'community_hub_page.dart';

class _CommunityMemberProfileHeader extends StatelessWidget {
  const _CommunityMemberProfileHeader({
    required this.profile,
    required this.creator,
    required this.relationshipBusy,
    required this.followBusy,
    required this.onRequestFriend,
    required this.onToggleFollow,
    required this.onOpenConnections,
  });

  final CommunityProfileOverview profile;
  final CommunityCreatorProfile? creator;
  final bool relationshipBusy;
  final bool followBusy;
  final VoidCallback onRequestFriend;
  final VoidCallback onToggleFollow;
  final ValueChanged<CommunityProfileConnectionKind> onOpenConnections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [scheme.primary.withValues(alpha: .12), scheme.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BilAccountAvatar(radius: 42, networkUrl: profile.avatarUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (profile.handle != null)
                      Text(
                        '@${profile.handle}',
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (profile.countryCode != null)
                      Text(
                        profile.countryCode!,
                        style: theme.textTheme.labelMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.bio?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(profile.bio!, style: theme.textTheme.bodyLarge),
          ],
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
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () =>
                      onOpenConnections(CommunityProfileConnectionKind.friends),
                  child: _CommunityProfileMetric(
                    icon: Icons.people_outline_rounded,
                    value: '${profile.friendCount}',
                    label: communityText(context, 'Friends', 'الأصدقاء'),
                  ),
                ),
              if (profile.followerCount != null)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onOpenConnections(
                    CommunityProfileConnectionKind.followers,
                  ),
                  child: _CommunityProfileMetric(
                    icon: Icons.group_outlined,
                    value: '${profile.followerCount}',
                    label: communityText(context, 'Followers', 'المتابعون'),
                  ),
                ),
              if (profile.followingCount != null)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onOpenConnections(
                    CommunityProfileConnectionKind.following,
                  ),
                  child: _CommunityProfileMetric(
                    icon: Icons.person_add_alt_outlined,
                    value: '${profile.followingCount}',
                    label: communityText(context, 'Following', 'يتابع'),
                  ),
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
          const SizedBox(height: 16),
          if (profile.isSelf)
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/community/profile'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    communityText(context, 'Edit profile', 'تعديل الملف'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/community/code'),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: Text(
                    communityText(context, 'My BIL Code', 'رمز BIL الخاص بي'),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ProfileRelationshipAction(
                  profile: profile,
                  busy: relationshipBusy,
                  onRequestFriend: onRequestFriend,
                ),
                if (profile.viewerFollows || profile.allowFollows)
                  OutlinedButton.icon(
                    key: const Key('community-profile-follow-action'),
                    onPressed: followBusy ? null : onToggleFollow,
                    icon: followBusy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                    avatar: const Icon(Icons.swap_horiz_rounded, size: 17),
                    label: Text(
                      communityText(context, 'Follows you', 'يتابعك'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
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
