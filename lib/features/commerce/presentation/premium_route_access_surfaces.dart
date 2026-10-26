part of 'premium_route_glass_gate.dart';

class _PremiumRouteAccessUnavailable extends StatelessWidget {
  const _PremiumRouteAccessUnavailable({
    required this.child,
    required this.isDark,
    required this.returnToDashboard,
    required this.onRetry,
    required this.title,
  });

  final Widget child;
  final bool isDark;
  final bool returnToDashboard;
  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PremiumRoutePageFrame(
      title: title,
      returnToDashboard: returnToDashboard,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: BilPearlMaterialCard(
            key: const ValueKey('premium-route-access-unavailable'),
            elevation: 0,
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BilNavigationFeedback(
                      child: Icon(
                        Icons.sync_problem_rounded,
                        size: 42,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.strings.text('Unavailable'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.strings.text('Subscription check unavailable'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      key: const ValueKey('premium-route-access-retry'),
                      onPressed: onRetry,
                      icon: const BilNavigationFeedback(
                        child: Icon(Icons.refresh_rounded),
                      ),
                      label: Text(context.strings.text('Try again')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _featureName(BuildContext context, PremiumGateFeature feature) =>
    context.strings.text(switch (feature) {
      PremiumGateFeature.premium => 'Premium',
      PremiumGateFeature.aiCoach => 'AI Coach',
      PremiumGateFeature.decisionMemory => 'Memory',
      PremiumGateFeature.personalPlan => 'Personal plan',
      PremiumGateFeature.experiments => 'Experiments',
      PremiumGateFeature.bodyMeasurements => 'Body measurements',
      PremiumGateFeature.nutritionPrograms => 'Nutrition Programs',
      PremiumGateFeature.weeklyReport => 'Weekly report',
      PremiumGateFeature.nutritionAnalytics => 'Nutrition analytics',
      PremiumGateFeature.workoutLibrary => 'Workout library',
      PremiumGateFeature.recipeLibrary => 'Recipe library',
      PremiumGateFeature.recipeImport => 'Import recipe',
      PremiumGateFeature.mealPlanner => 'Meal planner',
      PremiumGateFeature.contentPacks => 'Content packs',
      PremiumGateFeature.fasting => 'Fasting',
      PremiumGateFeature.sleep => 'Sleep',
      PremiumGateFeature.community => 'Community',
    });
