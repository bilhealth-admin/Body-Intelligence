part of 'community_notifications_page.dart';

class _ActivityReadWindow {
  const _ActivityReadWindow({required this.ids, this.before, this.beforeId});

  final Set<String> ids;
  final DateTime? before;
  final String? beforeId;
}

extension _CommunityNotificationReadReceipts
    on _CommunityNotificationsPageState {
  String? _receiptOwner(CommunityRepository? repository) {
    try {
      return repository?.currentUserId;
    } on Object {
      return null;
    }
  }

  void _bindReceiptSession() {
    unawaited(_receiptAuth?.cancel());
    _receiptAuth = null;
    _receiptSessionOwner = _receiptOwner(_repository);
    final repository = _repository;
    if (repository == null) return;
    _receiptAuth = repository.communitySocialClient.auth.onAuthStateChange
        .listen(
          (_) {
            if (!mounted || !identical(repository, _repository)) return;
            final owner = _receiptOwner(repository);
            if (owner == _receiptSessionOwner) return;
            _receiptSessionOwner = owner;
            _receiptSignedOut = owner == null;
            _loadedOwnerId = null;
            _activityReadWindows.clear();
            _retry();
          },
          onError: (Object _, StackTrace _) {
            // Auth owns session recovery; a notification must never invent one.
          },
        );
  }

  bool _receiptIsCurrent(
    CommunityRepository repository,
    String owner,
    int generation,
  ) =>
      mounted &&
      identical(repository, _repository) &&
      _receiptOwner(repository) == owner &&
      _loadedOwnerId == owner &&
      _loadGeneration == generation;

  Future<Set<String>> _markVisibleActivityRead(
    _CommunityUpdates visible,
    List<String> requested,
  ) async {
    final repository = _repository;
    final owner = _loadedOwnerId;
    final generation = _loadGeneration;
    if (repository == null ||
        owner == null ||
        _visibleReadBusy ||
        _loadingFirst ||
        _loadingMore ||
        _markingPageSeen ||
        !_receiptIsCurrent(repository, owner, generation)) {
      return {};
    }
    final allowed = visible.notifications
        .where((row) => !row.seen && !_markingSeen.contains(row.id))
        .map((row) => row.id)
        .toSet();
    final ids = requested.where(allowed.contains).toSet().take(100).toList();
    if (ids.isEmpty) return {};
    final idSet = ids.toSet();
    final windows = _activityReadWindows
        .where((window) => window.ids.any(idSet.contains))
        .toList(growable: false);
    if (windows.isEmpty) return {};
    final operation = Object();
    _visibleReadOperation = operation;
    _visibleReadBusy = true;
    try {
      // Existing owner-scoped RPC also reconciles the post-event receipt. It
      // cannot read private messages, accept friends, or grant any currency.
      await repository.markCommunityNotificationsSeen(ids);
      if (!_receiptIsCurrent(repository, owner, generation)) return {};
      final remote = <String, CommunityNotification>{};
      final kinds = _CommunityNotificationsFilters(this).filterKinds;
      for (final window in windows) {
        final rows = await repository.loadCommunityNotifications(
          before: window.before,
          beforeId: window.beforeId,
          kinds: kinds,
          limit: _CommunityNotificationsPageState._pageSize,
        );
        if (!_receiptIsCurrent(repository, owner, generation)) return {};
        for (final row in rows) {
          if (window.ids.contains(row.id)) remote[row.id] = row;
        }
      }
      final attention = await repository.loadAttention();
      if (!_receiptIsCurrent(repository, owner, generation)) return {};
      final latest = await _updates;
      if (!_receiptIsCurrent(repository, owner, generation)) return {};
      final readback = _CommunityUpdates(
        incomingRequests: attention.incomingRequests,
        unreadMessages: attention.unreadMessages,
        communityUpdates: attention.communityUpdates,
        notifications: [
          for (final row in latest.notifications)
            if (remote[row.id] case final value? when !row.seen || value.seen)
              value
            else
              row,
        ],
      );
      _updateReceiptState(() => _updates = Future.value(readback));
      await CommunityAttentionScope.refresh(context);
      if (!_receiptIsCurrent(repository, owner, generation)) return {};
      return {
        for (final id in ids)
          if (remote[id]?.seen == true) id,
      };
    } finally {
      if (identical(_visibleReadOperation, operation)) {
        _visibleReadOperation = null;
        _visibleReadBusy = false;
      }
    }
  }
}
