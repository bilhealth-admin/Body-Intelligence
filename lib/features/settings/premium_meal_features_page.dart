import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/runtime_copy.dart';
import '../commerce/domain/commerce_entitlement.dart';
import '../commerce/providers/commerce_providers.dart';
import '../profile/providers/user_profile_provider.dart';

const mealMacroDisplayEnabledKey = 'diary.mealMacros.enabled.v1';
const mealMacroDisplayModeKey = 'diary.mealMacros.mode.v1';

String mealCalorieGoalKey(String meal) => 'goals.mealCalories.$meal.v1';

final mealMacroDisplayProvider = StreamProvider<MealMacroDisplay>((ref) async* {
  final repository = ref.watch(preferencesRepositoryProvider);
  await for (final enabled in repository.watch(mealMacroDisplayEnabledKey)) {
    final mode = await repository.get(mealMacroDisplayModeKey);
    yield MealMacroDisplay(
      enabled: enabled == 'true',
      mode: mode == 'percent'
          ? MealMacroDisplayMode.percent
          : MealMacroDisplayMode.grams,
    );
  }
});

enum MealMacroDisplayMode { grams, percent }

final class MealMacroDisplay {
  const MealMacroDisplay({required this.enabled, required this.mode});
  final bool enabled;
  final MealMacroDisplayMode mode;
}

final mealCalorieGoalsProvider = StreamProvider<Map<String, double>>((ref) {
  final repository = ref.watch(preferencesRepositoryProvider);
  const meals = ['breakfast', 'lunch', 'dinner', 'snack'];
  return Stream<Map<String, double>>.multi((controller) {
    final values = <String, double>{};
    final ready = <String>{};
    final subscriptions = <dynamic>[];
    for (final meal in meals) {
      subscriptions.add(
        repository.watch(mealCalorieGoalKey(meal)).listen((raw) {
          ready.add(meal);
          final parsed = double.tryParse(raw ?? '');
          if (parsed != null &&
              parsed.isFinite &&
              parsed >= 100 &&
              parsed <= 10000) {
            values[meal] = parsed;
          } else {
            values.remove(meal);
          }
          if (ready.length == meals.length) {
            controller.add(Map.unmodifiable(values));
          }
        }, onError: controller.addError),
      );
    }
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  });
});

class VerifiedPremiumFeatureGate extends ConsumerWidget {
  const VerifiedPremiumFeatureGate({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verifiedSubscriptionStateProvider);
    return state.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(verifiedSubscriptionStateProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_copy(context, 'Retry subscription check')),
          ),
        ),
      ),
      data: (subscription) {
        if (subscription.grants(CommerceEntitlement.advancedIntelligence)) {
          return child;
        }
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_rounded, size: 54),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.push('/plans'),
                    child: Text(_copy(context, 'View Premium plans')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class MealCalorieGoalsPage extends ConsumerWidget {
  const MealCalorieGoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = _copy(context, 'Calorie goals by meal');
    return VerifiedPremiumFeatureGate(
      title: title,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ref
            .watch(mealCalorieGoalsProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(mealCalorieGoalsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_copy(context, 'Retry')),
                ),
              ),
              data: (goals) => ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _copy(
                        context,
                        'Set a separate calorie goal for each meal.',
                      ),
                    ),
                  ),
                  for (final meal in const [
                    'breakfast',
                    'lunch',
                    'dinner',
                    'snack',
                  ])
                    ListTile(
                      title: Text(_copy(context, meal)),
                      subtitle: Text(
                        goals[meal] == null
                            ? _copy(context, 'No meal goal')
                            : '${goals[meal]!.toStringAsFixed(0)} kcal',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          _editMealGoal(context, ref, meal, goals[meal]),
                    ),
                ],
              ),
            ),
      ),
    );
  }

  Future<void> _editMealGoal(
    BuildContext context,
    WidgetRef ref,
    String meal,
    double? current,
  ) async {
    final controller = TextEditingController(
      text: current?.toStringAsFixed(0) ?? '',
    );
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> commit(String raw) async {
            if (saving) return;
            final value = double.tryParse(raw.replaceAll(',', '.'));
            if (raw.isNotEmpty &&
                (value == null ||
                    !value.isFinite ||
                    value < 100 ||
                    value > 10000)) {
              setDialogState(
                () => error = _copy(context, 'Enter 100 to 10000 kcal.'),
              );
              return;
            }
            setDialogState(() {
              saving = true;
              error = null;
            });
            try {
              final repository = ref.read(preferencesRepositoryProvider);
              if (raw.isEmpty) {
                await repository.remove(mealCalorieGoalKey(meal));
              } else {
                await repository.set(mealCalorieGoalKey(meal), '$value');
              }
              ref.invalidate(mealCalorieGoalsProvider);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (_) {
              if (dialogContext.mounted) {
                setDialogState(
                  () => error = _copy(context, 'Could not save changes.'),
                );
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
              }
            }
          }

          return PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: Text(_copy(context, meal)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    enabled: !saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(suffixText: 'kcal'),
                  ),
                  if (saving) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => commit(''),
                  child: Text(_copy(context, 'Clear')),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () => commit(controller.text.trim()),
                  child: Text(_copy(context, 'Save')),
                ),
              ],
            ),
          );
        },
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    controller.dispose();
  }
}

class MealMacroDisplayPage extends ConsumerStatefulWidget {
  const MealMacroDisplayPage({super.key});

  @override
  ConsumerState<MealMacroDisplayPage> createState() =>
      _MealMacroDisplayPageState();
}

class _MealMacroDisplayPageState extends ConsumerState<MealMacroDisplayPage> {
  bool saving = false;
  Object? saveError;

  @override
  Widget build(BuildContext context) {
    final title = _copy(context, 'Macros by meal');
    return PopScope(
      canPop: !saving,
      child: VerifiedPremiumFeatureGate(
        title: title,
        child: Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ref
              .watch(mealMacroDisplayProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: TextButton.icon(
                    onPressed: () => ref.invalidate(mealMacroDisplayProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_copy(context, 'Retry')),
                  ),
                ),
                data: (value) => ListView(
                  children: [
                    SwitchListTile.adaptive(
                      title: Text(
                        _copy(context, 'Show carbs, protein and fat by meal'),
                      ),
                      value: value.enabled,
                      onChanged: saving
                          ? null
                          : (enabled) => _save(enabled, value.mode),
                    ),
                    RadioGroup<MealMacroDisplayMode>(
                      groupValue: value.mode,
                      onChanged: (mode) {
                        if (value.enabled && !saving && mode != null) {
                          _save(true, mode);
                        }
                      },
                      child: Column(
                        children: [
                          RadioListTile(
                            value: MealMacroDisplayMode.grams,
                            title: Text(_copy(context, 'Grams')),
                          ),
                          RadioListTile(
                            value: MealMacroDisplayMode.percent,
                            title: Text(_copy(context, 'Percent')),
                          ),
                        ],
                      ),
                    ),
                    if (saving) const LinearProgressIndicator(),
                    if (saveError != null)
                      ListTile(
                        leading: const Icon(Icons.error_outline_rounded),
                        title: Text(_copy(context, 'Could not save changes.')),
                      ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Future<void> _save(bool enabled, MealMacroDisplayMode mode) async {
    if (saving) return;
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      await ref.read(preferencesRepositoryProvider).setMany({
        mealMacroDisplayEnabledKey: '$enabled',
        mealMacroDisplayModeKey: mode.name,
      });
      ref.invalidate(mealMacroDisplayProvider);
    } catch (error) {
      if (mounted) setState(() => saveError = error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

String _copy(BuildContext context, String key) {
  final locale = Localizations.localeOf(context);
  final language = locale.languageCode;
  return _copies[language]?[key] ??
      RuntimeCopy.resolve(key, locale.toLanguageTag()) ??
      key;
}

const _copies = <String, Map<String, String>>{
  'en': {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snack',
  },
  'ar': {
    'Retry subscription check': 'إعادة التحقق من الاشتراك',
    'This is an independent Premium feature.': 'هذه ميزة Premium مستقلة.',
    'View Premium plans': 'عرض خطط Premium',
    'Calorie goals by meal': 'أهداف السعرات حسب الوجبة',
    'Set a separate calorie goal for each meal.':
        'حدّد هدف سعرات مستقلًا لكل وجبة.',
    'No meal goal': 'لا يوجد هدف للوجبة',
    'breakfast': 'الإفطار',
    'lunch': 'الغداء',
    'dinner': 'العشاء',
    'snack': 'وجبة خفيفة',
    'Clear': 'مسح',
    'Save': 'حفظ',
    'Retry': 'إعادة المحاولة',
    'Enter 100 to 10000 kcal.': 'أدخل من 100 إلى 10000 سعرة.',
    'Could not save changes.': 'تعذر حفظ التغييرات.',
    'Macros by meal': 'العناصر الكبرى حسب الوجبة',
    'Show carbs, protein and fat by meal':
        'عرض الكربوهيدرات والبروتين والدهون حسب الوجبة',
    'Grams': 'غرامات',
    'Percent': 'نسبة مئوية',
  },
};
