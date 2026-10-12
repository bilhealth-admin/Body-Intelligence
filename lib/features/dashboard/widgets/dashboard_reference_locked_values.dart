part of 'premium_dashboard_benchmark.dart';

/// The subscribed Home tree is returned unchanged. Only Free/Checking cards
/// separate public names from paid pixels; no watch/navigation redesign.
class _ReferenceLockedValuesCard extends StatelessWidget {
  const _ReferenceLockedValuesCard({
    required this.locked,
    required this.checking,
    required this.title,
    required this.detail,
    required this.child,
    required this.onTap,
    this.onRetry,
    super.key,
  });

  final bool locked;
  final bool checking;
  final String title;
  final String detail;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!locked && !checking && onRetry == null) return child;
    final macros = child is _ReferenceMacrosCard
        ? (child as _ReferenceMacrosCard).macros
        : (child as _CircularNutrientCard).rings.cast<_MacroProgress>();
    final edit = child is _ReferenceMacrosCard
        ? (child as _ReferenceMacrosCard).onEdit
        : null;
    return _ReferenceCard(
      child: SingleChildScrollView(
        child: Column(
          key: Key(
            edit != null
                ? 'dashboard-reference-macros-card'
                : 'dashboard-heart-circle-card',
          ),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    key: Key(
                      edit != null
                          ? 'dashboard-macros-public-title'
                          : 'dashboard-heart-public-title',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (edit != null)
                  IconButton(
                    key: const Key('dashboard-reference-macros-edit'),
                    tooltip: _referenceText(
                      context,
                      'Edit goal',
                      'تعديل الهدف',
                    ),
                    onPressed: edit,
                    icon: const BilGlassPressFeedback(
                      child: Icon(Icons.swap_horiz_rounded, size: 20),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final macro in macros)
                  Text(
                    '${macro.label} · ${macro.unit}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            PremiumDashboardCardLock(
              key: Key(
                edit != null
                    ? 'dashboard-macros-paid-values'
                    : 'dashboard-heart-paid-values',
              ),
              locked: locked,
              checking: checking,
              onRetry: onRetry,
              title: title,
              detail: detail,
              borderRadius: 12,
              onTap: onTap,
              child: const SizedBox(height: 78),
            ),
          ],
        ),
      ),
    );
  }
}
