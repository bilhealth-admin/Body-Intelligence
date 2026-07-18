import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/body_profile.dart';
import '../../engine/plan_engine.dart';
import 'providers/user_profile_provider.dart';

class PlanPage extends ConsumerStatefulWidget {
  const PlanPage({super.key});

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
    final profileAsync = ref.watch(userProfileProvider);
    final goal = ref.watch(activeGoalProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Targets and plan')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Complete your profile first.'));
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
                const SnackBar(
                  content: Text('Enter whole-number targets in every field.'),
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
                  const SnackBar(
                    content: Text(
                      'Plan saved. Historical records were not changed.',
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
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'We recommend…',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'BMR ${recommendation.bmr.round()} kcal · TDEE ${recommendation.tdee.round()} kcal · '
                        '${goal?.type ?? 'maintain'} plan ${recommendation.targets.calories} kcal',
                      ),
                      const SizedBox(height: 8),
                      ...recommendation.assumptions.map(
                        (assumption) => Text('• $assumption'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Confidence starts formula-based. Consistent weight and complete meal records are required before observed estimates become useful.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(controllers.length, (index) {
                final current =
                    int.tryParse(controllers[index].text) ?? recommended[index];
                final delta = current - recommended[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[index],
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: labels[index],
                      helperText: delta == 0
                          ? 'Using recommendation: ${recommended[index]}'
                          : '${delta > 0 ? '+' : ''}$delta versus recommendation. Changing this may alter adherence and scenario interpretations.',
                    ),
                  ),
                );
              }),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving…' : 'Save plan'),
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
                child: const Text('Reset to recommended'),
              ),
              const Text(
                'BIL does not recommend faster change as inherently better. If you have medical needs, pregnancy, an eating-disorder history, or clinician-directed targets, consult a qualified professional.',
              ),
            ],
          );
        },
      ),
    );
  }
}
