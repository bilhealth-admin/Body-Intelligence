part of 'premium_route_glass_gate.dart';

class _PremiumRouteAccessChecking extends StatelessWidget {
  const _PremiumRouteAccessChecking({
    required this.isDark,
    required this.returnToDashboard,
    required this.title,
  });

  final bool isDark;
  final bool returnToDashboard;
  final String title;

  @override
  Widget build(BuildContext context) => _PremiumRoutePageFrame(
    title: title,
    returnToDashboard: returnToDashboard,
    backKey: const ValueKey('premium-route-loading-back'),
    child: const Center(
      child: SizedBox.square(
        key: ValueKey('premium-route-access-checking'),
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );
}

class _PremiumRoutePageFrame extends StatelessWidget {
  const _PremiumRoutePageFrame({
    required this.title,
    required this.child,
    required this.returnToDashboard,
    this.backKey = const ValueKey('premium-route-back'),
  });
  final String title;
  final Widget child;
  final bool returnToDashboard;
  final Key backKey;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: BilPearlFinish.background(context)),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  key: backKey,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => _handlePremiumRouteBack(
                    context,
                    returnToDashboard: returnToDashboard,
                  ),
                  icon: const BackButtonIcon(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    key: const Key('premium-route-public-title'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class _BenefitPill extends StatelessWidget {
  const _BenefitPill({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: const Color(0x20FFFFFF)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Icon(
          Icons.check_rounded,
          size: 15,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            softWrap: true,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark ? const Color(0xFFF1F1F1) : const Color(0xFF272117),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _GoldActionButton extends StatelessWidget {
  const _GoldActionButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    key: const ValueKey('premium-route-upgrade-cta'),
    onPressed: loading ? null : onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    child: loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
  );
}
