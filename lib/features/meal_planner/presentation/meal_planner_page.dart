import '../../../shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_expansion_indicator.dart';
import '../../../shared/widgets/bil_pearl_material.dart';
import '../../../shared/widgets/bil_navigation_feedback.dart';
import 'dart:convert';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../data/repositories/preferences_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../profile/providers/user_profile_provider.dart';
import '../domain/meal_plan.dart';
import '../services/meal_plan_engine.dart';
import '../../nutrition/domain/dietary_preferences.dart';

part 'meal_planner_copy.dart';
part 'meal_planner_persistence.dart';

class MealPlannerPage extends ConsumerStatefulWidget {
  const MealPlannerPage({super.key});

  @override
  ConsumerState<MealPlannerPage> createState() => _MealPlannerPageState();
}

class _MealPlannerPageState extends ConsumerState<MealPlannerPage> {
  static const _readTimeout = Duration(seconds: 12);
  static const _preferencesKey = 'mealPlanner.preferences.v1';
  static const _planKey = 'mealPlanner.week.v1';
  static const _groceryChecksKey = 'mealPlanner.groceryChecks.v1';
  final _engine = const MealPlanEngine();
  MealPlanPreferences _preferences = const MealPlanPreferences();
  // Snapshot used to generate the saved week. Form edits are draft-only.
  MealPlanPreferences _planPreferences = const MealPlanPreferences();
  DietaryPreferences _dietaryPreferences = const DietaryPreferences();
  WeeklyMealPlan? _plan;
  var _loading = true;
  var _saving = false;
  var _loadInFlight = false;
  var _grocerySaveInFlight = false;
  var _reviewLogNavigating = false;
  var _loadEpoch = 0;
  PreferencesRepository? _boundRepository;
  Map<String, String?>? _readSnapshot;
  String? _loadError;
  String? _saveError;
  final _checkedGrocery = <String>{};

  void _updateMealPlannerState(VoidCallback update) {
    if (!mounted) return;
    setState(update);
  }

  @override
  void initState() {
    super.initState();
    _boundRepository = ref.read(preferencesRepositoryProvider);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final copy = _PlannerCopy(language);
    final activeRepository = ref.watch(preferencesRepositoryProvider);
    if (!identical(activeRepository, _boundRepository) ||
        !_isActiveRepository(activeRepository)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _adoptRepository(activeRepository);
      });
      return Scaffold(
        appBar: AppBar(title: Text(copy.text('title'))),
        body: const Center(child: BilFeatureWelcomeStatus()),
      );
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(copy.text('title')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: copy.text('week')),
              Tab(text: copy.text('grocery')),
              Tab(text: copy.text('prepMode')),
              Tab(text: copy.text('preferences')),
            ],
          ),
        ),
        body: _loading && _plan == null
            ? const Center(child: BilFeatureWelcomeStatus())
            : Column(
                children: [
                  if (_loadError != null)
                    _recoverableError(
                      copy,
                      _loadError!,
                      () => _load(retry: true),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _week(copy),
                        _grocery(copy),
                        _prep(copy),
                        _preferencesView(copy),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _recoverableError(
    _PlannerCopy copy,
    String messageKey,
    VoidCallback onRetry,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: BilPearlMaterialCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(copy.text(messageKey))),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: _loadInFlight ? null : onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(copy.text('retry')),
                ),
              ),
            ],
          ),
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
        const SizedBox(height: 12),
        BilPearlMaterialCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        copy.text('sourceLabel'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  copy.text('sourceBody'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (_saveError != null) ...[
          const SizedBox(height: 12),
          _recoverableError(
            copy,
            _saveError!,
            () =>
                _saveError == 'planChanged' ? _load(retry: true) : _generate(),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('generate-weekly-meal-plan'),
          onPressed:
              _saving ||
                  _grocerySaveInFlight ||
                  _loadInFlight ||
                  _loadError != null ||
                  _saveError == 'planChanged' ||
                  _readSnapshot == null
              ? null
              : _generate,
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
            final recipe = recipeById(meal.recipeId);
            if (recipe == null) {
              return BilPearlMaterialCard(
                child: ListTile(
                  title: Text(copy.text('missingRecipe')),
                  subtitle: Text(copy.day(meal.day)),
                ),
              );
            }
            return BilPearlMaterialCard(
              child: ListTile(
                leading: CircleAvatar(child: Text('${meal.day + 1}')),
                title: Text(recipe.title),
                subtitle: Text(
                  '${copy.day(meal.day)} • ${recipe.minutes} ${copy.text('minutes')} • ${recipe.meal}',
                ),
                trailing: const BilNavigationFeedback(
                  child: Icon(Icons.chevron_right),
                ),
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
    final items = _engine.groceryList(plan, _planPreferences).entries.toList()
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
          // Do not export optimistic or stale checks before the owner-guarded
          // grocery transaction has committed or recovery has completed.
          onPressed:
              _saving ||
                  _grocerySaveInFlight ||
                  _loadInFlight ||
                  _loadError != null ||
                  _readSnapshot == null
              ? null
              : () => _shareGrocery(copy, items),
          icon: const Icon(Icons.ios_share_outlined),
          label: Text(copy.text('shareGrocery')),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => CheckboxListTile(
            value: _checkedGrocery.contains(item.key),
            onChanged:
                _saving ||
                    _grocerySaveInFlight ||
                    _loadInFlight ||
                    _loadError != null
                ? null
                : (checked) => _toggleGrocery(item.key, checked == true),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(item.key),
            subtitle: Text(_amount(item.value)),
          ),
        ),
      ],
    );
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
          final recipe = recipeById(meal.recipeId);
          final details = recipe == null
              ? null
              : plannerRecipeDetails[recipe.id];
          if (recipe == null || details == null) {
            return BilPearlMaterialCard(
              child: ListTile(
                title: Text(copy.text('missingRecipe')),
                subtitle: Text(copy.day(meal.day)),
              ),
            );
          }
          return BilPearlMaterialCard(
            child: ExpansionTile(
              title: Text('${copy.day(meal.day)} — ${recipe.title}'),
              subtitle: Text(
                '${copy.text('prep')}: ${details.prepMinutes} ${copy.text('minutes')} • '
                '${copy.text('cook')}: ${recipe.minutes} ${copy.text('minutes')}',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,

              trailing: const BilCrystalExpansionIndicator(),
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
          key: ValueKey<MealPlanDiet>(_preferences.diet),
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
          onChanged:
              _saving ||
                  _grocerySaveInFlight ||
                  _loadInFlight ||
                  _loadError != null
              ? null
              : (value) => setState(
                  () => _preferences = MealPlanPreferences(
                    diet: value!,
                    budget: _preferences.budget,
                    maxMinutes: _preferences.maxMinutes,
                    servings: _preferences.servings,
                  ),
                ),

          icon: const BilCrystalArrow(
            extent: 36,
            child: Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<MealPlanBudget>(
          key: ValueKey<MealPlanBudget>(_preferences.budget),
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
          onChanged:
              _saving ||
                  _grocerySaveInFlight ||
                  _loadInFlight ||
                  _loadError != null
              ? null
              : (value) => setState(
                  () => _preferences = MealPlanPreferences(
                    diet: _preferences.diet,
                    budget: value!,
                    maxMinutes: _preferences.maxMinutes,
                    servings: _preferences.servings,
                  ),
                ),

          icon: const BilCrystalArrow(
            extent: 36,
            child: Icon(Icons.keyboard_arrow_down_rounded),
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
          onChanged:
              _saving ||
                  _grocerySaveInFlight ||
                  _loadInFlight ||
                  _loadError != null
              ? null
              : (value) => setState(
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
          onChanged:
              _saving ||
                  _grocerySaveInFlight ||
                  _loadInFlight ||
                  _loadError != null
              ? null
              : (value) => setState(
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

  Future<void> _showRecipe(_PlannerCopy copy, PlannerRecipe recipe) async {
    final repository = _boundRepository;
    if (_reviewLogNavigating ||
        repository == null ||
        !_isActiveRepository(repository)) {
      return;
    }
    _reviewLogNavigating = true;
    var reviewRequested = false;
    final details = plannerRecipeDetails[recipe.id];
    try {
      final review = await showBilPearlBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
            ),
            child: SingleChildScrollView(
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
                      '• ${item.key}: ${_amount(item.value * _planPreferences.servings)}',
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
                      // A callback already queued by the previous frame must not
                      // pop another route or start a second diary journey.
                      if (reviewRequested || !_isActiveRepository(repository)) {
                        return;
                      }
                      reviewRequested = true;
                      Navigator.of(sheetContext).pop(true);
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
          ),
        ),
      );
      // This shared presenter completes after the closing sheet AND barrier
      // are removed. Pushing from its pop callback races two Navigators on iOS.
      if (review != true || !mounted || !_isActiveRepository(repository)) {
        return;
      }
      // A recipe is only a search hint. Nothing is eaten/logged until the
      // member chooses a canonical diary food and confirms its portion.
      await context.push(
        Uri(
          path: '/daily-log',
          queryParameters: {
            'action': 'food',
            'focus': 'meal',
            'meal': recipe.meal.toLowerCase(),
            'query': recipe.title,
          },
        ).toString(),
      );
    } finally {
      _reviewLogNavigating = false;
    }
  }

  String _amount(double value) => value == value.roundToDouble()
      ? '${value.toInt()}'
      : value.toStringAsFixed(1);
}
