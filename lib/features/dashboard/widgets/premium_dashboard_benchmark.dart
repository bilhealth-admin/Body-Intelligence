import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../app/theme/bil_premium_responsive_layout.dart';
import '../../../shared/widgets/premium_surface.dart';
import '../providers/dashboard_preferences_provider.dart';
import '../domain/nutrient_dashboard.dart';
import '../dashboard_five_locale_copy.dart';
import 'dashboard_primary_carousel.dart';
import 'dashboard_mobile_body_twin_snapshot.dart';
import 'dashboard_compact_insight_card.dart';
import 'dashboard_twin_deck_shell.dart';

part 'premium_dashboard_command_center.dart';
part 'premium_dashboard_evidence.dart';
part 'dashboard_reference_phone.dart';
part 'dashboard_reference_phone_components.dart';

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
    this.proteinConsumed = 0,
    this.proteinGoal = 0,
    this.carbohydratesConsumed = 0,
    this.carbohydratesGoal = 0,
    this.fatConsumed = 0,
    this.fatGoal = 0,
    this.fiberConsumed = 0,
    this.fiberGoal,
    this.sugarConsumed = 0,
    this.sodiumConsumed = 0,
    this.sodiumGoal,
    this.carbohydratesEvidenceValue,
    this.fiberEvidenceValue,
    this.sugarEvidenceValue,
    this.sodiumEvidenceValue,
    this.nutrientDashboardPreset = 'Calories and macros',
    this.weightTrendValues = const [],
    this.stepTrendValues = const [],
    this.weightUnit = 'kg',
    this.visibleSections = const {
      DashboardSectionIds.aiCoach,
      DashboardSectionIds.calories,
      DashboardSectionIds.macros,
      DashboardSectionIds.activity,
      DashboardSectionIds.quickLog,
      DashboardSectionIds.discover,
      DashboardSectionIds.bestAction,
      DashboardSectionIds.dailyIntelligence,
      DashboardSectionIds.progress,
      DashboardSectionIds.connectedHealth,
      DashboardSectionIds.bodyTwin,
    },
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
  final int proteinConsumed;
  final int proteinGoal;
  final int carbohydratesConsumed;
  final int carbohydratesGoal;
  final int fatConsumed;
  final int fatGoal;
  final int fiberConsumed;
  final int? fiberGoal;
  final int sugarConsumed;
  final int sodiumConsumed;
  final int? sodiumGoal;
  final double? carbohydratesEvidenceValue;
  final double? fiberEvidenceValue;
  final double? sugarEvidenceValue;
  final double? sodiumEvidenceValue;
  final String nutrientDashboardPreset;
  final List<double> weightTrendValues;
  final List<double> stepTrendValues;
  final String weightUnit;
  final Set<String> visibleSections;

  String tr(String en, String ar) => dashboardFiveLocaleText(en, ar);

  @override
  Widget build(BuildContext context) {
    final phone = BilPremiumResponsiveLayout.isPhone(
      MediaQuery.sizeOf(context).width,
    );
    if (phone) {
      return _ReferenceDashboardPhone(
        arabic: arabic,
        caloriesConsumed: caloriesConsumed,
        caloriesGoal: caloriesGoal,
        proteinConsumed: proteinConsumed,
        proteinGoal: proteinGoal,
        carbohydratesConsumed: carbohydratesConsumed,
        carbohydratesGoal: carbohydratesGoal,
        fatConsumed: fatConsumed,
        fatGoal: fatGoal,
        fiberConsumed: fiberConsumed,
        fiberGoal: fiberGoal,
        sugarConsumed: sugarConsumed,
        sodiumConsumed: sodiumConsumed,
        sodiumGoal: sodiumGoal,
        carbohydratesEvidenceValue: carbohydratesEvidenceValue,
        fiberEvidenceValue: fiberEvidenceValue,
        sugarEvidenceValue: sugarEvidenceValue,
        sodiumEvidenceValue: sodiumEvidenceValue,
        nutrientDashboardPreset: nutrientDashboardPreset,
        weightTrendValues: weightTrendValues,
        stepTrendValues: stepTrendValues,
        weightUnit: weightUnit,
        loggingItems: loggingItems,
        progressSection: progressSection,
        personalHealthAi: personalHealthAi,
        bodyTwinSummary: bodyTwinSummary,
        actionTitle: actionTitle,
        actionReason: actionReason,
        confidence: confidence,
        onAction: onAction,
        onExplain: onExplain,
        visibleSections: visibleSections,
      );
    }
    // Retained as a large-screen fallback while the unified mobile rail ships.
    // ignore: unused_local_variable
    final insightCards = <Widget>[
      DashboardCompactInsightCard(
        key: const Key('dashboard-nutrition-context'),
        eyebrow: '',
        title: showRecommendation
            ? tr('Protein below target', 'البروتين أقل من الهدف')
            : tr('Nutrition signal', 'إشارة التغذية'),
        interpretation: nutritionSummary,
        evidence: nutritionEvidence,
        accent: const Color(0xFF65E5B1),
        matchPersonalAiSurface: true,
      ),
      DashboardCompactInsightCard(
        key: const Key('dashboard-action-insight'),
        eyebrow: '',
        title: insightTitle ?? actionTitle,
        interpretation: insightSummary ?? actionReason,
        evidence: actionEvidence,
        accent: const Color(0xFF58D8FF),
        onTap: phone ? onAction : (onExplain ?? onAction),
      ),
    ];

    return LayoutBuilder(
      key: const Key('premium-dashboard-benchmark'),
      builder: (context, constraints) {
        final sectionGap = BilPremiumResponsiveLayout.sectionGap(
          constraints.maxWidth,
        );
        Widget intelligenceFor(double width) {
          final twinHeight = BilPremiumResponsiveLayout.twinBaseHeight(
            constraints.maxWidth,
          );
          if (personalHealthAi == null) {
            return const SizedBox.shrink();
          }
          return SizedBox(
            key: Key(
              phone
                  ? 'dashboard-mobile-personal-ai-slot'
                  : 'dashboard-tablet-personal-ai-slot',
            ),
            height: twinHeight,
            child: personalHealthAi!,
          );
        }

        final top = hero == null
            ? intelligenceFor(constraints.maxWidth)
            : !BilPremiumResponsiveLayout.usesSplitHero(constraints.maxWidth)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hero!,
                  SizedBox(height: sectionGap),
                  intelligenceFor(constraints.maxWidth),
                ],
              )
            : Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: hero!),
                    const SizedBox(width: PremiumDesignTokens.spaceMd),
                    Expanded(
                      flex: 9,
                      child: LayoutBuilder(
                        builder: (context, panelConstraints) =>
                            intelligenceFor(panelConstraints.maxWidth),
                      ),
                    ),
                  ],
                ),
              );
        final dailyContent = Semantics(
          container: true,
          label: tr('Daily Intelligence', 'الذكاء اليومي'),
          child: dailyIntelligence,
        );
        final pairDaySections = BilPremiumResponsiveLayout.pairsDaySections(
          constraints.maxWidth,
        );
        final daily = pairDaySections
            ? PremiumSurface(
                dashboardGlass: true,
                padding: const EdgeInsets.all(PremiumDesignTokens.spaceMd),
                child: dailyContent,
              )
            : dailyContent;
        final dayAndProgress = daily;

        final phoneSummaryCard = phone && progressSection != null
            ? DashboardTwinDeckShell(
                key: const Key('dashboard-mobile-summary-card'),
                title: tr('Today Summary', 'ملخص اليوم'),
                semanticLabel: tr('Today Summary', 'ملخص اليوم'),
                compact: true,
                pages: [DashboardPrimaryEmbeddedScope(child: progressSection!)],
              )
            : null;

        final phoneSummaryAndBioRail =
            phone && phoneSummaryCard != null && personalHealthAi != null
            ? SizedBox(
                key: const Key('dashboard-summary-and-bio-rail'),
                height: BilPremiumResponsiveLayout.twinBaseHeight(
                  constraints.maxWidth,
                ),
                child: LayoutBuilder(
                  builder: (context, railConstraints) {
                    final cardWidth = (railConstraints.maxWidth * .88)
                        .clamp(300.0, 430.0)
                        .toDouble();
                    final cards = <Widget>[personalHealthAi!, phoneSummaryCard];
                    return Semantics(
                      container: true,
                      label: tr(
                        'Bio Intelligence and Today Summary',
                        'الذكاء الحيوي وملخص اليوم',
                      ),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        itemCount: cards.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: PremiumDesignTokens.spaceSm),
                        itemBuilder: (context, index) =>
                            SizedBox(width: cardWidth, child: cards[index]),
                      ),
                    );
                  },
                ),
              )
            : null;

        final mobileTwin = phone
            ? DashboardMobileBodyTwinSnapshot(
                arabic: arabic,
                summary: bodyTwinSummary,
                evidence: bodyTwinEvidence,
                trendSummary: trendSummary,
                trendEvidence: trendEvidence,
              )
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (phone && hero != null) ...[hero!, SizedBox(height: sectionGap)],
            if (!phone) ...[top, SizedBox(height: sectionGap)],
            dayAndProgress,
            if (aiCoach != null) ...[SizedBox(height: sectionGap), aiCoach!],
            if (connectedHealth != null) ...[
              SizedBox(height: sectionGap),
              connectedHealth!,
            ],
            if (mobileTwin != null) ...[
              SizedBox(height: sectionGap),
              mobileTwin,
            ],
            if (phoneSummaryAndBioRail != null) ...[
              SizedBox(height: sectionGap),
              phoneSummaryAndBioRail,
            ],
          ],
        );
      },
    );
  }
}

// Retained for the large-screen release layout.
// ignore: unused_element
