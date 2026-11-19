part of 'premium_route_glass_gate.dart';

/// Both stores retain presentation during observed renewal ambiguity.
/// Exact access authority and definitive negative decisions remain unchanged.
class _RetainedStorePremiumSurface extends ConsumerStatefulWidget {
  const _RetainedStorePremiumSurface({
    super.key,
    required this.feature,
    required this.child,
  });
  final PremiumGateFeature feature;
  final Widget child;
  @override
  ConsumerState<_RetainedStorePremiumSurface> createState() =>
      _RetainedStorePremiumSurfaceState();
}

class _RetainedStorePremiumSurfaceState
    extends ConsumerState<_RetainedStorePremiumSurface> {
  bool _authorizedChildMounted = false;
  StoreRenewalObservation? _lastObservation;

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(verifiedEntitlementOwnerIdProvider);
    final source = ref.watch(verifiedSubscriptionStateProvider);
    final access = ref.watch(verifiedSubscriptionAccessProvider);
    final now = ref.watch(verifiedEntitlementClockProvider)().toUtc();
    final observed = ref.watch(storeRenewalObservationProvider);
    final definitive =
        !source.isLoading &&
        !source.hasError &&
        source.value?.authority == EntitlementAuthority.verifiedServer &&
        (source.value?.storeRenewalDefinitivelyInactive == true ||
            (source.value?.plan != CommercePlan.free && observed == null));
    if (observed?.ownerId == owner && owner != null) {
      _lastObservation = observed;
    }
    final hint = observed?.ownerId == owner
        ? observed
        : !definitive && _lastObservation?.ownerId == owner
        ? _lastObservation
        : null;
    final paid =
        !access.isLoading &&
        !access.hasError &&
        _verifiedSubscriptionAllowsFeature(access.value, widget.feature);
    final storePaid =
        paid &&
        (access.value?.provider == SubscriptionProvider.google ||
            access.value?.provider == SubscriptionProvider.apple);
    if (storePaid) {
      // Encrypted startup continuity may precede the first fresh metadata read.
      // Keep the same child tree when that display-only observation arrives.
      _authorizedChildMounted = true;
      if (hint != null && !hint.pendingAt(now)) _lastObservation = hint;
    }
    final ambiguous = !paid && hint != null && hint.pendingAt(now);
    if (!ambiguous && !(storePaid && _authorizedChildMounted)) {
      // A fresh terminal/absent/nonrenewing result has no observation. Never
      // retain an old hint across that authoritative negative decision.
      _lastObservation = null;
      _authorizedChildMounted = false;
      return _PremiumRouteGateContents(
        feature: widget.feature,
        child: widget.child,
      );
    }
    final burst = ref.watch(storeRenewalRecheckProvider);
    if (ambiguous) burst.begin(hint);
    return ListenableBuilder(
      listenable: burst,
      builder: (context, _) {
        final timedOut = ambiguous && burst.timedOut(hint);
        if (!_authorizedChildMounted) {
          // Initial expired/unknown observations disclose no protected child.
          if (!timedOut) {
            return _PremiumRouteAccessChecking(
              title: _featureName(context, widget.feature),
              isDark: Theme.of(context).brightness == Brightness.dark,
              returnToDashboard: false,
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(_featureName(context, widget.feature)),
              leading: BackButton(
                onPressed: () =>
                    _handlePremiumRouteBack(context, returnToDashboard: false),
              ),
            ),
            body: Center(child: _retry(context)),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeFocus(
              excluding: ambiguous,
              child: Semantics(
                blockUserActions: ambiguous,
                child: AbsorbPointer(
                  absorbing: ambiguous,
                  child: KeyedSubtree(
                    key: const ValueKey('store-renewal-retained-child'),
                    child: widget.child,
                  ),
                ),
              ),
            ),
            if (ambiguous) ...[
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
                      returnToDashboard: false,
                    ),
                  ),
                ),
              ),
              if (timedOut)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _retry(context),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _retry(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(context.strings.text('Subscription check unavailable')),
      TextButton(
        onPressed: () {
          final hint = _lastObservation;
          if (hint != null) ref.read(storeRenewalRecheckProvider).retry(hint);
        },
        child: Text(context.strings.text('Try again')),
      ),
    ],
  );
}
