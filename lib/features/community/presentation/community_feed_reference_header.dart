part of 'community_hub_page.dart';

class _CommunityFeedReferenceHeader extends StatefulWidget {
  const _CommunityFeedReferenceHeader({
    required this.repository,
    required this.posts,
    required this.topics,
    required this.enabled,
    required this.onCompose,
    required this.onOpenTopic,
    this.onOpenCircles,
  });

  final CommunityRepository repository;
  final List<CommunityPost> posts;
  final Future<List<CommunityTopic>> topics;
  final bool enabled;
  final Future<void> Function({String? tag, String? circle}) onCompose;
  final ValueChanged<CommunityTopic> onOpenTopic;
  final VoidCallback? onOpenCircles;

  @override
  State<_CommunityFeedReferenceHeader> createState() =>
      _CommunityFeedReferenceHeaderState();
}

class _CommunityFeedReferenceHeaderState
    extends State<_CommunityFeedReferenceHeader> {
  late Future<CommunityProfileOverview?> _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.repository.loadMyProfileOverview();
  }

  @override
  void didUpdateWidget(covariant _CommunityFeedReferenceHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _profile = widget.repository.loadMyProfileOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final uniqueAuthors = <String, CommunityPost>{};
    for (final post in widget.posts) {
      uniqueAuthors.putIfAbsent(post.authorId, () => post);
      if (uniqueAuthors.length >= 4) break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height:
              94 +
              (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0, 36),
          child: ListView(
            key: const Key('community-reference-stories'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 9, 16, 6),
            children: [
              FutureBuilder<CommunityProfileOverview?>(
                future: _profile,
                builder: (context, snapshot) => _CommunityStoryBubble(
                  label: communityText(context, 'You', 'أنت'),
                  avatarUrl: snapshot.data?.avatarUrl,
                  accent: true,
                  add: true,
                  onTap: widget.enabled ? () => widget.onCompose() : null,
                ),
              ),
              for (final post in uniqueAuthors.values)
                _CommunityStoryBubble(
                  label:
                      post.authorName ??
                      communityText(context, 'BIL member', 'عضو BIL'),
                  avatarUrl: post.authorAvatarUrl,
                  accent: true,
                  onTap: widget.enabled
                      ? () =>
                            context.push('/community/profile/${post.authorId}')
                      : null,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 3, 16, 0),
          child: Material(
            color: dark
                ? scheme.surfaceContainerHigh.withValues(alpha: .74)
                : const Color(0xFFF1F6FC),
            borderRadius: BorderRadius.circular(17),
            child: InkWell(
              key: const Key('community-create-post'),
              onTap: widget.enabled ? () => widget.onCompose() : null,
              borderRadius: BorderRadius.circular(17),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    FutureBuilder<CommunityProfileOverview?>(
                      future: _profile,
                      builder: (context, snapshot) => BilAccountAvatar(
                        radius: 18,
                        networkUrl: snapshot.data?.avatarUrl,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        communityText(
                          context,
                          'Share an experience or win',
                          'شارك تجربة أو إنجازًا',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      size: 19,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 7, 14, 2),
          child: Row(
            children: [
              Expanded(
                child: _CommunityComposeAction(
                  icon: Icons.photo_camera_outlined,
                  label: communityText(context, 'Photo', 'صورة'),
                  onTap: widget.enabled ? () => widget.onCompose() : null,
                ),
              ),
              Expanded(
                child: _CommunityComposeAction(
                  icon: Icons.poll_outlined,
                  label: communityText(context, 'Poll', 'استطلاع'),
                  onTap: widget.enabled ? () => widget.onCompose() : null,
                ),
              ),
              Expanded(
                child: _CommunityComposeAction(
                  icon: Icons.groups_outlined,
                  label: communityText(context, 'Circles', 'الدوائر'),
                  onTap: widget.enabled ? widget.onOpenCircles : null,
                ),
              ),
              Expanded(
                child: _CommunityComposeAction(
                  icon: Icons.auto_awesome_outlined,
                  label: communityText(context, 'AI Coach', 'AI Coach'),
                  onTap: widget.enabled
                      ? () => context.push('/intelligence-center')
                      : null,
                ),
              ),
            ],
          ),
        ),
        FutureBuilder<List<CommunityTopic>>(
          future: widget.topics,
          builder: (context, snapshot) {
            final topics = snapshot.data ?? const <CommunityTopic>[];
            final preferred = <String>[
              'nutrition',
              'fitness',
              'mindset',
              'sleep',
            ];
            final visible = <CommunityTopic>[];
            for (final slug in preferred) {
              for (final topic in topics) {
                if (topic.slug.contains(slug) && !visible.contains(topic)) {
                  visible.add(topic);
                  break;
                }
              }
            }
            for (final topic in topics) {
              if (!visible.contains(topic) && visible.length < 4) {
                visible.add(topic);
              }
            }
            return SizedBox(
              height:
                  48 +
                  (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(
                    0,
                    36,
                  ),
              child: ListView(
                key: const Key('community-reference-topic-chips'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.fromSTEB(16, 5, 16, 6),
                children: [
                  _CommunityReferenceChip(
                    label: communityText(context, 'All', 'الكل'),
                    selected: true,
                    onTap: null,
                  ),
                  for (final topic in visible.take(4)) ...[
                    const SizedBox(width: 7),
                    _CommunityReferenceChip(
                      label: CommunityTaxonomySheet.titleForSlug(
                        context,
                        topic.slug,
                      ),
                      onTap: widget.enabled
                          ? () => widget.onOpenTopic(topic)
                          : null,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CommunityStoryBubble extends StatelessWidget {
  const _CommunityStoryBubble({
    required this.label,
    required this.avatarUrl,
    this.accent = false,
    this.add = false,
    this.onTap,
  });

  final String label;
  final String? avatarUrl;
  final bool accent;
  final bool add;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 67,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: accent ? 2 : 1,
                      color: accent ? scheme.primary : scheme.outlineVariant,
                    ),
                  ),
                  child: BilAccountAvatar(radius: 23, networkUrl: avatarUrl),
                ),
                if (add)
                  PositionedDirectional(
                    end: -2,
                    bottom: -1,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: scheme.onPrimary,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityComposeAction extends StatelessWidget {
  const _CommunityComposeAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CommunityReferenceChip extends StatelessWidget {
  const _CommunityReferenceChip({
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary
          : scheme.surfaceContainerHighest.withValues(alpha: .55),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
