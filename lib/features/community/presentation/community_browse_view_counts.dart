part of 'community_hub_page.dart';

Future<Map<String, int>> _communityBrowseViewCounts(
  CommunityRepository repository,
  List<CommunityPost> posts,
) async {
  if (!repository.useServerCommunityReferenceParity || posts.isEmpty) {
    return const <String, int>{};
  }
  try {
    return await repository.loadCommunityPostViewCounts(
      posts.map((post) => post.id).toList(growable: false),
    );
  } on Object {
    // Missing optional metrics are unknown, never fabricated as zero views.
    return const <String, int>{};
  }
}
