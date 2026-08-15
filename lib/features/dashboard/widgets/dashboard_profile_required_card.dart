import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Column(
    key: const Key('dashboard-unprofiled-overview'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (hero != null) ...[hero!, const SizedBox(height: 16)],
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('dashboard-complete-profile-action'),
                onPressed: onAction,
                icon: const Icon(Icons.person_outline_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _EmptyMetricCard(
            key: Key('dashboard-empty-calories-card'),
            icon: Icons.local_fire_department_outlined,
            label: 'Calories',
          ),
          _EmptyMetricCard(
            key: Key('dashboard-empty-steps-card'),
            icon: Icons.directions_walk_rounded,
            label: 'Steps',
          ),
        ],
      ),
    ],
  );
}

class _EmptyMetricCard extends StatelessWidget {
  const _EmptyMetricCard({required this.icon, required this.label, super.key});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Card(
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
