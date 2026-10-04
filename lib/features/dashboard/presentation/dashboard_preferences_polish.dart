part of 'dashboard_preferences_page.dart';

class _DashboardPreferencesHero extends StatelessWidget {
  const _DashboardPreferencesHero({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: dark
              ? const [Color(0xFF102D3C), Color(0xFF0A1218)]
              : [
                  const Color(0xFF64D8FF).withValues(alpha: .16),
                  const Color(0xFF7568FF).withValues(alpha: .09),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF64D8FF).withValues(alpha: dark ? .24 : .28),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3C75FF).withValues(alpha: dark ? .12 : .08),
            blurRadius: 24,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DashboardLuxeIconBadge(
              kind: BilSemanticIconKind.preferences,
              active: true,
              size: 48,
              iconSize: 23,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLuxeIconBadge extends StatelessWidget {
  const _DashboardLuxeIconBadge({
    required this.kind,
    this.active = false,
    this.size = 42,
    this.iconSize = 21,
  });

  final BilSemanticIconKind kind;
  final bool active;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = BilSemanticIcons.spec(kind);
    final accent = spec.accent(theme.brightness);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: active ? .30 : .18),
            accent.withValues(alpha: active ? .12 : .06),
          ],
        ),
        borderRadius: BorderRadius.circular(size * .31),
        border: Border.all(color: accent.withValues(alpha: active ? .48 : .25)),
        boxShadow: active
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: .20),
                  blurRadius: 15,
                  spreadRadius: -7,
                ),
              ]
            : const [],
      ),
      child: BilSemanticIconBadge(
        kind: kind,
        size: size - 6,
        iconSize: iconSize,
      ),
    );
  }
}

class _DashboardPreferenceSurface extends StatelessWidget {
  const _DashboardPreferenceSurface({
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: active
            ? LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  scheme.primaryContainer.withValues(alpha: .42),
                  scheme.surfaceContainerLow,
                ],
              )
            : null,
        border: Border.all(
          color: active
              ? scheme.primary.withValues(alpha: .30)
              : Colors.transparent,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
