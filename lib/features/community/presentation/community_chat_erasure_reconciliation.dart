part of 'community_people_page.dart';

/// StreamBuilder(limit:1) can suppress a DELETE for an older uncached row.
/// This active-route presence-only fallback never rebuilds an unchanged chat.
extension _CommunityChatErasureReconciliation on _CommunityChatPageState {
  void _stopMessageVisibilityPoll() {
    _messageVisibilityPoll?.cancel();
    _messageVisibilityPoll = null;
    _messageVisibilityPollEpoch++;
    _messageVisibilityPollBusy = false;
  }

  void _startMessageVisibilityPoll(int binding) {
    _stopMessageVisibilityPoll();
    final epoch = _messageVisibilityPollEpoch;
    _messageVisibilityPoll = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_reconcileMessageVisibility(binding, epoch));
    });
  }

  Future<void> _reconcileMessageVisibility(int binding, int epoch) async {
    if (!_current(binding) ||
        epoch != _messageVisibilityPollEpoch ||
        _messageVisibilityPollBusy ||
        _rows.isEmpty ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _messageVisibilityPollBusy = true;
    final generation = _loadGeneration;
    final snapshot = List<CommunityMessage>.of(_rows);
    try {
      final visible = <String>{};
      for (var offset = 0; offset < snapshot.length; offset += 200) {
        final ids = snapshot
            .skip(offset)
            .take(200)
            .map((row) => row.id)
            .toList();
        visible.addAll(
          await _run(
            binding,
            () => _repository!.loadVisibleConversationMessageIds(_peerId!, ids),
          ),
        );
        _check(binding);
        if (epoch != _messageVisibilityPollEpoch ||
            generation != _loadGeneration) {
          return;
        }
      }
      // Only queried identities can be disproved by this response. Older
      // history loaded during the await was not part of this snapshot.
      final missing = snapshot.map((row) => row.id).toSet().difference(visible);
      if (missing.isEmpty) return;
      _check(binding);
      if (epoch != _messageVisibilityPollEpoch ||
          generation != _loadGeneration) {
        return;
      }
      _setChatState(() {
        _loadGeneration++;
        _rows = List.unmodifiable(
          _rows.where((row) => !missing.contains(row.id)),
        );
        _observeMessagePresentation();
        _messages = Future.value(_rows);
      });
    } on Object {
      // Failure/unknown presence never deletes local text or reports success.
    } finally {
      // An old owner/visit's completion must not release a newer flight.
      if (epoch == _messageVisibilityPollEpoch) {
        _messageVisibilityPollBusy = false;
      }
    }
  }
}
