part of 'community_hub_page.dart';

/// The category navigation stays above the scrolling posts, below the hub tabs.
class _CommunityFeedReferenceHeader extends StatelessWidget {
  const _CommunityFeedReferenceHeader({
    required this.topics,
    required this.enabled,
    required this.onSelectTopic,
    this.initialTopics,
    this.selectedTopic,
    this.ownerIsCurrent,
  });
  final Future<List<CommunityTopic>> topics;
  final List<CommunityTopic>? initialTopics;
  final bool enabled;
  final ValueChanged<CommunityTopic?> onSelectTopic;
  final String? selectedTopic;
  final ValueGetter<bool>? ownerIsCurrent;

  bool get _ownerCurrent => ownerIsCurrent?.call() ?? true;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('community-pinned-categories'),
    color: Theme.of(context).scaffoldBackgroundColor,
    child: FutureBuilder<List<CommunityTopic>>(
      future: topics,
      initialData: initialTopics,
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
                selected: selectedTopic == null,
                onTap: enabled && _ownerCurrent
                    ? () => onSelectTopic(null)
                    : null,
              ),
              for (final topic in visible.take(4)) ...[
                const SizedBox(width: 7),
                _CommunityReferenceTab(
                  key: ValueKey('community-category-${topic.slug}'),
                  selected: selectedTopic == topic.slug,
                  label: switch (topic.slug) {
                    'nutrition' => communityText(
                      context,
                      'Nutrition',
                      'التغذية',
                    ),
                    'fitness' => communityText(context, 'Workouts', 'التمارين'),
                    'motivation-support' => CommunityTaxonomySheet.titleForSlug(
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
                  onTap: enabled && _ownerCurrent
                      ? () => onSelectTopic(topic)
                      : null,
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
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
