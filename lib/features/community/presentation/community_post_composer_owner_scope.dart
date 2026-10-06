part of 'community_hub_page.dart';

extension _CommunityPostComposerOwnerScope on _CommunityPostComposerPageState {
  bool get _sameComposerOwner {
    try {
      return mounted &&
          !_composerOwnerCancelled &&
          _composerOwnerId != null &&
          identical(_composerRepository, widget.repository) &&
          widget.repository.currentUserId == _composerOwnerId &&
          (widget.ownerIsCurrent?.call() ?? true);
    } on Object {
      return false;
    }
  }

  void _bindComposerOwner() {
    _composerRepository = widget.repository;
    _composerOwnerId = _communityDraftOwnerId(widget.repository);
    final binding = ++_composerBinding;
    final auth = widget.repository.communitySocialClient.auth;
    var deliveredOwner = auth.currentUser?.id;
    _composerAuth = auth.onAuthStateChange.listen(
      (state) {
        if (!mounted || binding != _composerBinding) return;
        final eventOwner = state.session?.user.id;
        final changedSession = eventOwner != deliveredOwner;
        deliveredOwner = eventOwner;
        // The event owner preserves A -> B -> A even when currentUser is A
        // again before the queued B event is delivered.
        if (changedSession || !_sameComposerOwner) {
          _invalidateComposerOwner();
        }
      },
      onError: (Object _, StackTrace _) {
        // An offline refresh is not evidence of an account change.
      },
    );
  }

  bool _checkComposerOwner() {
    if (_sameComposerOwner) return true;
    _invalidateComposerOwner();
    return false;
  }

  void _invalidateComposerOwner() {
    if (_composerOwnerCancelled) return;
    _composerOwnerCancelled = true;
    _composerBinding++;
    unawaited(_composerAuth?.cancel());
    _composerAuth = null;
    if (!mounted) return;
    _composerFocus.unfocus();
    _setComposerState(() {
      // A saved draft remains on its owner's server. This editor never becomes
      // an editable copy belonging to the next authenticated account.
      _title.clear();
      _composer.clear();
      _location.clear();
      _hashtagInput.clear();
      _mentionQuery.clear();
      _collaboratorQuery.clear();
      _selectedImages.clear();
      _mentionResults = const [];
      _collaboratorResults = const [];
      _publishing = false;
      _savingDraft = false;
      _submitError = null;
    });
  }

  Future<bool> _confirmCommunityEntry() async {
    if (!_checkComposerOwner()) return false;
    final repository = widget.repository;
    final receipt = await CommunityEntryCoordinator(
      repository,
      isCurrentOwner: () => _sameComposerOwner,
    ).check();
    if (!mounted || !_checkComposerOwner()) return false;
    if (receipt != null) return true;

    await pushCommunityPage<bool>(
      context,
      CommunityEntryGate(
        repository: repository,
        syncPhoto: () async {
          if (!mounted || !_sameComposerOwner) return false;
          final service = ProviderScope.containerOf(
            context,
            listen: false,
          ).read(profilePhotoServiceProvider);
          final result = await service.syncStoredPhotoToCommunity(
            isCurrentOwner: () => _sameComposerOwner,
          );
          return _sameComposerOwner && (result == null || result.cloudSynced);
        },
        child: _CommunityComposerEntryConfirmed(
          ownerIsCurrent: () => _sameComposerOwner,
        ),
      ),
    );
    // Identity setup is never a publishing action. Return the original editor
    // and require another explicit Publish after profile and code are saved.
    return false;
  }

  Widget _buildComposerOwnerChanged(BuildContext context) => Scaffold(
    key: const Key('community-post-owner-changed'),
    appBar: AppBar(
      leading: const CommunityReturnButton(),
      title: Text(communityText(context, 'BIL Community', 'مجتمع BIL')),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          communityText(
            context,
            'Your account changed. Return to Community to continue.',
            'تغير الحساب. ارجع إلى المجتمع للمتابعة.',
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _CommunityComposerEntryConfirmed extends StatefulWidget {
  const _CommunityComposerEntryConfirmed({required this.ownerIsCurrent});

  final ValueGetter<bool> ownerIsCurrent;

  @override
  State<_CommunityComposerEntryConfirmed> createState() =>
      _CommunityComposerEntryConfirmedState();
}

class _CommunityComposerEntryConfirmedState
    extends State<_CommunityComposerEntryConfirmed> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(widget.ownerIsCurrent());
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
