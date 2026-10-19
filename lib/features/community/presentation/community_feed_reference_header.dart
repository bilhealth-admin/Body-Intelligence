part of 'community_hub_page.dart';

class _CommunityFeedReferenceHeader extends StatefulWidget {
  const _CommunityFeedReferenceHeader({
    required this.repository,
    this.profile,
    this.initialProfile,
    this.initialTopics,
    required this.posts,
    required this.topics,
    required this.enabled,
    required this.onCompose,
    required this.onSelectTopic,
    this.selectedTopic,
    this.onOpenCircles,
    this.ownerIsCurrent,
  });

  final CommunityRepository repository;
  final Future<CommunityProfileOverview?>? profile;
  final CommunityProfileOverview? initialProfile;
  final List<CommunityTopic>? initialTopics;
  final List<CommunityPost> posts;
  final Future<List<CommunityTopic>> topics;
  final bool enabled;
  final Future<void> Function({String? tag, String? circle}) onCompose;
  final ValueChanged<CommunityTopic?> onSelectTopic;
  final String? selectedTopic;
  final VoidCallback? onOpenCircles;
  final ValueGetter<bool>? ownerIsCurrent;

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
    _profile = widget.profile ?? widget.repository.loadMyProfileOverview();
  }

  @override
  void didUpdateWidget(covariant _CommunityFeedReferenceHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.profile, widget.profile)) {
      _profile = widget.profile ?? widget.repository.loadMyProfileOverview();
    }
  }

  bool get _ownerCurrent => widget.ownerIsCurrent?.call() ?? true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final uniqueAuthors = <String, CommunityPost>{};
    final currentUserId = widget.repository.currentUserId.trim().toLowerCase();
    for (final post in widget.posts) {
      if (currentUserId.isNotEmpty &&
          post.authorId.trim().toLowerCase() == currentUserId) {
        continue;
      }
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
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 3),
            children: [
              FutureBuilder<CommunityProfileOverview?>(
                future: _profile,
                initialData: widget.initialProfile,
                builder: (context, snapshot) => _CommunityStoryBubble(
                  label: communityText(context, 'Create post', 'إنشاء منشور'),
                  avatarUrl: snapshot.data?.avatarUrl,
                  accent: false,
                  add: true,
                  onTap: widget.enabled && _ownerCurrent
                      ? () {
                          if (_ownerCurrent) widget.onCompose();
                        }
                      : null,
                ),
              ),
              for (final post in uniqueAuthors.values)
                _CommunityStoryBubble(
                  key: ValueKey('community-story-${post.authorId}'),
                  label:
                      post.authorName ??
                      communityText(context, 'BIL member', 'عضو BIL'),
                  avatarUrl: post.authorAvatarUrl,
                  accent: true,
                  onTap: widget.enabled && _ownerCurrent
                      ? () {
                          if (_ownerCurrent) {
                            context.push('/community/profile/${post.authorId}');
                          }
                        }
                      : null,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 7, 16, 0),
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
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Container(
                      key: const Key('community-create-post-icon'),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: .14),
                        ),
                      ),
                      child: Icon(
                        Icons.post_add_rounded,
                        size: 20,
                        color: scheme.primary,
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
        FutureBuilder<List<CommunityTopic>>(
          future: widget.topics,
          initialData: widget.initialTopics,
          builder: (context, snapshot) {
            final topics = snapshot.data ?? const <CommunityTopic>[];
            // The selected chips are projections of actual server topics.
            // The source taxonomy uses motivation-support / wellness rather
            // than invented mindset / sleep identifiers.
            final preferred = <String>[
              'nutrition',
              'fitness',
              'motivation-support',
              'wellness',
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
            return SingleChildScrollView(
              key: const Key('community-reference-topic-chips'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 3, 16, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _CommunityReferenceTab(
                    key: const Key('community-category-all'),
                    label: communityText(context, 'All', 'الكل'),
                    selected: widget.selectedTopic == null,
                    onTap: widget.enabled && _ownerCurrent
                        ? () => widget.onSelectTopic(null)
                        : null,
                  ),
                  for (final topic in visible.take(4)) ...[
                    const SizedBox(width: 7),
                    _CommunityReferenceTab(
                      key: ValueKey('community-category-${topic.slug}'),
                      selected: widget.selectedTopic == topic.slug,
                      label: switch (topic.slug) {
                        'nutrition' => communityText(
                          context,
                          'Nutrition',
                          'التغذية',
                        ),
                        'fitness' => communityText(
                          context,
                          'Workouts',
                          'التمارين',
                        ),
                        'motivation-support' =>
                          CommunityTaxonomySheet.titleForSlug(
                            context,
                            topic.slug,
                          ),
                        'wellness' => CommunityTaxonomySheet.titleForSlug(
                          context,
                          topic.slug,
                        ),
                        _ => CommunityTaxonomySheet.titleForSlug(
                          context,
                          topic.slug,
                        ),
                      },
                      onTap: widget.enabled && _ownerCurrent
                          ? () => widget.onSelectTopic(topic)
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
    super.key,
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
      width: 72,
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
                  child: BilAccountAvatar(radius: 25, networkUrl: avatarUrl),
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

class _CommunityReferenceTab extends StatelessWidget {
  const _CommunityReferenceTab({
    required this.label,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: _CommunityHubTopTab(
        label: label,
        selected: selected,
        onTap: onTap,
        singleLine: true,
      ),
    ),
  );
}
