import 'package:flutter/material.dart';

class BilReportReasonOption extends StatelessWidget {
  const BilReportReasonOption({
    required this.value,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.tapKey,
    super.key,
  });

  final Key? tapKey;
  final String value;
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected
        ? scheme.primary.withValues(alpha: .58)
        : scheme.outlineVariant.withValues(alpha: .5);
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          key: tapKey ?? Key('report-reason-tap-$value'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: selected
                    ? [
                        scheme.primaryContainer.withValues(alpha: .38),
                        scheme.surface.withValues(alpha: .88),
                      ]
                    : [
                        scheme.surface.withValues(alpha: .76),
                        scheme.surfaceContainerLow.withValues(alpha: .72),
                      ],
              ),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.1 : .8,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? scheme.primaryContainer.withValues(alpha: .64)
                        : scheme.surfaceContainerHighest.withValues(alpha: .68),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: .36),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(selected),
                    size: 22,
                    color: selected
                        ? scheme.primary
                        : scheme.outline.withValues(alpha: .68),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
