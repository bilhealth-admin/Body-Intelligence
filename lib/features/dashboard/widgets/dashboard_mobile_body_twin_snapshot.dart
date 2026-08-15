import 'package:flutter/material.dart';

import '../dashboard_five_locale_copy.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';

/// Compact Body Twin snapshot used by the phone dashboard composition.
class DashboardMobileBodyTwinSnapshot extends StatelessWidget {
  const DashboardMobileBodyTwinSnapshot({
    super.key,
    required this.arabic,
    required this.summary,
    required this.evidence,
    required this.trendSummary,
    required this.trendEvidence,
  });

  final bool arabic;
  final String summary;
  final String evidence;
  final String trendSummary;
  final String trendEvidence;

  String tr(String en, String ar) => dashboardFiveLocaleText(en, ar);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumSurface(
      key: const Key('dashboard-mobile-body-twin-snapshot'),
      level: PremiumSurfaceLevel.detail,
      padding: PremiumDesignTokens.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer,
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: .36),
                  ),
                ),
                child: Icon(
                  Icons.accessibility_new_rounded,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: PremiumDesignTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('BODY TWIN', 'توأم الجسم'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr('Your current body state', 'حالة جسمك الحالية'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceMd),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          _TwinSignalRow(
            icon: Icons.timeline_rounded,
            label: tr('What changed', 'ما الذي تغيّر'),
            value: trendSummary,
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          _TwinSignalRow(
            icon: Icons.science_outlined,
            label: tr('Model evidence', 'أدلة النموذج'),
            value: evidence,
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          _TwinSignalRow(
            icon: Icons.fact_check_outlined,
            label: tr('Trend evidence', 'أدلة الاتجاه'),
            value: trendEvidence,
          ),
        ],
      ),
    );
  }
}

class _TwinSignalRow extends StatelessWidget {
  const _TwinSignalRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: PremiumDesignTokens.spaceSm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label · ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
