part of 'premium_route_glass_gate.dart';

final class _PremiumGateContent {
  const _PremiumGateContent({
    required this.title,
    required this.body,
    required this.benefits,
  });

  final String title;
  final String body;
  final List<String> benefits;
}

class _PremiumGateCard extends StatelessWidget {
  const _PremiumGateCard({
    required this.tier,
    required this.title,
    required this.body,
    required this.benefits,
    required this.action,
    required this.secondaryAction,
    required this.loading,
    required this.compact,
    required this.isDark,
    required this.showCoach,
    required this.onPressed,
    required this.onSecondaryPressed,
  });

  final String tier;
  final String title;
  final String body;
  final List<String> benefits;
  final String action;
  final String? secondaryAction;
  final bool loading;
  final bool compact;
  final bool isDark;
  final bool showCoach;
  final VoidCallback? onPressed;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 390),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .97),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? .22 : .12),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 22 : 26,
              compact ? 22 : 27,
              compact ? 22 : 26,
              compact ? 20 : 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (showCoach)
                      Container(
                        width: compact ? 54 : 60,
                        height: compact ? 54 : 60,
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFC8F3FF),
                          shape: BoxShape.circle,
                        ),
                        child: const ClipOval(child: BilCoachPortrait()),
                      )
                    else
                      PremiumCrownEmblem(size: compact ? 54 : 60),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tier,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF17130B),
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 16 : 20),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? const Color(0xFFE4E4E4)
                        : const Color(0xFF3A352B),
                    height: 1.55,
                  ),
                ),
                SizedBox(height: compact ? 14 : 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final benefit in benefits)
                      _BenefitPill(label: benefit, isDark: isDark),
                  ],
                ),
                SizedBox(height: compact ? 18 : 24),
                _GoldActionButton(
                  label: action,
                  loading: loading,
                  onPressed: onPressed,
                ),
                if (secondaryAction != null && onSecondaryPressed != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onSecondaryPressed,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: const Color(0xFFFFDB78),
                      side: const BorderSide(color: Color(0x66F5D477)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    icon: const Icon(Icons.bolt_rounded, size: 20),
                    label: Text(secondaryAction!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
