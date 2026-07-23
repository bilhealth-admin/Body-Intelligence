import 'package:flutter/material.dart';

import 'paywall_plan_view_model.dart';
import 'paywall_state.dart';

/// Commerce-owned paywall shell with no store or cloud integration.
class CommercePaywall extends StatelessWidget {
  const CommercePaywall({
    required this.state,
    required this.onPlanSelected,
    required this.onContinue,
    required this.onRestore,
    super.key,
  });

  final PaywallState state;
  final ValueChanged<String> onPlanSelected;
  final VoidCallback onContinue;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedPlanId;
    return Semantics(
      container: true,
      label: 'BIL subscription plans',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final content = state.plans
              .map(
                (plan) => _PlanCard(
                  plan: plan,
                  selected: selected == plan.plan.name,
                  enabled: !state.isBusy,
                  onTap: () => onPlanSelected(plan.plan.name),
                ),
              )
              .toList(growable: false);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose your BIL plan',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your current access is always resolved from entitlements, not from the plan label shown here.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (wide)
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: content
                        .map((card) => SizedBox(width: 300, child: card))
                        .toList(),
                  )
                else
                  ...content.expand(
                    (card) => [card, const SizedBox(height: 12)],
                  ),
                if (state.message != null) ...[
                  const SizedBox(height: 16),
                  Semantics(liveRegion: true, child: Text(state.message!)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.isBusy || selected == null
                      ? null
                      : onContinue,
                  child: Text(state.isPurchasing ? 'Processing…' : 'Continue'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: state.isBusy ? null : onRestore,
                  child: Text(
                    state.isRestoring ? 'Restoring…' : 'Restore purchases',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final PaywallPlanViewModel plan;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectable = enabled && plan.canSelect;
    return Semantics(
      button: true,
      selected: selected,
      enabled: selectable,
      label: '${plan.title}, ${plan.priceLabel} ${plan.billingPeriodLabel}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selectable ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (plan.isRecommended)
                      const Chip(label: Text('Recommended')),
                  ],
                ),
                const SizedBox(height: 6),
                Text(plan.subtitle),
                const SizedBox(height: 16),
                Text(
                  plan.priceLabel,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(plan.billingPeriodLabel),
                const SizedBox(height: 16),
                for (final item in plan.highlights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
                if (!plan.isEligible)
                  Text(
                    plan.ineligibilityReason!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (plan.isCurrent) const Text('Current plan'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
