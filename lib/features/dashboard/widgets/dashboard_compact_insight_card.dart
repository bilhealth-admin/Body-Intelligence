import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';

/// Evidence-first insight content embedded inside a parent dashboard surface.
class DashboardCompactInsightCard extends StatelessWidget {
  const DashboardCompactInsightCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.interpretation,
    required this.evidence,
    required this.accent,
    this.onTap,
    this.matchPersonalAiSurface = false,
  });

  final String eyebrow;
  final String title;
  final String interpretation;
  final String evidence;
  final Color accent;
  final VoidCallback? onTap;
  final bool matchPersonalAiSurface;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final copy =
        _compactInsightCopy[Localizations.localeOf(
          context,
        ).languageCode.toLowerCase()] ??
        _compactInsightCopy['en']!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(PremiumDesignTokens.spaceSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow.isNotEmpty) ...[
              Text(
                eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .2,
                ),
              ),
              const SizedBox(height: 5),
            ],
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            _TwinLikeInsightRow(
              icon: Icons.psychology_alt_outlined,
              label: copy['interpretation']!,
              value: interpretation,
              accent: accent,
            ),
            const SizedBox(height: PremiumDesignTokens.spaceXs),
            _TwinLikeInsightRow(
              icon: Icons.fact_check_outlined,
              label: copy['evidence']!,
              value: evidence,
              accent: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

const _compactInsightCopy = <String, Map<String, String>>{
  'ar': {'interpretation': 'التفسير', 'evidence': 'الدليل'},
  'en': {'interpretation': 'Interpretation', 'evidence': 'Evidence'},
  'fr': {'interpretation': 'Interprétation', 'evidence': 'Preuve'},
  'es': {'interpretation': 'Interpretación', 'evidence': 'Evidencia'},
  'tr': {'interpretation': 'Yorum', 'evidence': 'Kanıt'},
};

class _TwinLikeInsightRow extends StatelessWidget {
  const _TwinLikeInsightRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
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
