part of 'premium_route_glass_gate.dart';

class _RetainedAiCoachSurface extends ConsumerStatefulWidget {
  const _RetainedAiCoachSurface({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<_RetainedAiCoachSurface> createState() =>
      _RetainedAiCoachSurfaceState();
}

class _RetainedAiCoachSurfaceState
    extends ConsumerState<_RetainedAiCoachSurface> {
  bool _contentMounted = false;
  bool? _lastVerifiedAccess;
  DateTime? _pendingQuotaBoundary;
  DateTime? _quotaCheckStartedAt;
  String? _quotaCheckPeriodKey;
  StoreRenewalObservation? _pendingQuotaObservation;
  Timer? _ownerResolutionTimer;
  bool _ownerResolutionExpired = false;

  @override
  void initState() {
    super.initState();
    _startOwnerResolutionWindow();
  }

  void _startOwnerResolutionWindow() {
    _ownerResolutionTimer?.cancel();
    _ownerResolutionExpired = false;
    _ownerResolutionTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() => _ownerResolutionExpired = true);
    });
  }

  void _retryOwnerResolution() {
    setState(_startOwnerResolutionWindow);
    ref.invalidate(verifiedEntitlementOwnerProvider);
    ref.invalidate(aiCoachCreditAccessProvider);
  }

  Future<void> _openSignIn() async {
    await context.push<void>('/login');
    if (!mounted) return;
    _retryOwnerResolution();
  }

  @override
  void dispose() {
    _ownerResolutionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final credits = ref.watch(aiCoachCreditAccessProvider);
    final ownerSnapshot = ref.watch(verifiedEntitlementOwnerProvider);
    final ownerKnown = ref.watch(verifiedEntitlementOwnerIdProvider) != null;
    if (ownerKnown || ownerSnapshot.hasValue || ownerSnapshot.hasError) {
      _ownerResolutionTimer?.cancel();
    }
    if (!ownerKnown) {
      // A settled signed-out owner is not an in-flight credit request. No
      // entitlement is granted here, and no Coach child or paid offer mounts.
      if (ownerSnapshot.hasError ||
          (!ownerSnapshot.hasValue && _ownerResolutionExpired)) {
        return _AiCoachAccountRecoverySurface(
          unavailable: true,
          onRetry: _retryOwnerResolution,
          onSignIn: _openSignIn,
        );
      }
      if (ownerSnapshot.hasValue) {
        return _AiCoachAccountRecoverySurface(
          unavailable: false,
          onRetry: _retryOwnerResolution,
          onSignIn: _openSignIn,
        );
      }
      return const _AiCoachAccessCheckingSurface();
    }
    // AsyncValue can retain previous data during a dependency reload. Only a
    // completed check for this owner may populate the owner's retained state.
    final freshAccess = credits.isLoading || credits.hasError || !ownerKnown
        ? null
        : credits.asData?.value;
    if (freshAccess != null) {
      _lastVerifiedAccess = freshAccess;
    }

    // Observe only its exact-boundary timer. A paid plan never grants AI
    // credit; the reserved-aware quota RPC remains the sole Send authority.
    ref.watch(verifiedSubscriptionAccessProvider);
    final source = ref.watch(verifiedSubscriptionStateProvider);
    final hint = ref.watch(storeRenewalObservationProvider);
    final quota = ref.watch(aiCoachAccessSnapshotStoreProvider);
    final now = ref.watch(verifiedEntitlementClockProvider)().toUtc();
    final definitive =
        !source.isLoading &&
        !source.hasError &&
        source.value?.storeRenewalDefinitivelyInactive == true;
    if (definitive || (hint != null && !hint.hadAiAllowance)) {
      _pendingQuotaBoundary = null;
      _pendingQuotaObservation = null;
      _quotaCheckStartedAt = null;
      _quotaCheckPeriodKey = null;
    }
    if (hint != null && hint.hadAiAllowance && hint.pendingAt(now)) {
      // A future store period cannot embargo independent current credits.
      // Keep the first check threshold stable across rebuilds of this hint.
      if (_pendingQuotaBoundary == null &&
          _quotaCheckPeriodKey != hint.periodKey) {
        _quotaCheckStartedAt = now;
        _quotaCheckPeriodKey = hint.periodKey;
      }
      _quotaCheckStartedAt ??= now;
      _pendingQuotaObservation ??= hint;
      _pendingQuotaBoundary ??= _quotaCheckStartedAt;
    } else if (_pendingQuotaBoundary == null) {
      _quotaCheckStartedAt = null;
      _quotaCheckPeriodKey = null;
    }
    final quotaAfterBoundary =
        quota.usageResponseFresh &&
        quota.usageRequestedAt != null &&
        _pendingQuotaBoundary != null &&
        !quota.usageRequestedAt!.isBefore(_pendingQuotaBoundary!);
    // A fresh positive reserved-aware balance is independent of plan. A fresh
    // ai_coach/zero is real quota exhaustion; Free/zero during a known renewal
    // cannot prove exhaustion of the next period and must not offer repurchase.
    if (quotaAfterBoundary &&
        (freshAccess == true ||
            (freshAccess == false && quota.verifiedUsagePlan == 'ai_coach'))) {
      _pendingQuotaBoundary = null;
      _pendingQuotaObservation = null;
      // This quota proof also resolves the currently observed future hint.
      // Keep the first-check time; a later rebuild must not embargo it again.
      if (hint != null && hint.pendingAt(now)) {
        _quotaCheckPeriodKey = hint.periodKey;
      }
    }
    final renewalAmbiguous = _pendingQuotaBoundary != null && !definitive;
    final allowed = freshAccess == true && !renewalAmbiguous;
    final readOnly =
        _contentMounted &&
        (renewalAmbiguous || credits.isLoading || credits.hasError);
    final unavailable = credits.hasError && _lastVerifiedAccess == null;
    final checking =
        credits.isLoading && _lastVerifiedAccess == null && !unavailable;
    if (allowed) _contentMounted = true;
    final burst = ref.watch(storeRenewalRecheckProvider);
    if (renewalAmbiguous && hint != null) burst.begin(hint);
    return ListenableBuilder(
      listenable: burst,
      builder: (context, _) {
        // The canonical row can advance while quota is still unavailable.
        // Its new period has no pending burst: keep the original deadline.
        final pendingQuota = _pendingQuotaObservation;
        final quotaTimedOut =
            pendingQuota != null && burst.timedOut(pendingQuota);
        final retry = readOnly && (credits.hasError || quotaTimedOut);
        if (renewalAmbiguous && !_contentMounted) {
          if (quotaTimedOut) {
            return _PremiumRouteAccessUnavailable(
              title: _featureName(context, PremiumGateFeature.aiCoach),
              isDark: Theme.of(context).brightness == Brightness.dark,
              returnToDashboard: true,
              onRetry: () {
                ref.invalidate(aiCoachCreditAccessProvider);
                // Fresh canonical proof needs only quota recovery. Never
                // requery the old store period solely to refresh AI credits.
                if (hint != null && hint.pendingAt(now)) burst.retry(hint);
              },
              child: const SizedBox.shrink(),
            );
          }
          return const _AiCoachAccessCheckingSurface();
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            if (!_contentMounted && checking)
              const _AiCoachAccessCheckingSurface(),
            // Keep the same element position even when the gate is shown. Credit
            // settlement must not discard a draft, scroll position or transcript.
            if (_contentMounted)
              KeyedSubtree(
                key: const ValueKey('ai-coach-retained-content'),
                child: ExcludeFocus(
                  excluding: !allowed,
                  child: AbsorbPointer(
                    absorbing: !allowed,
                    child: Semantics(
                      blockUserActions: !allowed,
                      child: TooltipVisibility(
                        visible: allowed,
                        child: Opacity(
                          opacity: allowed || readOnly ? 1 : 0,
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (readOnly) ...[
              Positioned.fill(
                child: Focus(
                  autofocus: true,
                  onKeyEvent: (_, event) =>
                      event.logicalKey == LogicalKeyboardKey.escape ||
                          event.logicalKey == LogicalKeyboardKey.goBack
                      ? KeyEventResult.ignored
                      : KeyEventResult.handled,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top,
                left: 4,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: BackButton(
                    onPressed: () => _handlePremiumRouteBack(
                      context,
                      returnToDashboard: true,
                    ),
                  ),
                ),
              ),
              if (retry)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: TextButton(
                      onPressed: () {
                        ref.invalidate(aiCoachCreditAccessProvider);
                        if (hint != null && hint.pendingAt(now)) {
                          burst.retry(hint);
                        }
                      },
                      child: Text(context.strings.text('Try again')),
                    ),
                  ),
                ),
            ],
            if (!allowed &&
                !readOnly &&
                (!checking || _contentMounted || unavailable))
              const _PremiumRouteGateContents(
                feature: PremiumGateFeature.aiCoach,
                child: SizedBox.shrink(),
              ),
          ],
        );
      },
    );
  }
}
