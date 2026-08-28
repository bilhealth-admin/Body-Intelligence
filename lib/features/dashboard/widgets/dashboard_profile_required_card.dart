import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';

class DashboardProfileRequiredCard extends StatelessWidget {
  const DashboardProfileRequiredCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.hero,
    super.key,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget? hero;

  @override
  Widget build(BuildContext context) {
    final strings = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Column(
      key: const Key('dashboard-unprofiled-overview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hero != null) ...[hero!, const SizedBox(height: 16)],
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('dashboard-complete-profile-action'),
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.person_outline_rounded),
                  label: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _EmptyMetricCard(
              key: const Key('dashboard-empty-calories-card'),
              icon: Icons.local_fire_department_outlined,
              label: strings?.text('Calories') ?? 'Calories',
            ),
            _EmptyMetricCard(
              key: const Key('dashboard-empty-steps-card'),
              icon: Icons.directions_walk_rounded,
              label: strings?.text('Steps') ?? 'Steps',
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyMetricCard extends StatelessWidget {
  const _EmptyMetricCard({required this.icon, required this.label, super.key});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text('—', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    ),
  );
}
