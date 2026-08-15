import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../composition/dashboard_composition.dart';

class DashboardAnalyticsCenter extends StatelessWidget {
  const DashboardAnalyticsCenter({
    required this.title,
    required this.weightJourney,
    required this.weeklyProgress,
    required this.bodyProfile,
    super.key,
  });

  final String title;
  final Widget weightJourney;
  final Widget weeklyProgress;
  final Widget bodyProfile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = DashboardComposition.analytics(
          viewportWidth: MediaQuery.sizeOf(context).width,
          contentWidth: constraints.maxWidth,
        );
        if (!layout.analyticsHorizontal) {
          final phone = layout.isPhone;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!phone) ...[bodyProfile, const SizedBox(height: 12)],
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 6),
              weightJourney,
              const SizedBox(height: PremiumDesignTokens.spaceSm),
              weeklyProgress,
            ],
          );
        }
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: weightJourney),
              const SizedBox(width: PremiumDesignTokens.spaceMd),
              Expanded(flex: 5, child: weeklyProgress),
              const SizedBox(width: PremiumDesignTokens.spaceMd),
              Expanded(flex: 9, child: bodyProfile),
            ],
          ),
        );
      },
    );
  }
}
