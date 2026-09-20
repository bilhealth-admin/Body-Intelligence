import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/secondary_page_app_bar.dart';
import '../../shared/widgets/bil_mobile_list.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/services/store_review_prompt_service.dart';
import '../../data/database/database_provider.dart';
import '../../engine/body_profile.dart';
import '../../engine/plan_engine.dart';
import '../intelligence_center/services/coach_context_provider.dart';
import '../nutrition/domain/dietary_preferences.dart';
import '../nutrition_plans/domain/nutrition_pathway.dart';
import '../nutrition_plans/domain/nutrition_pathway_catalog.dart';
import '../weight/providers/weight_provider.dart';
import 'dietary_system_labels.dart';
import 'domain/goal_timeline_estimator.dart';
import 'goal_timeline_card.dart';
import 'plan_navigation_contract.dart';
import 'providers/user_profile_provider.dart';
import 'profile_locale_copy.dart';

class PlanPage extends ConsumerStatefulWidget {
  const PlanPage({
    super.key,
    this.pathwayId,
    this.origin = PlanPageOrigin.dashboard,
  });

  final String? pathwayId;
  final PlanPageOrigin origin;

  @override
  ConsumerState<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends ConsumerState<PlanPage> {
  final controllers = List.generate(6, (_) => TextEditingController());
  bool initialized = false;
  bool saving = false;
  bool leaving = false;
  DietaryPattern selectedPattern = DietaryPattern.omnivore;
  String selectedApproach = 'balanced';
  DietaryPreferences? initialDietaryPreferences;
  List<int> initialTargetValues = const [];

  bool get hasUnsavedChanges {
    final initialDietary = initialDietaryPreferences;
    if (!initialized || initialDietary == null) return false;
    final currentTargets = controllers
        .map((controller) => int.tryParse(controller.text))
        .toList(growable: false);
    return currentTargets.length != initialTargetValues.length ||
        Iterable<int>.generate(
          currentTargets.length,
        ).any((index) => currentTargets[index] != initialTargetValues[index]) ||
        selectedPattern != initialDietary.pattern ||
        selectedApproach != initialDietary.approach;
  }

  Future<void> leave() async {
    if (saving || leaving) return;
    leaving = true;
    try {
      if (hasUnsavedChanges) {
        final discard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.strings.text('Discard changes?')),
            content: Text(context.strings.text('You have unsaved changes.')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.strings.text('Keep editing')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.strings.text('Discard')),
              ),
            ],
          ),
        );
        if (discard != true || !mounted) return;
      }
      context.go(widget.origin.returnLocation);
    } finally {
      leaving = false;
    }
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    final profileAsync = ref.watch(userProfileProvider);
    final effectiveCurrentWeight = ref.watch(effectiveCurrentWeightProvider);
    final latestBodyMeasurement = ref
        .watch(bodyMeasurementHistoryProvider)
        .value
        ?.firstOrNull;
    final goal = ref.watch(activeGoalProvider).value;
    final dietaryAsync = ref.watch(dietaryPreferencesProvider);
    final activePathwayId = ref.watch(activeNutritionPathwayProvider).value;
    final effectivePathwayId = widget.pathwayId ?? activePathwayId;
    NutritionPathway? pathway;
    for (final candidate in nutritionPathways) {
      if (candidate.id == effectivePathwayId) {
        pathway = candidate;
        break;
      }
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: SecondaryPageAppBar(
          title: Text(t('Targets and plan')),
          dashboardPath: widget.origin.returnLocation,
          showDashboardAction: false,
          onBack: leave,
        ),
        body: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t('Your saved data was not changed. Try again.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(userProfileProvider),
                    child: Text(t('Retry')),
                  ),
                ],
              ),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return Center(child: Text(t('Complete your profile first.')));
            }
            if (dietaryAsync.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (dietaryAsync.hasError) {
              return Center(
                child: FilledButton(
                  onPressed: () => ref.invalidate(dietaryPreferencesProvider),
                  child: Text(t('Retry')),
                ),
              );
            }
            final dietaryPreferences =
                dietaryAsync.value ?? const DietaryPreferences();
            final currentWeight =
                effectiveCurrentWeight ?? profile.currentWeight;
            final goalType =
                goal?.type ??
                (profile.targetWeight < currentWeight
                    ? 'lose'
                    : profile.targetWeight > currentWeight
                    ? 'gain'
                    : 'maintain');
            final body = BodyProfile(
              age: profile.age,
              gender: profile.gender,
              height: profile.height,
              weight: currentWeight,
              targetWeight: profile.targetWeight,
              activityLevel: profile.activityLevel,
              exercises: profile.exercises,
              goalType: goalType,
              waistCm: latestBodyMeasurement?.waistCm ?? profile.waist,
              neckCm: latestBodyMeasurement?.neckCm ?? profile.neck,
              hipCm: latestBodyMeasurement?.hipsCm,
            );
            final draftDietaryPreferences = dietaryPreferences.copyWith(
              pattern: selectedPattern,
              approach: selectedApproach,
            );
            final recommendation = PlanEngine.recommend(
              body,
              dietaryPreferences: initialized
                  ? draftDietaryPreferences
                  : dietaryPreferences,
            );
            final goalTimeline = GoalTimelineEstimator.estimate(
              currentWeightKg: currentWeight,
              targetWeightKg: profile.targetWeight,
              goalType: goalType,
              asOf: DateTime.now(),
            );
            final settingAsync = ref.watch(planSettingProvider(profile.uuid));
            if (settingAsync.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final setting = settingAsync.value;
            if (!initialized) {
              initialized = true;
              selectedPattern = dietaryPreferences.pattern;
              selectedApproach = dietaryPreferences.approach;
              initialDietaryPreferences = dietaryPreferences;
              final values = [
                setting?.overrideCalories ?? recommendation.targets.calories,
                setting?.overrideProtein ?? recommendation.targets.protein,
                setting?.overrideCarbs ?? recommendation.targets.carbs,
                setting?.overrideFats ?? recommendation.targets.fats,
                setting?.overrideFiber ?? recommendation.targets.fiber,
                setting?.overrideWater ?? recommendation.targets.water,
              ];
              for (var index = 0; index < controllers.length; index++) {
                controllers[index].text = values[index].toString();
              }
              initialTargetValues = List<int>.unmodifiable(values);
            }
            final recommended = [
              recommendation.targets.calories,
              recommendation.targets.protein,
              recommendation.targets.carbs,
              recommendation.targets.fats,
              recommendation.targets.fiber,
              recommendation.targets.water,
            ];
            const labels = [
              'Calories (kcal)',
              'Protein (g)',
              'Carbohydrates (g)',
              'Fat (g)',
              'Fiber (g)',
              'Water (ml)',
            ];
            Future<void> save() async {
              final values = controllers
                  .map((item) => int.tryParse(item.text))
                  .toList();
              if (values.any((value) => value == null)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      t('Enter whole-number targets in every field.'),
                    ),
                  ),
                );
                return;
              }
              final nextDietaryPreferences = dietaryPreferences.copyWith(
                pattern: selectedPattern,
                approach: selectedApproach,
              );
              setState(() => saving = true);
              try {
                int? override(int index) =>
                    values[index] == recommended[index] ? null : values[index];
                await ref.read(databaseProvider).transaction(() async {
                  await ref
                      .read(planRepositoryProvider)
                      .save(
                        profileUuid: profile.uuid,
                        recommended: recommendation.targets,
                        calories: override(0),
                        protein: override(1),
                        carbs: override(2),
                        fats: override(3),
                        fiber: override(4),
                        water: override(5),
                      );
                  await ref
                      .read(dietaryPreferencesRepositoryProvider)
                      .saveInCurrentTransaction(nextDietaryPreferences);
                });
                if (context.mounted) {
                  initialTargetValues = List<int>.unmodifiable(
                    values.whereType<int>(),
                  );
                  initialDietaryPreferences = nextDietaryPreferences;
                  ref.invalidate(planSettingProvider(profile.uuid));
                  ref.invalidate(dietaryPreferencesProvider);
                  ref.invalidate(coachContextSnapshotProvider);
                  unawaited(
                    ref
                        .read(storeReviewPromptServiceProvider)
                        .recordPositiveMoment(StoreReviewMoment.planSaved),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t('Plan saved. Historical records were not changed.'),
                      ),
                    ),
                  );
                  context.go(widget.origin.returnLocation);
                }
              } on ArgumentError {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t('Enter whole-number targets in every field.'),
                      ),
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => saving = false);
              }
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                BilMobilePageIntro(
                  eyebrow: t('Goals'),
                  title: t('Calorie & macro goals'),
                  description: t(
                    'Review the recommendation, then adjust only what fits your plan.',
                  ),
                ),
                BilMobileSectionHeader(
                  profileLocaleText(
                    context,
                    'Dietary system',
                    'النظام الغذائي',
                  ),
                ),
                Material(
                  key: const Key('dietary-system-selector'),
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            profileLocaleText(
                              context,
                              'Eating pattern',
                              'نمط الأكل',
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        RadioGroup<DietaryPattern>(
                          groupValue: selectedPattern,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => selectedPattern = value);
                          },
                          child: Column(
                            children: [
                              for (final pattern in DietaryPattern.values)
                                RadioListTile<DietaryPattern>(
                                  key: Key('dietary-pattern-${pattern.name}'),
                                  value: pattern,
                                  title: Text(
                                    dietaryPatternLabel(context, pattern),
                                  ),
                                  dense: true,
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            profileLocaleText(
                              context,
                              'Plan style',
                              'أسلوب الخطة',
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        RadioGroup<String>(
                          groupValue: selectedApproach,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => selectedApproach = value);
                          },
                          child: Column(
                            children: [
                              for (final approach
                                  in DietaryPreferences.supportedApproaches)
                                RadioListTile<String>(
                                  key: Key('dietary-approach-$approach'),
                                  value: approach,
                                  title: Text(
                                    dietaryApproachLabel(context, approach),
                                  ),
                                  dense: true,
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: Text(
                            profileLocaleText(
                              context,
                              'Eating pattern controls compatible foods. Plan style shapes meal suggestions; neither changes allergy safeguards.',
                              'يحدد نمط الأكل الأطعمة المتوافقة، ويشكل أسلوب الخطة اقتراحات الوجبات دون تغيير احتياطات الحساسية.',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                BilMobileSectionHeader(
                  profileLocaleText(
                    context,
                    'Goal timeline',
                    'الجدول الزمني للهدف',
                  ),
                ),
                GoalTimelineCard(estimate: goalTimeline),
                if (pathway != null) ...[
                  BilMobileSectionHeader(t('Selected pathway')),
                  _PathwayContextCard(pathway: pathway),
                ],
                BilMobileSectionHeader(t('Default goal')),
                ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          t('We recommend…'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${t('BMR')} ${recommendation.bmr.round()} ${t('kcal')} · ${t('TDEE')} ${recommendation.tdee.round()} ${t('kcal')} · '
                          '${t(goal?.type ?? 'maintain')} ${t('plan')} ${recommendation.targets.calories} ${t('kcal')}',
                        ),
                        const SizedBox(height: 8),
                        ...recommendation.assumptions.map(
                          (assumption) => Text(
                            '• ${_localizedAssumption(context, assumption)}',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t(
                            'Confidence starts formula-based. Consistent weight and complete meal records are required before observed estimates become useful.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                BilMobileSectionHeader(t('Custom daily goals')),
                ...List.generate(controllers.length, (index) {
                  final current =
                      int.tryParse(controllers[index].text) ??
                      recommended[index];
                  final delta = current - recommended[index];
                  return Padding(
                    padding: EdgeInsets.zero,
                    child: TextField(
                      controller: controllers[index],
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: t(labels[index]),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.fromLTRB(
                          20,
                          13,
                          20,
                          10,
                        ),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        helperText: delta == 0
                            ? '${t('Using recommendation')}: ${recommended[index]}'
                            : '${delta > 0 ? '+' : ''}$delta ${t('versus recommendation. Changing this may alter adherence and scenario interpretations.')}',
                      ),
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: FilledButton(
                    key: const Key('plan-save-action'),
                    onPressed: saving ? null : save,
                    child: Text(saving ? t('Saving…') : t('Save plan')),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await ref
                        .read(planRepositoryProvider)
                        .reset(
                          profileUuid: profile.uuid,
                          recommended: recommendation.targets,
                        );
                    for (var index = 0; index < controllers.length; index++) {
                      controllers[index].text = recommended[index].toString();
                    }
                    initialTargetValues = List<int>.unmodifiable(recommended);
                    if (mounted) setState(() {});
                  },
                  child: Text(t('Reset to recommended')),
                ),
                Text(
                  t(
                    'BIL does not recommend faster change as inherently better. If you have medical needs, pregnancy, an eating-disorder history, or clinician-directed targets, consult a qualified professional.',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _localizedAssumption(BuildContext context, String value) {
    if (value.startsWith('Activity factor:')) {
      return '${profileLocaleText(context, 'Activity factor', 'معامل النشاط')}: ${value.split(':').last.trim()}';
    }
    if (value.startsWith('Goal direction:')) {
      return '${profileLocaleText(context, 'Goal direction', 'اتجاه الهدف')}: ${value.split(':').last.trim()}';
    }
    return switch (value) {
      'Mifflin–St Jeor BMR using the saved age, sex, height, and current weight' =>
        profileLocaleText(
          context,
          value,
          'معادلة ميفلين–سانت جيور باستخدام العمر والجنس والطول والوزن الحالي المحفوظ',
        ),
      'Logged scale weight cannot distinguish fat from muscle' =>
        profileLocaleText(
          context,
          value,
          'وزن الميزان المسجل لا يميز بين الدهون والعضلات',
        ),
      _ => value,
    };
  }
}

class _PathwayContextCard extends StatelessWidget {
  const _PathwayContextCard({required this.pathway});

  final NutritionPathway pathway;

  @override
  Widget build(BuildContext context) {
    final reviewRequired =
        pathway.safety == NutritionPathwaySafety.clinicianReview;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    profileLocaleText(
                      context,
                      pathway.enTitle,
                      pathway.arTitle,
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              profileLocaleText(
                context,
                pathway.enSubtitle,
                pathway.arSubtitle,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              reviewRequired
                  ? profileLocaleText(
                      context,
                      'Review draft only. Clinician review is required before activation.',
                      'مسودة للمراجعة فقط. يلزم مختص قبل التفعيل.',
                    )
                  : profileLocaleText(
                      context,
                      'Selecting a pathway does not change your targets. No values apply until you save the plan.',
                      'اختيار المسار لا يغيّر أهدافك. لا تُطبق أي قيم حتى تضغط حفظ الخطة.',
                    ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: reviewRequired
                    ? const Color(0xFF9A6700)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
