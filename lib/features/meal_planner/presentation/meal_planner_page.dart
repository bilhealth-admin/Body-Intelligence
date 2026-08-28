import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../profile/providers/user_profile_provider.dart';
import '../domain/meal_plan.dart';
import '../services/meal_plan_engine.dart';
import '../../nutrition/domain/dietary_preferences.dart';

part 'meal_planner_copy.dart';

class MealPlannerPage extends ConsumerStatefulWidget {
  const MealPlannerPage({super.key});

  @override
  ConsumerState<MealPlannerPage> createState() => _MealPlannerPageState();
}

class _MealPlannerPageState extends ConsumerState<MealPlannerPage> {
  static const _preferencesKey = 'mealPlanner.preferences.v1';
  static const _planKey = 'mealPlanner.week.v1';
  static const _groceryChecksKey = 'mealPlanner.groceryChecks.v1';
  final _engine = const MealPlanEngine();
  MealPlanPreferences _preferences = const MealPlanPreferences();
  DietaryPreferences _dietaryPreferences = const DietaryPreferences();
  WeeklyMealPlan? _plan;
  var _loading = true;
  var _saving = false;
  final _checkedGrocery = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(preferencesRepositoryProvider);
    try {
      final values = await Future.wait([
        repository.get(_preferencesKey),
        repository.get(_planKey),
        repository.get(_groceryChecksKey),
      ]);
      final dietary = await ref
          .read(dietaryPreferencesRepositoryProvider)
          .read();
      if (!mounted) return;
      setState(() {
        final preferences = values[0];
        _dietaryPreferences = dietary;
        final plan = values[1];
        if (preferences != null) {
          _preferences = MealPlanPreferences.fromJson(
            jsonDecode(preferences) as Map<String, dynamic>,
          );
        }
        if (plan != null) _plan = WeeklyMealPlan.decode(plan);
        final checks = values[2];
        if (checks != null) {
          _checkedGrocery
            ..clear()
            ..addAll((jsonDecode(checks) as List).cast<String>());
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _saving = true);
    final plan = _engine.generate(
      _preferences,
      dietaryPreferences: _dietaryPreferences,
    );
    try {
      final repository = ref.read(preferencesRepositoryProvider);
      await repository.set(_preferencesKey, jsonEncode(_preferences.toJson()));
      await repository.set(_planKey, plan.encode());
      await repository.remove(_groceryChecksKey);
      if (mounted) {
        setState(() {
          _plan = plan;
          _checkedGrocery.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final copy = _PlannerCopy(language);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(copy.text('title')),
          bottom: TabBar(
            tabs: [
              Tab(text: copy.text('week')),
              Tab(text: copy.text('grocery')),
              Tab(text: copy.text('prepMode')),
              Tab(text: copy.text('preferences')),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _week(copy),
                  _grocery(copy),
                  _prep(copy),
                  _preferencesView(copy),
                ],
              ),
      ),
    );
  }

  Widget _week(_PlannerCopy copy) {
    final plan = _plan;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          copy.text('hero'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(copy.text('heroBody')),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('generate-weekly-meal-plan'),
          onPressed: _saving ? null : _generate,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: Text(_saving ? copy.text('saving') : copy.text('generate')),
        ),
        if (plan == null) ...[
          const SizedBox(height: 36),
          Icon(
            Icons.calendar_month_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(copy.text('empty'), textAlign: TextAlign.center),
        ] else if (plan.meals.isEmpty) ...[
          const SizedBox(height: 28),
          Icon(
            Icons.no_meals_outlined,
            size: 52,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(copy.text('noDietaryMatch'), textAlign: TextAlign.center),
        ] else ...[
          const SizedBox(height: 20),
          ...plan.meals.map((meal) {
            final recipe = recipeById(meal.recipeId)!;
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${meal.day + 1}')),
                title: Text(recipe.title),
                subtitle: Text(
                  '${copy.day(meal.day)} • ${recipe.minutes} ${copy.text('minutes')} • ${recipe.meal}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showRecipe(copy, recipe),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _grocery(_PlannerCopy copy) {
    final plan = _plan;
    if (plan == null) return Center(child: Text(copy.text('generateFirst')));
    final items = _engine.groceryList(plan, _preferences).entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          copy.text('groceryTitle'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(copy.text('groceryBody')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('share-meal-plan-grocery-list'),
          onPressed: () => _shareGrocery(copy, items),
          icon: const Icon(Icons.ios_share_outlined),
          label: Text(copy.text('shareGrocery')),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => CheckboxListTile(
            value: _checkedGrocery.contains(item.key),
            onChanged: (checked) => _toggleGrocery(item.key, checked == true),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(item.key),
            subtitle: Text(_amount(item.value)),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleGrocery(String key, bool checked) async {
    final wasChecked = _checkedGrocery.contains(key);
    setState(() {
      checked ? _checkedGrocery.add(key) : _checkedGrocery.remove(key);
    });
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .set(_groceryChecksKey, jsonEncode(_checkedGrocery.toList()..sort()));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        wasChecked ? _checkedGrocery.add(key) : _checkedGrocery.remove(key);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _PlannerCopy(
              Localizations.localeOf(context).languageCode,
            ).text('saveFailed'),
          ),
        ),
      );
    }
  }

  Future<void> _shareGrocery(
    _PlannerCopy copy,
    List<MapEntry<String, double>> items,
  ) async {
    final lines = <String>[
      copy.text('groceryTitle'),
      '',
      ...items.map(
        (item) =>
            '${_checkedGrocery.contains(item.key) ? '✓' : '☐'} ${item.key}: ${_amount(item.value)}',
      ),
      '',
      copy.text('shareNotice'),
    ];
    try {
      await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.text('shareFailed'))));
    }
  }

  Widget _prep(_PlannerCopy copy) {
    final plan = _plan;
    if (plan == null) return Center(child: Text(copy.text('generateFirst')));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          copy.text('prepTitle'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(copy.text('prepBody')),
        const SizedBox(height: 12),
        ...plan.meals.map((meal) {
          final recipe = recipeById(meal.recipeId)!;
          final details = plannerRecipeDetails[recipe.id]!;
          return Card(
            child: ExpansionTile(
              title: Text('${copy.day(meal.day)} — ${recipe.title}'),
              subtitle: Text(
                '${copy.text('prep')}: ${details.prepMinutes} ${copy.text('minutes')} • '
                '${copy.text('cook')}: ${recipe.minutes} ${copy.text('minutes')}',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: details.steps.indexed
                  .map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${step.$1 + 1}. ${step.$2}'),
                    ),
                  )
                  .toList(growable: false),
            ),
          );
        }),
      ],
    );
  }

  Widget _preferencesView(_PlannerCopy copy) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          copy.text('preferencesTitle'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<MealPlanDiet>(
          initialValue: _preferences.diet,
          decoration: InputDecoration(labelText: copy.text('diet')),
          items: MealPlanDiet.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(copy.diet(value)),
                ),
              )
              .toList(),
          onChanged: (value) => setState(
            () => _preferences = MealPlanPreferences(
              diet: value!,
              budget: _preferences.budget,
              maxMinutes: _preferences.maxMinutes,
              servings: _preferences.servings,
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<MealPlanBudget>(
          initialValue: _preferences.budget,
          decoration: InputDecoration(labelText: copy.text('budget')),
          items: MealPlanBudget.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(copy.budget(value)),
                ),
              )
              .toList(),
          onChanged: (value) => setState(
            () => _preferences = MealPlanPreferences(
              diet: _preferences.diet,
              budget: value!,
              maxMinutes: _preferences.maxMinutes,
              servings: _preferences.servings,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${copy.text('maxTime')}: ${_preferences.maxMinutes} ${copy.text('minutes')}',
        ),
        Slider(
          value: _preferences.maxMinutes.toDouble(),
          min: 10,
          max: 60,
          divisions: 10,
          onChanged: (value) => setState(
            () => _preferences = MealPlanPreferences(
              diet: _preferences.diet,
              budget: _preferences.budget,
              maxMinutes: value.round(),
              servings: _preferences.servings,
            ),
          ),
        ),
        Text('${copy.text('servings')}: ${_preferences.servings}'),
        Slider(
          value: _preferences.servings.toDouble(),
          min: 1,
          max: 8,
          divisions: 7,
          onChanged: (value) => setState(
            () => _preferences = MealPlanPreferences(
              diet: _preferences.diet,
              budget: _preferences.budget,
              maxMinutes: _preferences.maxMinutes,
              servings: value.round(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(copy.text('safety'), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  void _showRecipe(_PlannerCopy copy, PlannerRecipe recipe) {
    final details = plannerRecipeDetails[recipe.id];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              recipe.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            ...recipe.ingredients.entries.map(
              (item) => Text(
                '• ${item.key}: ${_amount(item.value * _preferences.servings)}',
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: 12),
              Text(
                '${copy.text('prep')}: ${details.prepMinutes} ${copy.text('minutes')} • '
                '${copy.text('cook')}: ${recipe.minutes} ${copy.text('minutes')}',
              ),
              const SizedBox(height: 10),
              Text(
                '${details.calories.toStringAsFixed(0)} kcal • '
                'P ${details.protein.toStringAsFixed(0)} g • '
                'C ${details.carbs.toStringAsFixed(0)} g • '
                'F ${details.fat.toStringAsFixed(0)} g',
              ),
              Text(
                '${copy.text('fiber')} ${details.fiber.toStringAsFixed(0)} g • '
                '${copy.text('sugar')} ${details.sugar.toStringAsFixed(0)} g • '
                '${copy.text('sodium')} ${details.sodium.toStringAsFixed(0)} mg • '
                '${copy.text('potassium')} ${details.potassium.toStringAsFixed(0)} mg',
              ),
              const SizedBox(height: 12),
              ...details.steps.indexed.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${step.$1 + 1}. ${step.$2}'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy.text('estimateNotice'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.push('/daily-log?action=food');
              },
              child: Text(copy.text('reviewLog')),
            ),
            const SizedBox(height: 8),
            Text(
              copy.text('logNotice'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _amount(double value) => value == value.roundToDouble()
      ? '${value.toInt()}'
      : value.toStringAsFixed(1);
}
