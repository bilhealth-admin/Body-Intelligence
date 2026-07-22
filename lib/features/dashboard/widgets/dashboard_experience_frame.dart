import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';

class DashboardExperienceFrame extends StatelessWidget {
  const DashboardExperienceFrame({
    super.key,
    required this.arabic,
    required this.child,
  });

  final bool arabic;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: arabic
          ? 'أولويات اليوم ثم التفاصيل الداعمة'
          : 'Today priorities followed by supporting detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              arabic ? 'يومك حسب الأولوية' : 'Your day, in priority order',
              key: const Key('dashboard-priority-heading'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFFF4F8FB),
                fontWeight: FontWeight.w900,
                letterSpacing: -.3,
              ),
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Text(
            arabic
                ? 'ابدأ بالإجراء الأهم، ثم راجع الأرقام والتفسير عندما تحتاجهما.'
                : 'Start with the most useful action, then review numbers and evidence when needed.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFCAE0E8),
              height: 1.45,
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceMd),
          child,
        ],
      ),
    );
  }
}
