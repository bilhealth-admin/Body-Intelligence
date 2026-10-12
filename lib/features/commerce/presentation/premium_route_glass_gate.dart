import '../../../shared/widgets/bil_glass_press_feedback.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/bil_pearl_finish.dart';
import '../../../shared/widgets/bil_coach_identity.dart';
import '../domain/commerce_entitlement.dart';
import '../domain/commerce_plan.dart';
import '../domain/subscription_state.dart';
import '../providers/commerce_providers.dart';
import 'bil_store_copy.dart';
import 'premium_crown_emblem.dart';

part 'premium_route_glass_gate_components.dart';
part 'premium_route_access_surfaces.dart';

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
    // Keep existing route callers compatible, without consulting billing or
    // admin state for a Free feature. Community owns sign-in, policy consent,
    // suspension, relationship permissions and moderation on the server.
    if (feature == PremiumGateFeature.community) return child;
    if (feature != PremiumGateFeature.aiCoach) {
      return _PremiumRouteGateContents(feature: feature, child: child);
    }
    return _RetainedAiCoachSurface(
      // Never retain a previous member's screen across an account change.
      key: ValueKey(ref.watch(verifiedEntitlementOwnerIdProvider)),
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
  bool? _lastVerifiedAccess;

  @override
  Widget build(BuildContext context) {
    final credits = ref.watch(aiCoachCreditAccessProvider);
    final ownerKnown = ref.watch(verifiedEntitlementOwnerIdProvider) != null;
    // AsyncValue can retain previous data during a dependency reload. Only a
    // completed check for this owner may populate the owner's retained state.
    final freshAccess = credits.isLoading || credits.hasError || !ownerKnown
        ? null
        : credits.asData?.value;
    if (freshAccess != null) {
      _lastVerifiedAccess = freshAccess;
    }

    // Keep the last server-verified result while the same account silently
    // revalidates. The parent widget is keyed by verified entitlement owner,
    // so an auth/account change recreates this state and cannot inherit another
    // member's cached access.
    //
    // This is presentation continuity only. AI reservations/settlement remain
    // server-authoritative, so stale UI cannot spend unavailable credit.
    final allowed = (freshAccess ?? _lastVerifiedAccess) == true;
    final unavailable = credits.hasError && _lastVerifiedAccess == null;
    final checking =
        (!ownerKnown || credits.isLoading) &&
        _lastVerifiedAccess == null &&
        !unavailable;
    if (allowed) {
      _contentMounted = true;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_contentMounted && checking) const _AiCoachAccessCheckingSurface(),
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
                  child: TooltipVisibility(
                    visible: allowed,
                    child: Opacity(
                      opacity: allowed ? 1 : 0,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (!allowed && (!checking || _contentMounted || unavailable))
          const _PremiumRouteGateContents(
            feature: PremiumGateFeature.aiCoach,
            child: SizedBox.shrink(),
          ),
      ],
    );
  }
}

/// Opaque first-frame surface for the one-time server credit check.
///
/// It matches the immersive Coach background, exposes no transcript or
/// purchase offer, and still lets the member leave while access is resolving.
class _AiCoachAccessCheckingSurface extends StatelessWidget {
  const _AiCoachAccessCheckingSurface();

  @override
  Widget build(BuildContext context) => _PremiumRoutePageFrame(
    title: _featureName(context, PremiumGateFeature.aiCoach),
    returnToDashboard: true,
    backKey: const ValueKey('premium-route-loading-back'),
    child: const Center(
      child: SizedBox.square(
        key: ValueKey('ai-coach-access-checking-surface'),
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );
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
    final isNutritionPrograms = feature == PremiumGateFeature.nutritionPrograms;
    final creditSnapshot = isAiCoach
        ? ref.watch(aiCoachCreditAccessProvider)
        : const AsyncValue<bool>.data(false);
    final creditAccess = creditSnapshot.asData?.value ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (subscription.isLoading) {
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
        subscription.hasError ||
        (!isAiCoach &&
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
        : isNutritionPrograms
        ? state?.authority == EntitlementAuthority.verifiedServer &&
              (state?.grants(CommerceEntitlement.premiumPrograms) ?? false)
        : state?.authority == EntitlementAuthority.verifiedServer &&
              state?.plan != CommercePlan.free;
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
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .97),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1.1,
            ),
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
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
