part of 'community_repository.dart';

extension CommunityAuthorIdentityReads on CommunityRepository {
  // Kept as a repository method via the public forwarding method for injected QA.
  Future<List<CommunityPostAuthorIdentity>> _readPostAuthorIdentities(
    List<String> ids,
  ) => _runCommunityOwnerOperation((operation) async {
    if (ids.length > 100 ||
        ids.any((id) => !CommunityRepository._uuid.hasMatch(id))) {
      throw ArgumentError('Invalid Community author identities');
    }
    final requested = ids.toSet();
    if (requested.isEmpty) return const [];
    final results = await Future.wait<Object>([
      _client
          .from('bil_public_profiles')
          .select('user_id,display_name,avatar_url')
          .inFilter('user_id', requested.toList()),
      loadPostAuthors(requested.toList()),
    ]);
    operation.check();
    final rows = results[0] as List;
    final profiles = <String, Map>{};
    for (final raw in rows) {
      if (raw is! Map ||
          raw['user_id'] is! String ||
          !requested.contains(raw['user_id']) ||
          profiles.containsKey(raw['user_id']) ||
          raw['display_name'] is! String ||
          (raw['display_name'] as String).trim().isEmpty ||
          (raw['display_name'] as String).length > 60 ||
          CommunityRepository._unsafeText.hasMatch(
            raw['display_name'] as String,
          ) ||
          (raw['avatar_url'] != null && raw['avatar_url'] is! String)) {
        throw const FormatException('Invalid Community author identity');
      }
      profiles[raw['user_id'] as String] = raw;
    }
    final social = {
      for (final value in results[1] as List<CommunityPostAuthorSocial>)
        value.userId: value,
    };
    return List.unmodifiable(
      requested.map(
        (id) => CommunityPostAuthorIdentity(
          userId: id,
          displayName: profiles[id]?['display_name'] as String?,
          avatarUrl: profiles[id]?['avatar_url'] as String?,
          social: social[id],
        ),
      ),
    );
  });
}
