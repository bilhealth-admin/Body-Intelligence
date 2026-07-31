import 'package:flutter/material.dart';

import '../../app/theme/premium_design_tokens.dart';
import 'premium_surface.dart';

class PremiumChartCard extends StatelessWidget {
  const PremiumChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.chart,
    required this.explanation,
    this.footer,
    this.semanticLabel,
  });

  final String title;
  final String subtitle;
  final Widget chart;
  final List<String> explanation;
  final Widget? footer;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: PremiumSurface(
        padding: PremiumDesignTokens.cardPaddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: rtl ? TextAlign.right : TextAlign.left,
                style: PremiumDesignTokens.cardHeading(context),
              ),
            ),
            const SizedBox(height: PremiumDesignTokens.spaceXs),
            Text(
              subtitle,
              textAlign: rtl ? TextAlign.right : TextAlign.left,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: PremiumDesignTokens.spaceMd),
            chart,
            const SizedBox(height: PremiumDesignTokens.spaceMd),
            ...explanation.map(
              (line) => Padding(
                padding: const EdgeInsets.only(
                  bottom: PremiumDesignTokens.spaceXs,
                ),
                child: Text(
                  line,
                  textAlign: rtl ? TextAlign.right : TextAlign.left,
                ),
              ),
            ),
            if (footer != null) ...[
              const SizedBox(height: PremiumDesignTokens.spaceSm),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
