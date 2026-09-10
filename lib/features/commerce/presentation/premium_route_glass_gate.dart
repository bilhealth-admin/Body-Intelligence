import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../shared/widgets/bil_coach_identity.dart';
import '../../admin/services/ai_coach_admin_service.dart';
import '../domain/commerce_entitlement.dart';
import '../domain/commerce_plan.dart';
import '../domain/subscription_state.dart';
import '../providers/commerce_providers.dart';
import 'bil_store_copy.dart';
import 'premium_crown_emblem.dart';

part 'premium_route_glass_gate_components.dart';

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
    if (feature != PremiumGateFeature.aiCoach) {
      return _PremiumRouteGateContents(feature: feature, child: child);
    }
    return _RetainedAiCoachSurface(
      // Never retain a previous member's screen across an account change.
      key: ValueKey(ref.watch(verifiedEntitlementOwnerProvider).asData?.value),
      child: child,
    );
  }
}

class _RetainedAiCoachSurface extends ConsumerStatefulWidget {
  const _RetainedAiCoachSurface({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<_RetainedAiCoachSurface> createState() =>
      _RetainedAiCoachSurfaceState();
}

class _RetainedAiCoachSurfaceState
    extends ConsumerState<_RetainedAiCoachSurface> {
  bool _contentMounted = false;

  @override
  Widget build(BuildContext context) {
    final credits = ref.watch(aiCoachCreditAccessProvider);
    final unavailable = credits.hasError;
    // A refresh retains the last verified result, not a locally inferred
    // entitlement. Every request is still authorized by the server. Errors,
    // an exhausted balance and a new account all fail closed.
    final allowed = !unavailable && credits.asData?.value == true;
    if (allowed || unavailable || (!unavailable && !credits.isLoading)) {
      _contentMounted = true;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // Keep the same element position even when the gate is shown. Credit
        // settlement must not discard a draft, scroll position or transcript.
        if (_contentMounted)
          KeyedSubtree(
            key: const ValueKey('ai-coach-retained-content'),
            child: ExcludeFocus(
              excluding: !allowed,
              child: AbsorbPointer(
                absorbing: !allowed,
                child: ExcludeSemantics(
                  excluding: !allowed,
                  child: widget.child,
                ),
              ),
            ),
          ),
        if (!allowed)
          const _PremiumRouteGateContents(
            feature: PremiumGateFeature.aiCoach,
            child: SizedBox.shrink(),
          ),
      ],
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
        : ref.watch(verifiedSubscriptionStateProvider);
    final storefrontPlan = isAiCoach
        ? null
        : ref.watch(storefrontTargetPlanProvider).value;
    final state = subscription.asData?.value;
    final isNutritionPrograms = feature == PremiumGateFeature.nutritionPrograms;
    final isCommunity = feature == PremiumGateFeature.community;
    final adminAccess = isCommunity
        ? ref.watch(aiCoachAdminAccessProvider)
        : const AsyncValue<bool>.data(false);
    final creditSnapshot = isAiCoach
        ? ref.watch(aiCoachCreditAccessProvider)
        : const AsyncValue<bool>.data(false);
    final creditAccess = creditSnapshot.asData?.value ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (subscription.isLoading) {
      return _PremiumRouteAccessChecking(
        isDark: isDark,
        returnToDashboard: isAiCoach,
      );
    }
    if (isCommunity &&
        state?.plan == CommercePlan.free &&
        adminAccess.isLoading) {
      return _PremiumRouteAccessChecking(
        isDark: isDark,
        returnToDashboard: false,
      );
    }
    final communityAdminCheckFailed =
        isCommunity && state?.plan == CommercePlan.free && adminAccess.hasError;
    final verificationUnavailable =
        subscription.hasError ||
        (isAiCoach && creditSnapshot.hasError) ||
        communityAdminCheckFailed;
    if (verificationUnavailable) {
      return _PremiumRouteAccessUnavailable(
        isDark: isDark,
        returnToDashboard: isAiCoach,
        onRetry: () {
          if (isAiCoach) {
            ref.invalidate(aiCoachCreditAccessProvider);
          } else {
            ref.invalidate(verifiedSubscriptionStateProvider);
          }
          if (isCommunity) ref.invalidate(aiCoachAdminAccessProvider);
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
        isDark: isDark,
        returnToDashboard: isAiCoach,
      );
    }
    final hasAccess = isAiCoach
        ? creditAccess
        : isNutritionPrograms
        ? state?.authority == EntitlementAuthority.verifiedServer &&
              (state?.grants(CommerceEntitlement.premiumPrograms) ?? false)
        : isCommunity && adminAccess.asData?.value == true
        ? true
        : state != null && state.plan != CommercePlan.free;
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
                key: const ValueKey('premium-route-back'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => _handlePremiumRouteBack(
                  context,
                  returnToDashboard: isAiCoach,
                ),
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
                    action: isAiCoach
                        ? context.strings.text('Get AI Boost')
                        : BilStoreCopy.text(storeLocale, 'plans'),
                    secondaryAction: null,
                    loading: loading,
                    compact: compact,
                    isDark: isDark,
                    showCoach: isAiCoach,
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

class _PremiumRouteAccessUnavailable extends StatelessWidget {
  const _PremiumRouteAccessUnavailable({
    required this.child,
    required this.isDark,
    required this.returnToDashboard,
    required this.onRetry,
  });

  final Widget child;
  final bool isDark;
  final bool returnToDashboard;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        KeyedSubtree(
          key: const ValueKey('premium-route-protected-content'),
          child: AbsorbPointer(child: ExcludeSemantics(child: child)),
        ),
        Positioned.fill(
          child: ColoredBox(
            color: scheme.surface.withValues(alpha: isDark ? .96 : .94),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => _handlePremiumRouteBack(
                  context,
                  returnToDashboard: returnToDashboard,
                ),
                key: const ValueKey('premium-route-back'),
                icon: const BackButtonIcon(),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                key: const ValueKey('premium-route-access-unavailable'),
                elevation: 0,
                color: scheme.surfaceContainerHighest,
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
                        Icon(
                          Icons.sync_problem_rounded,
                          size: 42,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.strings.text('Unavailable'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.strings.text(
                            'The request could not be completed. No partial change was kept. Try again.',
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.tonalIcon(
                          key: const ValueKey('premium-route-access-retry'),
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(context.strings.text('Try again')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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

final class _PremiumGateContent {
  const _PremiumGateContent({
    required this.title,
    required this.body,
    required this.benefits,
  });

  final String title;
  final String body;
  final List<String> benefits;
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
    required this.showCoach,
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
  final bool showCoach;
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
                    if (showCoach)
                      Container(
                        width: compact ? 54 : 60,
                        height: compact ? 54 : 60,
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFC8F3FF),
                          shape: BoxShape.circle,
                        ),
                        child: const ClipOval(child: BilCoachPortrait()),
                      )
                    else
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
