import '../../../shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import '../../../shared/widgets/bil_pearl_material.dart';
import '../../../shared/widgets/bil_navigation_feedback.dart';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/bil_pearl_finish.dart';
import '../../../shared/widgets/bil_coach_identity.dart';
import '../../auth/auth_entry_locale_copy.dart';
import '../../intelligence_center/intelligence_locale_copy.dart';
import '../domain/commerce_entitlement.dart';
import '../domain/commerce_plan.dart';
import '../domain/subscription_provider.dart';
import '../domain/store_renewal_observation.dart';
import '../providers/store_renewal_recheck_provider.dart';
import '../domain/subscription_state.dart';
import '../providers/commerce_providers.dart';
import 'bil_store_copy.dart';
import 'premium_crown_emblem.dart';

part 'premium_route_glass_gate_components.dart';
part 'premium_route_google_renewal_surface.dart';
part 'premium_route_access_surfaces.dart';
part 'premium_route_ai_credit_surface.dart';
part 'premium_route_glass_gate_card.dart';

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

bool _verifiedSubscriptionAllowsFeature(
  SubscriptionState? state,
  PremiumGateFeature feature,
) =>
    state?.authority == EntitlementAuthority.verifiedServer &&
    (feature == PremiumGateFeature.nutritionPrograms
        ? state!.grants(CommerceEntitlement.premiumPrograms)
        : state?.plan != CommercePlan.free);

void _handlePremiumRouteBack(
  BuildContext context, {
  required bool returnToDashboard,
}) {
  // Preserve the real entry point (Dashboard, More, or another caller) when
  // the gate was pushed. Direct/deep links have no route to pop, so they use
  // the safe Dashboard fallback.
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/dashboard');
  }
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
    // Keep existing route callers compatible, without consulting billing or
    // admin state for a Free feature. Community owns sign-in, policy consent,
    // suspension, relationship permissions and moderation on the server.
    if (feature == PremiumGateFeature.community) return child;
    if (feature != PremiumGateFeature.aiCoach) {
      return _RetainedStorePremiumSurface(
        key: ValueKey((
          ref.watch(verifiedEntitlementOwnerIdProvider),
          ref.watch(verifiedEntitlementOwnerVisitProvider),
        )),
        feature: feature,
        child: child,
      );
    }
    return _RetainedAiCoachSurface(
      // Never retain a previous member's screen across an account change.
      key: ValueKey((
        ref.watch(verifiedEntitlementOwnerIdProvider),
        ref.watch(verifiedEntitlementOwnerVisitProvider),
      )),
      child: child,
    );
  }
}

class _PremiumRouteGateContents extends ConsumerWidget {
  const _PremiumRouteGateContents({required this.feature, required this.child});

  final PremiumGateFeature feature;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAiCoach = feature == PremiumGateFeature.aiCoach;
    // Boost belongs to the account, not its membership tier. A subscription
    // lookup (including its loading/error state) must not block verified credit.
    final subscription = isAiCoach
        ? const AsyncValue<SubscriptionState?>.data(null)
        : ref.watch(verifiedSubscriptionAccessProvider);
    final storefrontPlan = isAiCoach
        ? null
        : ref.watch(storefrontTargetPlanProvider).value;
    final state = subscription.asData?.value;
    // Only re-use a completed public Free display for this authenticated
    // owner visit. Neither the protected child nor checkout uses that display.
    final retainingFreeGate =
        !isAiCoach && ref.watch(verifiedFreePresentationProvider);
    final creditSnapshot = isAiCoach
        ? ref.watch(aiCoachCreditAccessProvider)
        : const AsyncValue<bool>.data(false);
    final creditAccess = creditSnapshot.asData?.value ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (subscription.isLoading && !retainingFreeGate) {
      return _PremiumRouteAccessChecking(
        title: _featureName(context, feature),
        isDark: isDark,
        returnToDashboard: isAiCoach,
      );
    }
    // A local Free fallback means the server has not verified this owner.
    // Fail closed with Retry, not a paid offer that mislabels an entitled
    // reviewer as Free after a transient auth/network read.
    final verificationUnavailable =
        (!retainingFreeGate && subscription.hasError) ||
        (!isAiCoach &&
            !retainingFreeGate &&
            (state == null ||
                state.authority != EntitlementAuthority.verifiedServer)) ||
        (isAiCoach && creditSnapshot.hasError);
    if (verificationUnavailable) {
      return _PremiumRouteAccessUnavailable(
        title: _featureName(context, feature),
        isDark: isDark,
        returnToDashboard: isAiCoach,
        onRetry: () {
          if (isAiCoach) {
            ref.invalidate(aiCoachCreditAccessProvider);
          } else {
            ref.invalidate(verifiedSubscriptionStateProvider);
          }
        },
        child: child,
      );
    }
    final loading = isAiCoach && creditSnapshot.isLoading;
    // Never show an upgrade offer while the server is still resolving the
    // member's entitlement. This avoids the brief (and confusing) paywall
    // flash reported when an active AI subscription is opened from More.
    if (loading) {
      return _PremiumRouteAccessChecking(
        title: _featureName(context, feature),
        isDark: isDark,
        returnToDashboard: isAiCoach,
      );
    }
    final hasAccess = isAiCoach
        ? creditAccess
        : _verifiedSubscriptionAllowsFeature(state, feature);
    if (hasAccess) return child;

    final content = _contentFor(context, feature);
    final storeLocale = Localizations.localeOf(context).toLanguageTag();
    // The glass names the only subscription family exposed by the verified
    // billing storefront. Unknown storefronts fail closed to Premium; an
    // underpriced AI-inclusive membership is never advertised by locale/IP.
    final tier = isAiCoach
        ? 'BIL AI BOOST'
        : storefrontPlan == CommercePlan.premiumAiCoach
        ? 'BIL PREMIUM AI COACH'
        : 'BIL PREMIUM';
    return _PremiumRoutePageFrame(
      title: _featureName(context, feature),
      returnToDashboard: isAiCoach,
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _PremiumGateCard(
              tier: tier,
              title: content.title,
              body: content.body,
              benefits: content.benefits,
              action: isAiCoach
                  ? context.strings.text('Get AI Boost')
                  : BilStoreCopy.text(storeLocale, 'plans'),
              secondaryAction: null,
              loading: loading,
              compact: constraints.maxHeight < 700,
              isDark: isDark,
              showCoach: isAiCoach,
              onPressed: () => context.push(
                isAiCoach ? '/plans?focus=boost' : '/plans?focus=subscription',
              ),
              onSecondaryPressed: null,
            ),
          ),
        ),
      ),
    );
  }
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
        t('Global multilingual voice'),
        t('2,500 non-expiring AI Boost tokens'),
      ],
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
      t('Guided wellness packs'),
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
      t('Everything included in BIL Free'),
      [t('No ads'), t('Advanced insights'), t('Secure sync')],
    ),
  };
  return _PremiumGateContent(
    title: details.$1,
    body: details.$2,
    benefits: details.$3,
  );
}
