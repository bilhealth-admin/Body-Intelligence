part of 'community_messages_page.dart';

/// A page visit, including its modal callbacks, belongs to the captured owner.
/// Delivered auth events retire A -> B -> A even if currentUser is already A.
class _MessageOwnerVisit extends ChangeNotifier {
  _MessageOwnerVisit(this.repository, this._mounted, this._onChanged) {
    try {
      owner = repository.currentUserId;
    } on Object {
      _cancelled = true;
    }
    final auth = repository.communitySocialClient.auth;
    var delivered = auth.currentUser?.id;
    _auth = auth.onAuthStateChange.listen((state) {
      if (_disposed || _cancelled) return;
      final next = state.session?.user.id;
      final changed = next != delivered;
      delivered = next;
      if (changed || !isCurrent) {
        _cancelled = true;
        notifyListeners();
        _onChanged();
      }
    }, onError: (Object _, StackTrace _) {});
  }
  final CommunityRepository repository;
  final bool Function() _mounted;
  final VoidCallback _onChanged;
  String? owner;
  bool _cancelled = false, _disposed = false;
  StreamSubscription<AuthState>? _auth;
  bool get isCurrent {
    if (_disposed || _cancelled || !_mounted() || owner == null) return false;
    try {
      return repository.currentUserId == owner;
    } on Object {
      return false;
    }
  }

  void check() {
    if (!isCurrent) throw const CommunityOwnerOperationCancelled();
    CommunityOwnerOperation.checkCurrent();
  }

  Future<T> run<T>(Future<T> Function() action) {
    check();
    return repository.runForCommunityOwner(
      action,
      ownerId: owner!,
      isCurrentOwner: () => isCurrent,
    );
  }

  Widget guard(Widget child) => ListenableBuilder(
    listenable: this,
    builder: (_, _) => isCurrent
        ? child
        : Scaffold(
            appBar: AppBar(leading: const CommunityReturnButton()),
            body: const _MessageOwnerChanged(),
          ),
  );
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_auth?.cancel());
    // A parent can be replaced while a policy sheet is still mounted. Notify
    // that sibling route after the current build, with checks invalidated now.
    scheduleMicrotask(() {
      notifyListeners();
      super.dispose();
    });
  }
}

class _MessageOwnerChanged extends StatelessWidget {
  const _MessageOwnerChanged();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        communityText(
          context,
          'Your account changed. Return to Community to continue.',
          'تغير الحساب. ارجع إلى المجتمع للمتابعة.',
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

String _privateMessageLimitText(BuildContext context) => communityText(
  context,
  'Keep the message within 2000 characters. Your text is kept.',
  'اجعل الرسالة في حدود 2000 حرف. احتفظنا بالنص كاملًا.',
);
String _privateSubjectLimitText(BuildContext context) => communityText(
  context,
  'Keep the subject within 120 characters. Your text is kept.',
  'اجعل العنوان في حدود 120 حرفًا. احتفظنا بالنص كاملًا.',
);

/// The policy sheet uses the same account lifetime even if an already-mounted
/// consent callback runs before the owner-change rebuild removes that sheet.
class _MessagePolicyRepository extends CommunityRepository {
  _MessagePolicyRepository(this.visit)
    : super(visit.repository.communitySocialClient);
  final _MessageOwnerVisit visit;
  @override
  String get currentUserId {
    visit.check();
    return visit.owner!;
  }

  @override
  Future<CommunityPolicyState> loadCommunityPolicyState({
    required String localeCode,
  }) => visit.run(
    () => visit.repository.loadCommunityPolicyState(localeCode: localeCode),
  );
  @override
  Future<void> acceptContentPolicy(String version) =>
      visit.run(() => visit.repository.acceptContentPolicy(version));
}

/// Opens the existing consent UI without allowing a later account to inherit
/// the message entry's consent callback. No acceptance is created on opening.
Future<void> showCommunityMessagingPolicy(
  BuildContext context, {
  required CommunityRepository repository,
  required bool Function() isCurrent,
}) async {
  if (!context.mounted || !isCurrent()) return;
  final visit = _MessageOwnerVisit(
    repository,
    () => context.mounted && isCurrent(),
    () {},
  );
  try {
    visit.check();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => visit.guard(
          CommunitySafetyPage(repository: _MessagePolicyRepository(visit)),
        ),
      ),
    );
  } on CommunityOwnerOperationCancelled {
    // The original entry no longer owns this policy sheet.
  } finally {
    visit.dispose();
  }
}
