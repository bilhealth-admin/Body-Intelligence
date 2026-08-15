import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/secondary_page_app_bar.dart';
import '../../shared/widgets/bil_mobile_list.dart';

import '../../app/localization/app_localizations.dart';
import '../../engine/body_profile.dart';
import '../../engine/plan_engine.dart';
import '../nutrition_plans/domain/nutrition_pathway.dart';
import 'providers/user_profile_provider.dart';
import 'profile_locale_copy.dart';

class PlanPage extends ConsumerStatefulWidget {
  const PlanPage({super.key, this.pathwayId});

  final String? pathwayId;

  @override
  ConsumerState<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends ConsumerState<PlanPage> {
  final controllers = List.generate(6, (_) => TextEditingController());
  bool initialized = false;
  bool saving = false;

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
    final goal = ref.watch(activeGoalProvider).value;
    NutritionPathway? pathway;
    for (final candidate in nutritionPathways) {
      if (candidate.id == widget.pathwayId) {
        pathway = candidate;
        break;
      }
    }
    return Scaffold(
      appBar: SecondaryPageAppBar(title: Text(t('Targets and plan'))),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(t('Complete your profile first.')));
          }
          final body = BodyProfile(
            age: profile.age,
            gender: profile.gender,
            height: profile.height,
            weight: profile.currentWeight,
            targetWeight: profile.targetWeight,
            activityLevel: profile.activityLevel,
            exercises: profile.exercises,
            goalType: goal?.type ?? 'maintain',
          );
          final recommendation = PlanEngine.recommend(body);
          final settingAsync = ref.watch(planSettingProvider(profile.uuid));
          if (settingAsync.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final setting = settingAsync.value;
          if (!initialized) {
            initialized = true;
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
            setState(() => saving = true);
            try {
              int? override(int index) =>
                  values[index] == recommended[index] ? null : values[index];
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
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      t('Plan saved. Historical records were not changed.'),
                    ),
                  ),
                );
              }
            } on ArgumentError catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.message?.toString() ?? error.toString(),
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
                    int.tryParse(controllers[index].text) ?? recommended[index];
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
                      contentPadding: const EdgeInsets.fromLTRB(20, 13, 20, 10),
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
