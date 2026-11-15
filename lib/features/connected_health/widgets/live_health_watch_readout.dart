part of 'live_health_watch.dart';

class _WatchMetricsLayout extends StatelessWidget {
  const _WatchMetricsLayout({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => children.length <= 3
      ? Row(children: children)
      : Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(child: Row(children: children.take(2).toList())),
            const SizedBox(height: 4),
            Expanded(child: Row(children: children.skip(2).toList())),
          ],
        );
}

class _WatchNoRecentReadings extends StatelessWidget {
  const _WatchNoRecentReadings({required this.compact, required this.scale});

  final bool compact;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      connectedHealthNoRecentReadingsText(context),
      key: const Key('watch-no-recent-readings'),
      textAlign: TextAlign.center,
      maxLines: compact ? 3 : 1,
      softWrap: compact,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: const Color(0xFFB7D0DF),
        fontSize: (compact ? 10 : 12) * scale,
        height: 1.2,
        fontWeight: FontWeight.w500,
      ),
    );
    return compact ? text : FittedBox(fit: BoxFit.scaleDown, child: text);
  }
}

class _CompactWatchConnectButton extends StatelessWidget {
  const _CompactWatchConnectButton({
    required this.onPressed,
    required this.semanticLabel,
    this.readingStatus,
  });

  final VoidCallback? onPressed;
  final String semanticLabel;
  final Widget? readingStatus;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('watch-connect-health-semantics'),
    button: true,
    enabled: onPressed != null,
    label: readingStatus == null
        ? semanticLabel
        : '${connectedHealthNoRecentReadingsText(context)}. $semanticLabel',
    child: ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          key: const Key('watch-connect-health-cta'),
          onTap: onPressed,
          radius: 24,
          customBorder: const CircleBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: Container(
                      key: const Key('watch-connect-health-icon-disc'),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: .92),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .20),
                        ),
                      ),
                      child: Icon(
                        Icons.link_rounded,
                        key: const Key('watch-connect-health-icon'),
                        size: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                if (readingStatus != null) Flexible(child: readingStatus!),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _WatchMetricButton extends StatelessWidget {
  const _WatchMetricButton({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    enabled: onTap != null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
      ),
    ),
  );
}

class _WatchMetric extends StatelessWidget {
  const _WatchMetric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.semanticLabel,
    this.compact = false,
    this.scale = 1,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String semanticLabel;
  final bool compact;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semanticLabel, $value $label',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BilNavigationFeedback(
              child: Icon(
                icon,
                color: color,
                size: (compact ? 10 : 16) * scale,
              ),
            ),
            Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontSize: (compact ? 10 : 13) * scale,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFFD9EAF4),
                fontSize: compact ? 8 * scale : null,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
