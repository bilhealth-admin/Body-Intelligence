part of 'community_hub_page.dart';

class _CommunityFeedTopicSuggestions extends StatelessWidget {
  const _CommunityFeedTopicSuggestions({
    required this.topics,
    required this.onOpen,
  });

  final Future<List<CommunityTopic>> topics;
  final ValueChanged<CommunityTopic> onOpen;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CommunityTopic>>(
    future: topics,
    builder: (context, snapshot) {
      final visible = (snapshot.data ?? const <CommunityTopic>[])
          .where((topic) => topic.featured)
          .take(5)
          .toList(growable: false);
      if (visible.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 0, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Text(
                communityText(
                  context,
                  'Topics you might like',
                  'مواضيع قد تعجبك',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 9),
            SizedBox(
              height: 112,
              child: ListView.separated(
                key: const Key('community-feed-topic-suggestions'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.only(end: 16),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final topic = visible[index];
                  return SizedBox(
                    width: 190,
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        key: Key('community-feed-topic-${topic.slug}'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onOpen(topic),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              BilSemanticIconBadge(
                                kind: BilSemanticIconKind.community,
                                size: 38,
                                iconSize: 19,
                                iconOverride:
                                    CommunityTaxonomySheet.iconForSlug(
                                      topic.slug,
                                    ),
                                appleIconOverride:
                                    CommunityTaxonomySheet.iconForSlug(
                                      topic.slug,
                                    ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      CommunityTaxonomySheet.titleForSlug(
                                        context,
                                        topic.slug,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${topic.postCount} ${communityText(context, 'posts', 'منشورات')}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
