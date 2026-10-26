import '../../../shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_expansion_indicator.dart';
import '../../../shared/widgets/bil_pearl_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'recipe_editor_copy.dart';
import '../../nutrition/presentation/nutrition_food_picker.dart';
import '../services/recipe_nutrition_calculator.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/database/database_scope.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../nutrition/services/food_presentation_localizer.dart';
import '../domain/trusted_recipe.dart';
import '../providers/trusted_recipe_providers.dart';
import '../repositories/trusted_recipe_repository.dart';
import 'recipe_draft_form.dart';
import '../services/trusted_recipe_ingredient_reconciler.dart';
import '../../foods/providers/food_provider.dart';

class TrustedRecipeImportPage extends ConsumerStatefulWidget {
  const TrustedRecipeImportPage({this.recipeId, this.initialDraft, super.key})
    : assert(recipeId == null || initialDraft == null);
  final String? recipeId;
  final TrustedRecipeDraft? initialDraft;

  @override
  ConsumerState<TrustedRecipeImportPage> createState() =>
      _TrustedRecipeImportPageState();
}

class _TrustedRecipeImportPageState
    extends ConsumerState<TrustedRecipeImportPage> {
  TrustedRecipeDraft? _formDraft;
  TrustedRecipeDraft? _draft;
  String? _error;
  bool _saving = false;
  bool _loading = false;
  int _generation = 0;
  bool _confirmed = false;
  bool _retired = false;
  List<TrustedIngredientMatch> _matches = const [];

  @override
  void initState() {
    super.initState();
    if (widget.recipeId != null) {
      Future<void>.microtask(_loadExisting);
    } else if (widget.initialDraft != null) {
      Future<void>.microtask(() {
        return _setDraft(widget.initialDraft!);
      });
    }
  }

  Future<void> _loadExisting() async {
    final repository = ref.read(trustedRecipeRepositoryProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await repository.load();
      if (!mounted ||
          _retired ||
          !identical(repository, ref.read(trustedRecipeRepositoryProvider))) {
        return;
      }
      final matches = rows.where((row) => row.id == widget.recipeId);
      if (matches.length != 1) throw StateError('Recipe unavailable');
      await _setDraft(matches.single.recipe);
    } on Object {
      if (mounted) {
        setState(
          () => _error = _text('Saved recipe could not be loaded. Retry.'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _text(String english) => recipeEditorText(context, english);
  String get _locale =>
      BilLocalePolicy.canonicalTag(Localizations.localeOf(context));
  String _unit(String unit) =>
      FoodPresentationLocalizer.servingUnit(unit, _locale);

  @override
  Widget build(BuildContext context) {
    ref.listen(trustedRecipeRepositoryProvider, (previous, next) {
      _retired = true;
      _generation++;
      if (mounted) {
        setState(() {
          _draft = null;
          _formDraft = null;
          _loading = false;
          _error = _text('Account changed. Reopen the recipe.');
        });
      }
    });
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _text(widget.recipeId == null ? 'Create recipe' : 'Edit recipe'),
          ),
          centerTitle: true,
        ),
        body: _loading && _draft == null
            ? const Center(child: BilFeatureWelcomeStatus())
            : _retired
            ? Center(child: Text(_error!))
            : _draft == null
            ? _input()
            : _review(_draft!),
      ),
    );
  }

  Widget _input() => Column(
    children: [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (widget.recipeId != null && _formDraft == null && _error != null)
        TextButton(onPressed: _loadExisting, child: Text(_text('Retry')))
      else
        Expanded(
          child: RecipeDraftForm(initial: _formDraft, onReview: _setDraft),
        ),
    ],
  );

  Widget _review(TrustedRecipeDraft recipe) => ListView(
    key: const Key('trusted-recipe-review'),
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        _text('Review recipe'),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(recipe.name, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        "${_text('Servings')}: ${_number(recipe.servings.toDouble())} · ${_text('Prep time (min)')}: ${_number(recipe.prepMinutes.toDouble())} · ${_text('Cook time (min)')}: ${_number(recipe.cookMinutes.toDouble())}",
      ),
      if (recipe.sourceUrl != null)
        TextButton.icon(
          icon: const Icon(Icons.menu_book_outlined, size: 19),
          onPressed: () => _openSource(recipe.sourceUrl!),
          label: Text(_text('Source')),
        ),
      const SizedBox(height: 20),
      Text(
        _text('Ingredients'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      for (final item in recipe.ingredients)
        ListTile(
          dense: true,
          onTap: _saving || _loading ? null : () => _linkIngredient(item),
          leading: IconButton(
            tooltip: _text('Source'),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            onPressed: () => _ingredientSource(item),
          ),
          title: Text(
            FoodPresentationLocalizer.foodName(
              name: item.name,
              localeTag: _locale,
              isCustom: widget.initialDraft == null,
            ),
          ),
          subtitle: _matchFor(item)?.status == IngredientMatchStatus.exact
              ? Text(_text('Linked food record'))
              : Text(_text('Tap to choose the matching food')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_number(item.quantity)} ${_unit(item.unit)}'),
              const SizedBox(width: 8),
              Icon(
                _matchFor(item)?.status == IngredientMatchStatus.exact
                    ? Icons.link_rounded
                    : _matchFor(item)?.status == IngredientMatchStatus.ambiguous
                    ? Icons.help_outline_rounded
                    : Icons.link_off_rounded,
                size: 18,
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      Text(_text('Method'), style: Theme.of(context).textTheme.titleMedium),
      for (var index = 0; index < recipe.steps.length; index++)
        ListTile(
          dense: true,
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text(recipe.steps[index]),
        ),
      const SizedBox(height: 12),
      BilPearlMaterialCard(
        child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(
            recipe.nutrition == null
                ? _text('Nutrition not included')
                : _text('Nutrition with provenance'),
          ),
          subtitle: recipe.nutrition == null
              ? Text(_text('No nutrition values will be inferred or invented.'))
              : Text(_nutrition(recipe.nutrition!)),
        ),
      ),
      if (recipe.nutrition != null)
        ExpansionTile(
          leading: const Icon(Icons.menu_book_outlined, size: 19),
          title: Text(_text('Source')),

          trailing: const BilCrystalExpansionIndicator(),
          children: [
            ListTile(
              title: SelectableText(recipe.nutrition!.provenance.source),
              subtitle: SelectableText(recipe.nutrition!.provenance.recordId),
            ),
          ],
        ),
      const SizedBox(height: 18),
      if (widget.initialDraft != null) ...[
        CheckboxListTile(
          key: const Key('confirm-reviewed-recipe-evidence'),
          value: _confirmed,
          onChanged: _allResolved
              ? (value) => setState(() => _confirmed = value == true)
              : null,
          title: Text(
            _text(
              'I reviewed the ingredients, serving size, and source links.',
            ),
          ),
          subtitle: Text(
            _allResolved
                ? _text(
                    'This is your confirmation, not professional nutrition verification.',
                  )
                : _text(
                    'One or more ingredients still need an exact food-record match.',
                  ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      FilledButton(
        key: const Key('save-reviewed-recipe'),
        onPressed:
            _saving ||
                _loading ||
                (widget.initialDraft != null && (!_allResolved || !_confirmed))
            ? null
            : _save,
        child: Text(_text('Save')),
      ),
      TextButton(
        onPressed: _saving ? null : () => setState(() => _draft = null),
        child: Text(_text('Edit')),
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );

  Future<void> _setDraft(TrustedRecipeDraft draft) async {
    if (_retired || !mounted) return;
    final generation = ++_generation;
    final authority = ref.read(foodRuntimeSearchAuthorityProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final matches = await TrustedRecipeIngredientReconciler(
        authority,
        localeTag: _locale,
      ).reconcile(draft);
      if (!mounted ||
          generation != _generation ||
          !identical(authority, ref.read(foodRuntimeSearchAuthorityProvider))) {
        return;
      }
      final calculated =
          draft.nutrition ??
          RecipeNutritionCalculator.calculate(
            draft,
            matches,
            ownerKey: LocalDatabaseScope.keyForOwner(
              ref.read(databaseProvider).localOwnerId,
            ),
          );
      final reviewed = TrustedRecipeDraft(
        name: draft.name,
        servings: draft.servings,
        prepMinutes: draft.prepMinutes,
        cookMinutes: draft.cookMinutes,
        ingredients: draft.ingredients,
        steps: draft.steps,
        sourceUrl: draft.sourceUrl,
        nutrition: calculated,
      );
      setState(() {
        _draft = reviewed;
        _formDraft = reviewed;
        _matches = matches;
        _confirmed = false;
      });
    } on Object {
      if (mounted && generation == _generation) {
        setState(() => _error = _text('The recipe could not be saved.'));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _linkIngredient(TrustedRecipeIngredient ingredient) async {
    final draft = _draft;
    if (draft == null) return;
    final food = await selectNutritionFood(
      context,
      initialQuery: ingredient.name,
    );
    if (!mounted || food == null || _draft != draft) return;
    final label = FoodPresentationLocalizer.foodName(
      name: food.name,
      arabicName: food.arabicName,
      localeTag: _locale,
      isCustom: food.isCustom,
      source: food.source,
    );
    await _setDraft(
      TrustedRecipeDraft(
        name: draft.name,
        servings: draft.servings,
        prepMinutes: draft.prepMinutes,
        cookMinutes: draft.cookMinutes,
        steps: draft.steps,
        sourceUrl: draft.sourceUrl,
        ingredients: [
          for (final row in draft.ingredients)
            identical(row, ingredient)
                ? TrustedRecipeIngredient(
                    name: label,
                    quantity: row.quantity,
                    unit: row.unit,
                    sourceRecordId: RegExp(r'^usda:\d+$').hasMatch(food.uuid)
                        ? food.uuid
                        : 'local:${food.uuid}',
                  )
                : row,
        ],
      ),
    );
  }

  Future<void> _ingredientSource(TrustedRecipeIngredient ingredient) async {
    final match = _matchFor(ingredient), id = ingredient.sourceRecordId;
    if (id != null && RegExp(r'^usda:\d+$').hasMatch(id)) {
      await _openSource(
        Uri.parse(
          'https://fdc.nal.usda.gov/food-details/${id.substring(5)}/nutrients',
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => BilPearlMaterialAlertDialog(
        title: Text(_text('Source')),
        content: SingleChildScrollView(
          child: SelectableText(
            '${match?.foodName ?? ingredient.name}\n${match?.food?.source ?? _text('No linked source')}\n'
            '${id ?? ''}\n${match?.food?.servingSize ?? ''} ${match?.food?.servingUnit ?? ''}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_text('Close')),
          ),
        ],
      ),
    );
  }

  Future<void> _openSource(Uri uri) async {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return;
    }
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Object {
      /* Visible failure below. */
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_text('Could not open link.'))));
    }
  }

  TrustedIngredientMatch? _matchFor(TrustedRecipeIngredient ingredient) {
    for (final match in _matches) {
      if (identical(match.ingredient, ingredient)) return match;
    }
    return null;
  }

  bool get _allResolved =>
      _matches.length == (_draft?.ingredients.length ?? 0) &&
      _matches.every((match) => match.status == IngredientMatchStatus.exact);

  Future<void> _save() async {
    if (_retired || _saving || _loading || _draft == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(trustedRecipeRepositoryProvider);
      late final SavedTrustedRecipe saved;
      if (widget.recipeId == null) {
        saved = await repository.saveReviewed(_draft!);
      } else {
        saved = await repository.replaceReviewed(widget.recipeId!, _draft!);
      }
      if (!mounted ||
          _retired ||
          !identical(repository, ref.read(trustedRecipeRepositoryProvider))) {
        return;
      }
      final readback = await repository.load();
      if (!mounted ||
          _retired ||
          !identical(repository, ref.read(trustedRecipeRepositoryProvider))) {
        return;
      }
      if (!readback.any(
        (row) =>
            row.id == saved.id &&
            row.recipe.fingerprint == saved.recipe.fingerprint,
      )) {
        throw StateError('Saved recipe readback failed.');
      }
      ref.invalidate(trustedRecipesProvider);
      if (mounted) Navigator.pop(context);
    } on DuplicateRecipeException {
      if (mounted) {
        setState(() => _error = _text('This recipe is already saved.'));
      }
    } on Object {
      if (mounted) {
        setState(() => _error = _text('The recipe could not be saved.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _number(double value) => context.strings.number(
    value,
    decimalDigits: value == value.roundToDouble() ? 0 : 2,
  );
  String _nutrition(TrustedRecipeNutrition value) =>
      '${_number(value.caloriesKcal)} ${_unit('kcal')} · '
      '${_text('Protein')} ${_number(value.proteinG)} ${_unit('g')} · '
      '${_text('Carbohydrates')} ${_number(value.carbohydrateG)} ${_unit('g')} · '
      '${_text('Fat')} ${_number(value.fatG)} ${_unit('g')}\n'
      '${_text('Source')}: ${_locale.startsWith('ar') ? 'محسوبة من سجلات المكونات المرتبطة' : 'Calculated from linked ingredient records'}';
}
