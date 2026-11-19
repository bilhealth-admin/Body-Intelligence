part of 'community_people_page.dart';

extension _PeopleRelationshipRefresh on _CommunityPeoplePageState {
  bool _relationshipReadCurrent(
    CommunityMessageOwnerVisit visit,
    int queryGeneration,
  ) =>
      mounted &&
      identical(visit, _relationshipVisit) &&
      visit.isCurrent &&
      queryGeneration == _searchGeneration;

  Future<void> _refreshProfileRelationship(
    String userId,
    CommunityMessageOwnerVisit visit,
  ) => _refreshRelationships(
    {userId},
    visit,
    queryGeneration: _searchGeneration,
    showError: true,
  );

  Future<void> _refreshRelationships(
    Set<String> userIds,
    CommunityMessageOwnerVisit visit, {
    required int queryGeneration,
    bool showError = false,
  }) async {
    final repository = _repository;
    if (repository == null ||
        !_relationshipReadCurrent(visit, queryGeneration)) {
      return;
    }
    // A newer read can supersede an older read. It cannot supersede an actual
    // in-flight request write, whose receipt remains the local authority.
    final targets = userIds
        .where(
          (id) =>
              !_sendingRequests.contains(id) ||
              _relationshipReadTokens.containsKey(id),
        )
        .toSet();
    if (targets.isEmpty) {
      return;
    }
    final generation = ++_relationshipReadGeneration;
    _updateRelationships(() {
      for (final id in targets) {
        _relationshipReadTokens[id] = generation;
        _sendingRequests.add(id);
      }
    });
    try {
      final rows = await visit
          .run(repository.loadFriendshipsWithProfiles)
          .timeout(const Duration(seconds: 10));
      if (!_relationshipReadCurrent(visit, queryGeneration)) {
        return;
      }
      _updateRelationships(() {
        for (final id in targets) {
          if (_relationshipReadTokens[id] != generation) {
            continue;
          }
          final row = rows
              .where((row) => row['other_user_id'] == id)
              .firstOrNull;
          final status = switch (row?['status']) {
            'accepted' => CommunityFriendRequestStatus.accepted,
            'pending' =>
              row!['requester_id'] == visit.owner
                  ? CommunityFriendRequestStatus.pending
                  : CommunityFriendRequestStatus.incoming,
            'declined' when row!['requester_id'] == visit.owner =>
              CommunityFriendRequestStatus.declined,
            _ => null,
          };
          _pendingRequests.remove(id);
          _relationshipStates.remove(id);
          if (status != null) {
            _relationshipStates[id] = status;
          }
          if (status == CommunityFriendRequestStatus.pending) {
            _pendingRequests.add(id);
          }
        }
      });
    } on Object {
      // A failed read never clears a previously confirmed relationship.
      if (showError && _relationshipReadCurrent(visit, queryGeneration)) {
        // The visit guard also checks owner/query generation; make the
        // post-await State/context lifetime check explicit before UI access.
        if (!mounted) return;
        final currentContext = context;
        if (!currentContext.mounted) return;
        final messenger = ScaffoldMessenger.of(currentContext);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _copy(
                currentContext,
                'تعذر تحديث حالة العلاقة. أعد المحاولة.',
                'Could not refresh the connection. Try again.',
                'Impossible d’actualiser la relation. Réessayez.',
                'No se pudo actualizar la conexión. Inténtalo de nuevo.',
                'Bağlantı yenilenemedi. Tekrar deneyin.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted && identical(visit, _relationshipVisit) && visit.isCurrent) {
        _updateRelationships(() {
          for (final id in targets) {
            if (_relationshipReadTokens[id] != generation) {
              continue;
            }
            _relationshipReadTokens.remove(id);
            _sendingRequests.remove(id);
          }
        });
      }
    }
  }
}
