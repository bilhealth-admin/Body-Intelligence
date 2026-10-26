import '../../../shared/widgets/bil_pearl_feature_welcome.dart';
import '../../../shared/widgets/bil_navigation_feedback.dart';
import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import 'premium_label_badge.dart';

/// Masks only the paid value region. Headings, units, sources and free actions
/// belong outside this widget. Private pixels are never painted as a preview.
class PremiumValueMask extends StatelessWidget {
  const PremiumValueMask({
    required this.child,
    required this.locked,
    this.checking = false,
    this.onUpgrade,
    this.onRetry,
    this.showLabel = true,
    this.compact = false,
    this.borderRadius = 16,
    this.reserveSpace = true,
    this.actionKey,
    this.statusKey,
    super.key,
  });

  final Widget child;
  final bool locked;
  final bool checking;
  final VoidCallback? onUpgrade;
  final VoidCallback? onRetry;
  final bool showLabel;
  final bool compact;
  final double borderRadius;
  final bool reserveSpace;
  final Key? actionKey;
  final Key? statusKey;

  @override
  Widget build(BuildContext context) {
    final concealed = locked || checking || onRetry != null;
    final scheme = Theme.of(context).colorScheme;
    final strings = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    String text(String value) => strings?.text(value) ?? value;
    final label = checking
        ? text('Checking subscription')
        : onRetry != null
        ? text('Subscription check unavailable')
        : text('Premium');
    Widget size(Widget value) => reserveSpace
        ? ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 48 : 56),
            child: value,
          )
        : value;
    if (!concealed) return size(child);
    final action = checking ? null : onRetry ?? onUpgrade;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Opacity zero preserves layout without revealing numbers, chart
          // geometry, tooltips, selectable text or stale account content.
          ExcludeFocus(
            child: ExcludeSemantics(
              child: SelectionContainer.disabled(
                child: TooltipVisibility(
                  visible: false,
                  child: IgnorePointer(
                    child: Opacity(opacity: 0, child: size(child)),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              key: statusKey,
              decoration: BoxDecoration(
                // Opaque separation also protects values with reduced
                // transparency/high contrast and avoids repeated blur layers.
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.surface, scheme.surfaceContainerLow],
                ),
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Center(
                child: Semantics(
                  container: true,
                  liveRegion: checking || onRetry != null,
                  label: label,
                  child: checking
                      ? const SizedBox.square(
                          dimension: 22,
                          child: BilFeatureWelcomeStatus(),
                        )
                      : Tooltip(
                          message: onRetry != null ? text('Retry') : label,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: actionKey,
                              onTap: action,
                              borderRadius: BorderRadius.circular(borderRadius),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: onRetry != null || !showLabel
                                    ? SizedBox.square(
                                        dimension: 36,
                                        child: BilNavigationFeedback(
                                          child: Icon(
                                            onRetry != null
                                                ? Icons.refresh_rounded
                                                : Icons.lock_outline_rounded,
                                            size: 20,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    : PremiumLabelBadge(
                                        large: !compact,
                                        semanticLabel: label,
                                      ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
