part of 'community_people_page.dart';

extension _CommunityChatOwnerScope on _CommunityChatPageState {
  bool _current(int binding) {
    try {
      return mounted &&
          !_ownerCancelled &&
          binding == _binding &&
          _ownerId != null &&
          _peerId == widget.userId &&
          _repository?.currentUserId == _ownerId;
    } on Object {
      return false;
    }
  }

  void _check(int binding) {
    if (!_current(binding)) throw const CommunityOwnerOperationCancelled();
    CommunityOwnerOperation.checkCurrent();
  }

  Future<T> _run<T>(int binding, Future<T> Function() action) {
    _check(binding);
    return _repository!.runForCommunityOwner(
      action,
      ownerId: _ownerId!,
      isCurrentOwner: () => _current(binding),
    );
  }

  void _retire() {
    _ownerCancelled = true;
    _binding++;
    _loadGeneration++;
    unawaited(_conversationChanges?.cancel());
    unawaited(_auth?.cancel());
    _conversationChanges = null;
    _auth = null;
    _rows = const [];
    _messages = Future.value(const []);
    _hasOlder = false;
    _loadingOlder = false;
    _sending = false;
  }

  void _bind() {
    _repository = widget.repository;
    if (_repository == null && AppEnvironment.communityConfigured) {
      try {
        final supabase = Supabase.instance;
        if (supabase.isInitialized &&
            supabase.client.auth.currentUser != null) {
          _repository = CommunityRepository(supabase.client);
        }
      } on Object {
        /* Missing initialization is a signed-out state. */
      }
    }
    _ownerCancelled = false;
    _peerId = widget.userId;
    try {
      _ownerId = _repository?.currentUserId;
    } on Object {
      _ownerId = null;
    }
    if (_ownerId == null) {
      _repository = null;
      return;
    }
    final binding = ++_binding;
    final auth = _repository!.communitySocialClient.auth;
    var deliveredOwner = auth.currentUser?.id;
    _auth = auth.onAuthStateChange.listen(
      (state) {
        if (binding != _binding || !mounted) return;
        final next = state.session?.user.id;
        final changed = next != deliveredOwner;
        deliveredOwner = next;
        if (changed || !_current(binding)) {
          _retire();
          _composer.clear();
          _setChatState(() {});
        }
      },
      onError: (Object _, StackTrace _) {
        // A same-owner offline token refresh does not erase a private draft.
      },
    );
    _messages = _loadConversation();
    _watchConversation();
  }
}
