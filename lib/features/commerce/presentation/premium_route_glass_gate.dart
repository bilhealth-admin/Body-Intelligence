import '../../../shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import '../../../shared/widgets/bil_pearl_material.dart';
import '../../../shared/widgets/bil_navigation_feedback.dart';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/bil_pearl_finish.dart';
import '../../../shared/widgets/bil_coach_identity.dart';
import '../../auth/auth_entry_locale_copy.dart';
import '../../intelligence_center/intelligence_locale_copy.dart';
import '../domain/commerce_entitlement.dart';
import '../domain/commerce_plan.dart';
import '../domain/subscription_state.dart';
import '../providers/commerce_providers.dart';
import 'bil_store_copy.dart';
import 'premium_crown_emblem.dart';

part 'premium_route_glass_gate_components.dart';
part 'premium_route_access_surfaces.dart';
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
  Timer? _ownerResolutionTimer;
  bool _ownerResolutionExpired = false;

  @override
  void initState() {
    super.initState();
    _startOwnerResolutionWindow();
  }

  void _startOwnerResolutionWindow() {
    _ownerResolutionTimer?.cancel();
    _ownerResolutionExpired = false;
    _ownerResolutionTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() => _ownerResolutionExpired = true);
    });
  }

  void _retryOwnerResolution() {
    setState(_startOwnerResolutionWindow);
    ref.invalidate(verifiedEntitlementOwnerProvider);
    ref.invalidate(aiCoachCreditAccessProvider);
  }

  Future<void> _openSignIn() async {
    await context.push<void>('/login');
    if (!mounted) return;
    _retryOwnerResolution();
  }

  @override
  void dispose() {
    _ownerResolutionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final credits = ref.watch(aiCoachCreditAccessProvider);
    final ownerSnapshot = ref.watch(verifiedEntitlementOwnerProvider);
    final ownerKnown = ref.watch(verifiedEntitlementOwnerIdProvider) != null;
    if (ownerKnown || ownerSnapshot.hasValue || ownerSnapshot.hasError) {
      _ownerResolutionTimer?.cancel();
    }
    if (!ownerKnown) {
      // A settled signed-out owner is not an in-flight credit request. No
      // entitlement is granted here, and no Coach child or paid offer mounts.
      if (ownerSnapshot.hasError ||
          (!ownerSnapshot.hasValue && _ownerResolutionExpired)) {
        return _AiCoachAccountRecoverySurface(
          unavailable: true,
          onRetry: _retryOwnerResolution,
          onSignIn: _openSignIn,
        );
      }
      if (ownerSnapshot.hasValue) {
        return _AiCoachAccountRecoverySurface(
          unavailable: false,
          onRetry: _retryOwnerResolution,
          onSignIn: _openSignIn,
        );
      }
      return const _AiCoachAccessCheckingSurface();
    }
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
        credits.isLoading && _lastVerifiedAccess == null && !unavailable;
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

class _PremiumRouteGateContents extends ConsumerStatefulWidget {
  const _PremiumRouteGateContents({required this.feature, required this.child});

  final PremiumGateFeature feature;
  final Widget child;

  @override
  ConsumerState<_PremiumRouteGateContents> createState() =>
      _PremiumRouteGateContentsState();
}

class _PremiumRouteGateContentsState
    extends ConsumerState<_PremiumRouteGateContents> {
  ProviderSubscription<AsyncValue<String?>>? _ownerSubscription;
  String? _observedOwner;
  int _ownerVisit = 0;
  int? _verifiedFreeVisit;
  Future<SubscriptionState>? _sourceReadWitness;
  final _retiredSourceReads = Expando<bool>();
  int _retiredReadGeneration = -1;

  void _retireFreePresentationRead() {
    final previousRead = _sourceReadWitness;
    if (previousRead != null) _retiredSourceReads[previousRead] = true;
    // Retire an in-flight read even if no frame has observed it yet. A pending
    // Future may be forwarded across invalidations: a retired handle may never
    // seed display continuity again. This is deliberately conservative; fresh
    // authority still controls the real gate/child in the original code below.
    if (widget.feature != PremiumGateFeature.aiCoach) {
      final currentRead = ref.read(verifiedSubscriptionStateProvider.future);
      // Observe only identity here. The AsyncValue below still owns and shows
      // its error; do not leave this extra Future projection unhandled.
      currentRead.ignore();
      _retiredSourceReads[currentRead] = true;
      final generation = ref
          .read(verifiedSubscriptionReadWitnessProvider)
          .generation;
      if (generation > _retiredReadGeneration) {
        _retiredReadGeneration = generation;
      }
    }
    _ownerVisit++;
    _verifiedFreeVisit = null;
  }

  @override
  void initState() {
    super.initState();
    _observedOwner = ref.read(verifiedEntitlementOwnerIdProvider);
    // Observe raw owner transitions, including A -> B -> A between frames.
    // A scalar owner key alone can miss that visit boundary. This retains only
    // public Free gate presentation, never an entitlement or account data.
    _ownerSubscription = ref.listenManual(verifiedEntitlementOwnerProvider, (
      previous,
      next,
    ) {
      if (next.hasError) {
        setState(() {
          _retireFreePresentationRead();
        });
      } else if (next.hasValue && next.value != _observedOwner) {
        setState(() {
          _observedOwner = next.value;
          _retireFreePresentationRead();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _PremiumRouteGateContents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feature != widget.feature) _verifiedFreeVisit = null;
  }

  @override
  void dispose() {
    _ownerSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feature = widget.feature;
    final child = widget.child;
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
    final owner = isAiCoach
        ? null
        : ref.watch(verifiedEntitlementOwnerIdProvider);
    final ownerSnapshot = isAiCoach
        ? const AsyncValue<String?>.data(null)
        : ref.watch(verifiedEntitlementOwnerProvider);
    if (!isAiCoach && owner != _observedOwner) {
      _observedOwner = owner;
      _retireFreePresentationRead();
    }
    final source = isAiCoach
        ? const AsyncValue<SubscriptionState>.loading()
        : ref.watch(verifiedSubscriptionStateProvider);
    final sourceRead = isAiCoach
        ? null
        : ref.read(verifiedSubscriptionStateProvider.future);
    sourceRead?.ignore();
    _sourceReadWitness = sourceRead;
    final readGeneration = isAiCoach
        ? 0
        : ref.read(verifiedSubscriptionReadWitnessProvider).generation;
    // A pending Future can be forwarded by Riverpod across owner reloads.
    // A genuinely new canonical read is identified by its loader generation,
    // never by a previously retired Future handle. Direct preview overrides
    // have no loader witness and retain the conservative identity check.
    final currentPresentationRead = readGeneration == 0
        ? sourceRead != null && _retiredSourceReads[sourceRead] != true
        : readGeneration > _retiredReadGeneration;
    if (!isAiCoach && !subscription.isLoading) {
      _verifiedFreeVisit =
          !subscription.hasError &&
              !ownerSnapshot.hasError &&
              !source.isLoading &&
              !source.hasError &&
              sourceRead != null &&
              currentPresentationRead &&
              owner != null &&
              state?.authority == EntitlementAuthority.verifiedServer &&
              state?.plan == CommercePlan.free
          ? _ownerVisit
          : null;
    }
    // A timer/resume refresh must not replace a settled Free card with a
    // full-page spinner. Keep only its public presentation during an explicit
    // same-owner source refresh. Initial loads, owner/dependency reloads,
    // errors and completed paid/denied results use the original authority path.
    // The source is never overridden and the Plans action stays disabled until
    // verification completes; this cannot grant access to the protected child.
    final retainingFreeGate =
        !isAiCoach &&
        subscription.isLoading &&
        !subscription.hasError &&
        !ownerSnapshot.hasError &&
        owner != null &&
        sourceRead != null &&
        currentPresentationRead &&
        _verifiedFreeVisit == _ownerVisit &&
        source.isRefreshing &&
        !source.hasError &&
        source.value?.authority == EntitlementAuthority.verifiedServer &&
        source.value?.plan == CommercePlan.free;
    final isNutritionPrograms = feature == PremiumGateFeature.nutritionPrograms;
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
        subscription.hasError ||
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
              onPressed: retainingFreeGate
                  ? null
                  : () => context.push(
                      isAiCoach
                          ? '/plans?focus=boost'
                          : '/plans?focus=subscription',
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
