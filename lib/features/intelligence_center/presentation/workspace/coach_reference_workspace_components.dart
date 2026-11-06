part of 'coach_reference_workspace.dart';

String _water(Map<String, Object?> row) {
  final amount = row['amountMl'];
  return amount is num && amount.isFinite && amount >= 0 ? '$amount ml' : '—';
}

String _steps(Map<String, Object?> row, BuildContext context) {
  final amount = row['steps'];
  return amount is num && amount.isFinite && amount >= 0
      ? '$amount ${intelligenceText(context, 'steps', 'خطوات')}'
      : '—';
}

/// Reserve the translated, scaled badge height even before verification.
/// A missing/expired badge has no hidden label or semantics, but cannot move
/// the tabs and diary cards while its authority is refreshing.
class _CoachAccessLabelSlot extends StatelessWidget {
  const _CoachAccessLabelSlot({
    required this.visible,
    required this.labels,
    required this.child,
  });
  final bool visible;
  final List<String> labels;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = DefaultTextStyle.of(
        context,
      ).style.merge(const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));
      var textHeight = 0.0;
      for (final label in labels) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.localeOf(context),
        );
        painter.layout(
          maxWidth: (constraints.maxWidth - 20).clamp(1.0, double.infinity),
        );
        if (painter.height > textHeight) textHeight = painter.height;
        painter.dispose();
      }
      return SizedBox(
        height: textHeight + 10,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: visible ? child : const SizedBox.shrink(),
        ),
      );
    },
  );
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BilPearlFinish.panel(context),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

Color _workspaceAccent(BuildContext context, Color accent) =>
    Theme.of(context).brightness == Brightness.dark
    ? Color.lerp(accent, Theme.of(context).colorScheme.onSurface, .60)!
    : HSLColor.fromColor(accent).withLightness(.24).toColor();

class _NutrientTile extends StatelessWidget {
  const _NutrientTile({
    required this.label,
    required this.amount,
    required this.target,
    required this.accent,
    required this.progress,
    required this.locked,
    required this.onTap,
  });
  final String label, amount, target;
  final Color accent;
  final double progress;
  final bool locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _WorkspaceCard(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _workspaceAccent(context, accent),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (locked)
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '$amount / $target',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: BilStripedProgress(
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String label, detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: BilNavigationFeedback(
              child: Icon(
                icon,
                size: 17,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const BilNavigationFeedback(
            child: Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: Color(0xFF9DACC0),
            ),
          ),
        ],
      ),
    ),
  );
}
