part of 'onboarding_page.dart';

final class _StepView {
  const _StepView({
    required this.title,
    required this.subtitle,
    required this.body,
    this.skip,
    this.nextEnabled = true,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final VoidCallback? skip;
  final bool nextEnabled;
}

class _UnitToggleCard extends StatelessWidget {
  const _UnitToggleCard({
    required this.imperial,
    required this.metricLabel,
    required this.metricSubtitle,
    required this.imperialLabel,
    required this.imperialSubtitle,
    required this.semanticLabel,
    required this.onTap,
  });

  final bool imperial;
  final String metricLabel;
  final String metricSubtitle;
  final String imperialLabel;
  final String imperialSubtitle;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = imperial ? imperialLabel : metricLabel;
    final subtitle = imperial ? imperialSubtitle : metricSubtitle;
    return Semantics(
      key: const Key('onboarding-unit-toggle-semantics'),
      button: true,
      toggled: imperial,
      label: semanticLabel,
      value: title,
      hint: imperial ? metricLabel : imperialLabel,
      child: Material(
        color: scheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.primary, width: 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('onboarding-unit-toggle'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 92),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 15, 14, 15),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: Icon(
                        Icons.straighten_rounded,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 160),
                          child: Text(
                            title,
                            key: ValueKey(title),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ExcludeSemantics(
                    child: IgnorePointer(
                      child: Switch.adaptive(
                        value: imperial,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
          ],
        ),
      ),
    );
  }
}

/// Numeric ranges and SI/imperial symbols must retain their left-to-right
/// order inside RTL sentences (for example `20–300 cm`, never `cm 300–20`).
class _UnitRangeHint extends StatelessWidget {
  const _UnitRangeHint(this.value);

  final String value;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        value,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            message,
            style: TextStyle(color: scheme.onErrorContainer),
          ),
        ),
      ),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  const _PlanMetric({
    required this.label,
    required this.value,
    this.prominent = false,
  });
  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: prominent ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: prominent ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              value,
              style:
                  (prominent
                          ? Theme.of(context).textTheme.headlineMedium
                          : Theme.of(context).textTheme.titleLarge)
                      ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
