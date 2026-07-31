import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';

class NutritionProgressCard extends StatelessWidget {
  const NutritionProgressCard({
    super.key,
    required this.label,
    required this.consumed,
    required this.target,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String label;
  final double consumed;
  final double target;
  final String unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final difference = target - consumed;
    final remaining = difference.clamp(0, target);
    final progress = target <= 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);
    final exceeded = difference < 0;
    final summary = exceeded
        ? '${difference.abs().round()} $unit ${context.strings.text('above target reference')}'
        : '${remaining.round()} $unit ${context.strings.text('remaining')}';
    return Semantics(
      label:
          '$label: ${consumed.round()} $unit ${context.strings.text('consumed')}, ${target.round()} $unit ${context.strings.text('target')}, $summary',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withValues(alpha: 0.14),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${consumed.round()} / ${target.round()} $unit',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                color: color,
                backgroundColor: color.withValues(alpha: 0.14),
              ),
              const SizedBox(height: 6),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
