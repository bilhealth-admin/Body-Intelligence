import 'package:flutter/material.dart';

import '../../app/theme/bil_flagship_tokens.dart';
import '../../app/theme/bil_spacing.dart';
import 'bil_card.dart';

enum BilMetricTrend { up, down, neutral }

enum BilMetricStatus { info, success, warning, danger }

class BilMetricCard extends StatelessWidget {
  const BilMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    this.subtitle,
    this.icon,
    this.trend = BilMetricTrend.neutral,
    this.status = BilMetricStatus.info,
    this.onTap,
  });

  final String title;
  final String value;
  final String? unit;
  final String? subtitle;
  final IconData? icon;
  final BilMetricTrend trend;
  final BilMetricStatus status;
  final VoidCallback? onTap;

  Color get _accent {
    switch (status) {
      case BilMetricStatus.success:
        return BilFlagshipTokens.emerald400;
      case BilMetricStatus.warning:
        return Colors.amber;
      case BilMetricStatus.danger:
        return Colors.redAccent;
      case BilMetricStatus.info:
        return BilFlagshipTokens.cyan400;
    }
  }

  IconData get _trendIcon {
    switch (trend) {
      case BilMetricTrend.up:
        return Icons.trending_up_rounded;
      case BilMetricTrend.down:
        return Icons.trending_down_rounded;
      case BilMetricTrend.neutral:
        return Icons.trending_flat_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BilCard(
      variant: BilCardVariant.glass,
      onTap: onTap,
      semanticLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, color: _accent, size: 22),
              if (icon != null) const SizedBox(width: BilSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Icon(_trendIcon, color: _accent, size: 20),
            ],
          ),
          const SizedBox(height: BilSpacing.lg),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white70),
                  ),
              ],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: BilSpacing.sm),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}
