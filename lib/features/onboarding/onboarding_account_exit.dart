part of 'onboarding_page.dart';

extension _OnboardingAccountExit on _OnboardingPageState {
  Widget _accountExitAction() => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: TextButton.icon(
      key: const Key('onboarding-back-to-sign-in'),
      onPressed: _busy || _transitionBusy || _permissionBusy
          ? null
          : () => unawaited(_leaveSetup()),
      icon: const Icon(Icons.logout_rounded),
      label: Text(t('Back to sign in')),
    ),
  );

  Future<void> _leaveSetup() async {
    if (_busy || _transitionBusy || _permissionBusy || widget.reviewMode) {
      return;
    }
    final repository = _loadedDraftRepository;
    if (repository == null) return;
    final preferences = ref.read(preferencesRepositoryProvider);
    final auth = AppEnvironment.supabaseRuntimeReady
        ? Supabase.instance.client.auth
        : null;
    final owner = auth?.currentUser?.id;
    final snapshot = _draft.copyWith(stepId: _stepId);
    bool currentVisit() =>
        mounted &&
        identical(ref.read(onboardingDraftRepositoryProvider), repository) &&
        preferences.localOwnerId == owner;
    if (!currentVisit()) return;

    _updateState(() => _transitionBusy = true);
    FocusManager.instance.primaryFocus?.unfocus();
    Future<void> save(bool Function() current) async {
      await _draftWrites.catchError((Object _) {});
      if (!current()) throw StateError('The active account changed');
      await preferences.update(
        OnboardingDraft.preferenceKey,
        (_) => snapshot.encode(),
        isCurrent: current,
      );
    }

    try {
      if (auth != null && owner != null) {
        await signOutMatchingAccount(
          auth,
          owner,
          prepare: (current) => save(() => current() && currentVisit()),
          isCurrentVisit: () => mounted,
        );
      } else {
        await save(() => currentVisit() && auth?.currentUser == null);
      }
      if (mounted && auth?.currentUser == null) context.go('/login');
    } on Object {
      if (currentVisit() && auth?.currentUser?.id == owner) {
        _updateState(
          () => _inlineError = t(
            'Could not sign out. Check your connection and retry.',
          ),
        );
      }
    } finally {
      _updateState(() => _transitionBusy = false);
    }
  }
}
