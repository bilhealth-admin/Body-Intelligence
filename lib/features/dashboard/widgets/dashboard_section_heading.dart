import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';

class DashboardSectionHeading extends StatelessWidget {
  const DashboardSectionHeading({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Semantics(
      header: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: TextAlign.start,
            key: const Key('dashboard-today-summary-title'),
            style: theme.textTheme.titleLarge?.copyWith(
              color: dark ? const Color(0xFFF4F8FB) : const Color(0xFF10283B),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.15,
              height: 1.12,
              shadows: dark
                  ? const [
                      Shadow(
                        color: Color(0x80000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : const [],
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Text(
            subtitle,
            textAlign: TextAlign.start,
            key: const Key('dashboard-today-summary-subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: dark ? const Color(0xFFCAE0E8) : const Color(0xFF526B7C),
              fontWeight: FontWeight.w600,
              height: 1.45,
              shadows: dark
                  ? const [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : const [],
            ),
          ),
        ],
      ),
    );
  }
}
