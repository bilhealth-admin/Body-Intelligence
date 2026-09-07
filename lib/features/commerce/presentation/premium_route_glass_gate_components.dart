part of 'premium_route_glass_gate.dart';

class _PremiumRouteAccessChecking extends StatelessWidget {
  const _PremiumRouteAccessChecking({
    required this.isDark,
    required this.returnToDashboard,
  });

  final bool isDark;
  final bool returnToDashboard;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ColoredBox(
        color: isDark ? const Color(0xFF071923) : const Color(0xFFF7F8FA),
        child: const Center(
          child: SizedBox.square(
            key: ValueKey('premium-route-access-checking'),
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
      SafeArea(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IconButton(
              key: const ValueKey('premium-route-loading-back'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => _handlePremiumRouteBack(
                context,
                returnToDashboard: returnToDashboard,
              ),
              style: IconButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0x99141414)
                    : const Color(0xB8FFFFFF),
                foregroundColor: isDark ? Colors.white : Colors.black87,
              ),
              icon: const BackButtonIcon(),
            ),
          ),
        ),
      ),
    ],
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
      color: isDark ? const Color(0x1FFFFFFF) : const Color(0x24000000),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: const Color(0x20FFFFFF)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        const Icon(Icons.check_rounded, size: 15, color: Color(0xFFFFDA77)),
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
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFE89E), Color(0xFFF5C654), Color(0xFFD99B26)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55E9B33C),
          blurRadius: 22,
          offset: Offset(0, 9),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('premium-route-upgrade-cta'),
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 54,
          child: Center(
            child: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF07121E),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xFF08131F),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: Color(0xFF08131F),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}
