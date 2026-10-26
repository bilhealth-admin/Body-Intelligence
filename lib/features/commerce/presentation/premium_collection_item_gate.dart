import '../../../shared/widgets/bil_pearl_feature_welcome.dart';
import '../../../shared/widgets/bil_navigation_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_localizations.dart';
import '../domain/subscription_state.dart';
import '../providers/commerce_providers.dart';
import 'premium_label_badge.dart';

/// Collection previews contain public metadata only. Callers separately guard
/// paid values and never load paid payloads to build this preview.
class PremiumCollectionItemGate extends ConsumerWidget {
  const PremiumCollectionItemGate({
    required this.locked,
    required this.tier,
    required this.onUpgrade,
    required this.child,
    this.showLabel = true,
    super.key,
  });
  final bool locked;
  final String tier;
  final VoidCallback onUpgrade;
  final Widget child;
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!locked) return child;
    final access = ref.watch(verifiedSubscriptionAccessProvider);
    final checking = access.isLoading;
    final verified =
        access.asData?.value.authority == EntitlementAuthority.verifiedServer;
    final unavailable = !checking && !verified;
    final upgrade =
        Localizations.of<AppLocalizations>(
          context,
          AppLocalizations,
        )?.text('Upgrade') ??
        'Upgrade';
    // Reserve the action through layout instead of painting it over a
    // public name. Wrapped titles and enlarged text must remain separate from
    // both the pointer target and the paid-value masks inside the preview.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          key: const ValueKey('premium-collection-preview'),
          child: ExcludeFocus(child: AbsorbPointer(child: child)),
        ),
        Align(
          key: const ValueKey('premium-collection-action-region'),
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Tooltip(
              message: checking
                  ? context.strings.text('Checking subscription')
                  : unavailable
                  ? context.strings.text('Subscription check unavailable')
                  : upgrade,
              child: Semantics(
                button: !checking,
                label: checking
                    ? context.strings.text('Checking subscription')
                    : unavailable
                    ? context.strings.text('Retry')
                    : '$upgrade · $tier',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('premium-collection-upgrade'),
                    onTap: checking
                        ? null
                        : unavailable
                        ? () =>
                              ref.invalidate(verifiedSubscriptionStateProvider)
                        : onUpgrade,
                    borderRadius: BorderRadius.circular(18),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        minWidth: 48,
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: checking
                            ? const SizedBox.square(
                                dimension: 24,
                                child: BilFeatureWelcomeStatus(),
                              )
                            : unavailable
                            ? const BilNavigationFeedback(
                                child: Icon(Icons.refresh_rounded),
                              )
                            : showLabel
                            ? PremiumLabelBadge(semanticLabel: tier)
                            : Text(
                                upgrade,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
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
    );
  }
}
