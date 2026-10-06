part of 'community_hub_page.dart';

/// One list/detail visit keeps its original account, repository and circle.
/// The event payload also invalidates a queued A -> B -> A transition.
class _CommunityCircleOwnerScope {
  _CommunityCircleOwnerScope({
    required this.repository,
    required this.target,
    required this.currentVisit,
    required this.onInvalidated,
    this.parentIsCurrent,
    this.parentChanges,
  }) : ownerId = _communityDraftOwnerId(repository) {
    final auth = repository.communitySocialClient.auth;
    var deliveredOwner = auth.currentUser?.id;
    _auth = auth.onAuthStateChange.listen(
      (state) {
        final next = state.session?.user.id;
        final changed = next != deliveredOwner;
        deliveredOwner = next;
        if (changed || !isCurrent) _cancel();
      },
      onError: (Object _, StackTrace _) {
        // A refresh transport error alone does not establish another account.
      },
    );
    parentChanges?.addListener(_parentChanged);
  }

  final CommunityRepository repository;
  final String target;
  final String? ownerId;
  final ValueGetter<bool> currentVisit;
  final VoidCallback onInvalidated;
  final ValueGetter<bool>? parentIsCurrent;
  final Listenable? parentChanges;
  final ValueNotifier<int> changes = ValueNotifier(0);
  StreamSubscription<AuthState>? _auth;
  bool _cancelled = false;
  bool _disposeRequested = false;
  bool _signalScheduled = false;
  bool _signalDisposed = false;

  bool get isCurrent =>
      !_cancelled &&
      !_disposeRequested &&
      currentVisit() &&
      ownerId != null &&
      _communityDraftOwnerId(repository) == ownerId &&
      (parentIsCurrent?.call() ?? true);

  void _parentChanged() {
    if (parentIsCurrent?.call() == false) _cancel();
  }

  void _cancel({bool dispose = false}) {
    final wasCancelled = _cancelled;
    _cancelled = true;
    _disposeRequested = _disposeRequested || dispose;
    unawaited(_auth?.cancel());
    _auth = null;
    parentChanges?.removeListener(_parentChanged);
    if (_signalDisposed || _signalScheduled || (wasCancelled && !dispose)) {
      return;
    }
    _signalScheduled = true;
    // A parent replacement can happen during build. Checks cancel immediately;
    // modal routes are notified after that synchronous frame work finishes.
    scheduleMicrotask(() {
      _signalScheduled = false;
      if (_signalDisposed) return;
      changes.value++;
      if (!_disposeRequested && currentVisit()) onInvalidated();
      if (_disposeRequested) {
        _signalDisposed = true;
        changes.dispose();
      }
    });
  }

  void dispose() => _cancel(dispose: true);

  _CommunityProfileVisit? capture() {
    if (!isCurrent) return null;
    // Existing post tiles and their detail routes accept this captured visit.
    // Reusing it keeps their reaction/save/dialog guards intact for Circles.
    return _CommunityProfileVisit(
      repository: repository,
      ownerId: ownerId!,
      targetId: target,
      isCurrent: () => isCurrent,
      changes: changes,
    );
  }
}

Future<void> _composeFromCircle(
  BuildContext context,
  _CommunityProfileVisit visit,
  String slug,
  Future<void> Function(String) compose,
) async {
  try {
    await visit.run(() async {
      visit.check();
      await compose(slug);
      visit.check();
    });
  } on CommunityOwnerOperationCancelled {
    // An old callback cannot acquire a later owner, repository or circle.
  } on Object {
    if (context.mounted && visit.isCurrent()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not update this circle safely. Try again.',
              'تعذر تحديث هذه الدائرة بأمان. حاول مجددًا.',
            ),
          ),
        ),
      );
    }
  }
}
