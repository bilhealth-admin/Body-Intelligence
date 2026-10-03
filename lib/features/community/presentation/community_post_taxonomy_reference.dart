part of 'community_hub_page.dart';

class _CommunityPostTaxonomyReference extends StatelessWidget {
  const _CommunityPostTaxonomyReference({
    required this.metadata,
    required this.repository,
  });

  final CommunityPostReferenceMetadata metadata;
  final CommunityRepository repository;

  Future<void> _openTopic(
    BuildContext context,
    CommunityPostTopicReference reference,
  ) async {
    try {
      final topics = await repository.loadCommunityTopics();
      final topic = topics.firstWhere((value) => value.slug == reference.slug);
      if (!context.mounted) return;
      await pushCommunityPage<void>(
        context,
        _CommunityTopicPage(repository: repository, topic: topic),
      );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'This topic is unavailable right now.',
              'هذا الموضوع غير متاح حاليًا.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openCircle(
    BuildContext context,
    CommunityPostCircleReference reference,
  ) async {
    try {
      final circles = await repository.loadCommunityCircles();
      final circle = circles.firstWhere((value) => value.slug == reference.slug);
      if (!context.mounted) return;
      await pushCommunityPage<void>(
        context,
        _CommunityCirclePage(repository: repository, circle: circle),
      );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'This Circle is unavailable right now.',
              'هذه الدائرة غير متاحة حاليًا.',
            ),
          ),
        ),
      );
    }
  }

  Widget _topicCard(
    BuildContext context,
    CommunityPostTopicReference topic,
  ) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () => _openTopic(context, topic),
    child: Ink(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(CommunityTaxonomySheet.iconForSlug(topic.slug), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              CommunityTaxonomySheet.titleForSlug(context, topic.slug),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            topic.postCount.toString() +
                ' ' +
                communityText(context, 'posts', 'منشور'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(width: 4),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            size: 20,
          ),
        ],
      ),
    ),
  );

  Widget _circleCard(
    BuildContext context,
    CommunityPostCircleReference circle,
  ) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () => _openCircle(context, circle),
    child: Ink(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_2_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _circleTitle(context, circle.slug),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            circle.postCount.toString() +
                ' ' +
                communityText(context, 'posts', 'منشور'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(width: 4),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            size: 20,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final topic in metadata.topics) ...[
        _topicCard(context, topic),
        const SizedBox(height: 8),
      ],
      if (metadata.circle case final circle?) _circleCard(context, circle),
    ],
  );
}
