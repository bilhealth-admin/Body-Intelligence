import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/premium_surface.dart';
import '../../../shared/widgets/bil_coach_identity.dart';
import '../../ads/presentation/safe_free_ad_anchor.dart';
import '../../commerce/presentation/premium_label_badge.dart';
import '../providers/dashboard_preferences_provider.dart';
import '../dashboard_five_locale_copy.dart';
import '../domain/dashboard_heart_health_policy.dart';
import '../domain/dashboard_step_trend.dart';
import 'premium_dashboard_card_lock.dart';

part 'premium_dashboard_command_center.dart';
part 'premium_dashboard_evidence.dart';
part 'dashboard_reference_phone.dart';
part 'dashboard_reference_phone_components.dart';
part 'dashboard_reference_goal_components.dart';
part 'dashboard_reference_progress_components.dart';
part 'dashboard_reference_phone_sections.dart';

/// Presentation-only benchmark for the premium dashboard hierarchy.
///
/// It receives already-computed, human-readable intelligence from the current
/// dashboard composition and deliberately owns no providers or calculations.
class PremiumDashboardBenchmark extends StatelessWidget {
  const PremiumDashboardBenchmark({
    super.key,
    required this.arabic,
    required this.actionTitle,
    required this.actionReason,
    required this.actionEvidence,
    required this.confidence,
    this.missingEvidence = '',
    this.abstentionReason,
    required this.onAction,
    this.onExplain,
    this.onAccepted,
    this.onDone,
    this.onNotSuitable,
    required this.dailyIntelligence,
    this.hero,
    this.aiCoach,
    this.progressSection,
    this.personalHealthAi,
    this.connectedHealth,
    required this.bodyTwinSummary,
    required this.bodyTwinEvidence,
    required this.nutritionSummary,
    required this.nutritionEvidence,
    required this.trendSummary,
    required this.trendEvidence,
    required this.loggingItems,
    this.showRecommendation = true,
    this.insightTitle,
    this.insightSummary,
    this.caloriesConsumed = 0,
    this.caloriesGoal = 0,
    this.baseCaloriesGoal = 0,
    this.caloriesBurned = 0,
    this.netCalories = 0,
    this.remainingCalories,
    this.burnedCaloriesApplied = false,
    this.proteinConsumed = 0,
    this.proteinGoal = 0,
    this.carbohydratesConsumed = 0,
    this.carbohydratesGoal = 0,
    this.fatConsumed = 0,
    this.fatGoal = 0,
    this.fiberGoal,
    this.sodiumGoal,
    this.potassiumGoal,
    this.carbohydratesEvidenceValue,
    this.fiberEvidenceValue,
    this.sugarEvidenceValue,
    this.sodiumEvidenceValue,
    this.potassiumEvidenceValue,
    this.nutrientDashboardPreset = 'Calories and macros',
    this.weightTrendValues = const [],
    this.stepTrendValues = const [],
    this.stepSourceName,
    this.todaySteps,
    this.weightUnit = 'kg',
    this.visibleSections = const {
      DashboardSectionIds.aiCoach,
      DashboardSectionIds.calories,
      DashboardSectionIds.macros,
      DashboardSectionIds.activity,
      DashboardSectionIds.quickLog,
      DashboardSectionIds.discover,
      DashboardSectionIds.bestAction,
      DashboardSectionIds.progress,
      DashboardSectionIds.connectedHealth,
      DashboardSectionIds.bodyTwin,
    },
    this.premiumUnlocked = false,
  });

  final bool arabic;
  final String actionTitle;
  final String actionReason;
  final String actionEvidence;
  final String confidence;
  final String missingEvidence;
  final String? abstentionReason;
  final VoidCallback? onAction;
  final VoidCallback? onExplain;
  final VoidCallback? onAccepted;
  final VoidCallback? onDone;
  final VoidCallback? onNotSuitable;
  final Widget dailyIntelligence;
  final Widget? hero;
  final Widget? aiCoach;
  final Widget? progressSection;
  final Widget? personalHealthAi;
  final Widget? connectedHealth;
  final String bodyTwinSummary;
  final String bodyTwinEvidence;
  final String nutritionSummary;
  final String nutritionEvidence;
  final String trendSummary;
  final String trendEvidence;
  final List<DashboardLoggingItem> loggingItems;
  final bool showRecommendation;
  final String? insightTitle;
  final String? insightSummary;
  final int caloriesConsumed;
  final int caloriesGoal;
  final int baseCaloriesGoal;
  final int caloriesBurned;
  final int netCalories;
  final int? remainingCalories;
  final bool burnedCaloriesApplied;
  final int proteinConsumed;
  final int proteinGoal;
  final int carbohydratesConsumed;
  final int carbohydratesGoal;
  final int fatConsumed;
  final int fatGoal;
  final int? fiberGoal;
  final int? sodiumGoal;
  final int? potassiumGoal;
  final double? carbohydratesEvidenceValue;
  final double? fiberEvidenceValue;
  final double? sugarEvidenceValue;
  final double? sodiumEvidenceValue;
  final double? potassiumEvidenceValue;
  final String nutrientDashboardPreset;
  final List<double> weightTrendValues;
  final List<double> stepTrendValues;
  final String? stepSourceName;
  final double? todaySteps;
  final String weightUnit;
  final Set<String> visibleSections;
  final bool premiumUnlocked;

  String tr(String en, String ar) => dashboardFiveLocaleText(en, ar);

  @override
  Widget build(BuildContext context) {
    // One current dashboard composition is used for every window size. The
    // former >=600 px branch was a legacy fallback that omitted user-selected
    // sections (calories, macros, quick log, progress, Body Twin and Discover)
    // and could surface retired cards on tablets and iPads. Keep feature
    // parity across resize, rotation, split-screen and fold/unfold events, then
    // constrain the reading measure on larger windows instead of swapping in a
    // different feature tree.
    final currentDashboard = _ReferenceDashboardPhone(
      arabic: arabic,
      caloriesConsumed: caloriesConsumed,
      caloriesGoal: caloriesGoal,
      baseCaloriesGoal: baseCaloriesGoal,
      caloriesBurned: caloriesBurned,
      netCalories: netCalories,
      remainingCalories: remainingCalories,
      burnedCaloriesApplied: burnedCaloriesApplied,
      proteinConsumed: proteinConsumed,
      proteinGoal: proteinGoal,
      carbohydratesConsumed: carbohydratesConsumed,
      carbohydratesGoal: carbohydratesGoal,
      fatConsumed: fatConsumed,
      fatGoal: fatGoal,
      fiberGoal: fiberGoal,
      sodiumGoal: sodiumGoal,
      potassiumGoal: potassiumGoal,
      fiberEvidenceValue: fiberEvidenceValue,
      sodiumEvidenceValue: sodiumEvidenceValue,
      potassiumEvidenceValue: potassiumEvidenceValue,
      nutrientDashboardPreset: nutrientDashboardPreset,
      weightTrendValues: weightTrendValues,
      stepTrendValues: stepTrendValues,
      stepSourceName: stepSourceName,
      todaySteps: todaySteps,
      weightUnit: weightUnit,
      loggingItems: loggingItems,
      hero: hero,
      aiCoach: aiCoach,
      dailyIntelligence: dailyIntelligence,
      // Owner-retired cards are intentionally not forwarded to the active
      // dashboard tree, even when supplied for compatibility.
      connectedHealth: connectedHealth,
      bodyTwinSummary: bodyTwinSummary,
      actionTitle: actionTitle,
      actionReason: actionReason,
      confidence: confidence,
      onAction: onAction,
      onExplain: onExplain,
      visibleSections: visibleSections,
      premiumUnlocked: premiumUnlocked,
    );
    return LayoutBuilder(
      key: const Key('dashboard-unified-adaptive-layout'),
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            key: const Key('dashboard-current-content-rail'),
            constraints: const BoxConstraints(maxWidth: 840),
            child: currentDashboard,
          ),
        );
      },
    );
  }
}

// Retained for the large-screen release layout.
// ignore: unused_element
