import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../domain/commerce_entitlement.dart';
import '../domain/commerce_plan.dart';
import '../domain/subscription_lifecycle.dart';
import '../domain/subscription_state.dart';
import '../providers/commerce_providers.dart';
import 'premium_crown_emblem.dart';

enum PremiumGateFeature {
  premium,
  aiCoach,
  decisionMemory,
  personalPlan,
  experiments,
  bodyMeasurements,
  nutritionPrograms,
  weeklyReport,
  nutritionAnalytics,
  workoutLibrary,
  recipeLibrary,
  recipeImport,
  mealPlanner,
  contentPacks,
  fasting,
  sleep,
  community,
}

/// Lets people inspect a paid route while preventing interaction until a
/// server-verified entitlement is active.
class PremiumRouteGlassGate extends ConsumerWidget {
  const PremiumRouteGlassGate({
    required this.feature,
    required this.child,
    super.key,
  });

  final PremiumGateFeature feature;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(verifiedSubscriptionStateProvider);
    final storefrontPlan = ref.watch(storefrontTargetPlanProvider).value;
    final state = subscription.value;
    final isAiCoach = feature == PremiumGateFeature.aiCoach;
    final isNutritionPrograms = feature == PremiumGateFeature.nutritionPrograms;
    final creditAccess = isAiCoach
        ? ref.watch(aiCoachCreditAccessProvider).value ?? false
        : false;
    final isVerifiedTrial = state?.lifecycle == SubscriptionLifecycle.trial;
    final hasAccess = isAiCoach
        ? creditAccess ||
              (!isVerifiedTrial && state?.plan == CommercePlan.premiumAiCoach)
        : isNutritionPrograms
        ? state?.authority == EntitlementAuthority.verifiedServer &&
              (state?.grants(CommerceEntitlement.premiumPrograms) ?? false)
        : state != null && state.plan != CommercePlan.free;
    if (hasAccess) return child;

    final loading = subscription.isLoading;
    final content = _contentFor(context, feature);
    // The glass names the only subscription family exposed by the verified
    // billing storefront. Unknown storefronts fail closed to Premium; an
    // underpriced AI-inclusive membership is never advertised by locale/IP.
    final tier = storefrontPlan == CommercePlan.premiumAiCoach
        ? 'BIL PREMIUM AI COACH'
        : 'BIL PREMIUM';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        KeyedSubtree(
          key: const ValueKey('premium-route-protected-content'),
          child: AbsorbPointer(
            absorbing: true,
            child: ExcludeSemantics(child: child),
          ),
        ),
        Positioned.fill(child: _PremiumRouteGlassVeil(isDark: isDark)),
        SafeArea(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/dashboard'),
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0x99141414)
                      : const Color(0xB8FFFFFF),
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  side: const BorderSide(color: Color(0x66E3B94F)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 21),
              ),
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 700;
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, compact ? 58 : 76, 20, 20),
                  child: _PremiumGateCard(
                    tier: tier,
                    title: content.title,
                    body: content.body,
                    benefits: content.benefits,
                    action: content.action,
                    secondaryAction: null,
                    loading: loading,
                    compact: compact,
                    isDark: isDark,
                    onPressed: () => context.push(
                      isAiCoach
                          ? '/plans?focus=boost'
                          : '/plans?focus=subscription',
                    ),
                    onSecondaryPressed: null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The route remains painted beneath this layer. BackdropFilter samples those
/// pixels to create actual glass; it does not replace the protected page with
/// a grey placeholder.
class _PremiumRouteGlassVeil extends StatelessWidget {
  const _PremiumRouteGlassVeil({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(26),
    child: BackdropFilter(
      key: const ValueKey('premium-route-glass-blur'),
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: DecoratedBox(
        key: const ValueKey('premium-route-glass-veil'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0x78E3B94F), width: 1.1),
          color: isDark ? const Color(0x1A000000) : const Color(0x24FFFFFF),
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

_PremiumGateContent _contentFor(
  BuildContext context,
  PremiumGateFeature feature,
) {
  String t(String source) => context.strings.text(source);

  if (feature == PremiumGateFeature.aiCoach) {
    return _PremiumGateContent(
      title: t('Your AI Coach builds the plan with you'),
      body: t(
        'Buy AI Boost once to unlock coaching with 2,500 verified, non-expiring tokens.',
      ),
      benefits: [
        t('A diet matched to your calories and macros'),
        t('Training matched to your goal and progress'),
        t('Follow-up from the body data you log'),
        t('Ready · speak any language'),
        t('2,500 non-expiring AI Boost tokens'),
      ],
      action: t('Get AI Boost'),
    );
  }

  final details = switch (feature) {
    PremiumGateFeature.decisionMemory => (
      t('Coaching memory that stays useful'),
      t(
        'Review the goals, preferences, and past decisions BIL remembers for future coaching.',
      ),
      [
        t('Goal and preference memory'),
        t('Decision history with explanations'),
      ],
    ),
    PremiumGateFeature.personalPlan => (
      t('A plan built around your body'),
      t(
        'Turn your calorie target, macros, activity, and progress into one practical plan.',
      ),
      [
        t('Personal calorie and macro targets'),
        t('A plan that adapts as you progress'),
      ],
    ),
    PremiumGateFeature.experiments => (
      t('Guided body experiments'),
      t(
        'Test one change at a time and compare trusted measurements before drawing a conclusion.',
      ),
      [t('Structured experiments'), t('Evidence-based comparisons')],
    ),
    PremiumGateFeature.bodyMeasurements => (
      t('Advanced body measurements'),
      t(
        'Track detailed measurements and understand how your body composition changes over time.',
      ),
      [t('Detailed body profile'), t('Comparable measurement trends')],
    ),
    PremiumGateFeature.nutritionPrograms => (
      t('Personal nutrition programs'),
      t(
        'Choose a structured nutrition pathway and adapt it to your targets and routine.',
      ),
      [t('Goal-based nutrition pathways'), t('Custom calories and macros')],
    ),
    PremiumGateFeature.weeklyReport => (
      t('Your complete weekly report'),
      t(
        'See the patterns behind your meals, weight, hydration, and progress in one report.',
      ),
      [t('Weekly trends and comparisons'), t('A report ready to export')],
    ),
    PremiumGateFeature.nutritionAnalytics => (
      t('Advanced nutrition analytics'),
      t(
        'Understand calories, macros, nutrients, and the foods shaping your results.',
      ),
      [t('Macro and nutrient trends'), t('Foods with the greatest impact')],
    ),
    PremiumGateFeature.workoutLibrary => (
      t('Home workouts and strength plans'),
      t(
        'Explore 10 training categories with clear movement guidance and reusable routines.',
      ),
      [t('10 training categories'), t('My Routines')],
    ),
    PremiumGateFeature.recipeLibrary => (
      t('1,500 nutrition-aware recipes'),
      t(
        'Explore real recipes with ingredients, portions, nutrition, and regional variety.',
      ),
      [
        t('1,500 recipes'),
        t('Nutrition and food facts'),
        t('Step-by-step preparation'),
      ],
    ),
    PremiumGateFeature.recipeImport => (
      t('Import recipes into your diary'),
      t(
        'Bring in a recipe, verify its ingredients, and keep its nutrition ready to log.',
      ),
      [t('Ingredient verification'), t('Reusable nutrition records')],
    ),
    PremiumGateFeature.mealPlanner => (
      t('A meal plan made for your target'),
      t(
        'Build a practical week of meals around your calories, macros, preferences, and schedule.',
      ),
      [
        t('Personal weekly meal plan'),
        t('Calories and macros balanced for you'),
      ],
    ),
    PremiumGateFeature.contentPacks => (
      t('Premium wellness programs'),
      t(
        'Open structured packs for nutrition, movement, sleep, and sustainable habits.',
      ),
      [t('Guided wellness packs'), t('Progress you can revisit')],
    ),
    PremiumGateFeature.fasting => (
      t('Intermittent fasting tracker'),
      t(
        'Plan a fasting window, follow the timer, and review it beside your nutrition log.',
      ),
      [t('Live fasting timer'), t('Fasting history and context')],
    ),
    PremiumGateFeature.sleep => (
      t('Sleep insights beside nutrition'),
      t(
        'Review sleep records with meal timing and activity without pretending correlation is causation.',
      ),
      [t('Sleep trends'), t('Nutrition and activity context')],
    ),
    PremiumGateFeature.community => (
      t('You control your connections'),
      t('Your health data stays private. Only accept people you know.'),
      [t('Community profile'), t('Friends and requests'), t('Messages')],
    ),
    PremiumGateFeature.premium || PremiumGateFeature.aiCoach => (
      t('Your complete BIL experience'),
      t(
        'Preview the feature now, then unlock every Premium tool and remove ads instantly.',
      ),
      [t('No ads'), t('Advanced insights'), t('Secure sync')],
    ),
  };
  return _PremiumGateContent(
    title: details.$1,
    body: details.$2,
    benefits: details.$3,
    action: t('Start 7-day free trial'),
  );
}

final class _PremiumGateContent {
  const _PremiumGateContent({
    required this.title,
    required this.body,
    required this.benefits,
    required this.action,
  });

  final String title;
  final String body;
  final List<String> benefits;
  final String action;
}

class _PremiumGateCard extends StatelessWidget {
  const _PremiumGateCard({
    required this.tier,
    required this.title,
    required this.body,
    required this.benefits,
    required this.action,
    required this.secondaryAction,
    required this.loading,
    required this.compact,
    required this.isDark,
    required this.onPressed,
    required this.onSecondaryPressed,
  });

  final String tier;
  final String title;
  final String body;
  final List<String> benefits;
  final String action;
  final String? secondaryAction;
  final bool loading;
  final bool compact;
  final bool isDark;
  final VoidCallback onPressed;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 390),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            color: isDark ? const Color(0x85141414) : const Color(0x8AFFFFFF),
            border: Border.all(color: const Color(0x8AF5D477), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? .22 : .12),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 22 : 26,
              compact ? 22 : 27,
              compact ? 22 : 26,
              compact ? 20 : 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    PremiumCrownEmblem(size: compact ? 54 : 60),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tier,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: const Color(0xFFFFD977),
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF17130B),
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 16 : 20),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? const Color(0xFFE4E4E4)
                        : const Color(0xFF3A352B),
                    height: 1.55,
                  ),
                ),
                SizedBox(height: compact ? 14 : 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final benefit in benefits)
                      _BenefitPill(label: benefit, isDark: isDark),
                  ],
                ),
                SizedBox(height: compact ? 18 : 24),
                _GoldActionButton(
                  label: action,
                  loading: loading,
                  onPressed: onPressed,
                ),
                if (secondaryAction != null && onSecondaryPressed != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onSecondaryPressed,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: const Color(0xFFFFDB78),
                      side: const BorderSide(color: Color(0x66F5D477)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    icon: const Icon(Icons.bolt_rounded, size: 20),
                    label: Text(secondaryAction!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _BenefitPill extends StatelessWidget {
  const _BenefitPill({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: isDark ? const Color(0x1FFFFFFF) : const Color(0x24000000),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: const Color(0x20FFFFFF)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        const Icon(Icons.check_rounded, size: 15, color: Color(0xFFFFDA77)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            softWrap: true,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark ? const Color(0xFFF1F1F1) : const Color(0xFF272117),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _GoldActionButton extends StatelessWidget {
  const _GoldActionButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFE89E), Color(0xFFF5C654), Color(0xFFD99B26)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55E9B33C),
          blurRadius: 22,
          offset: Offset(0, 9),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('premium-route-upgrade-cta'),
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 54,
          child: Center(
            child: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF07121E),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xFF08131F),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: Color(0xFF08131F),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}
