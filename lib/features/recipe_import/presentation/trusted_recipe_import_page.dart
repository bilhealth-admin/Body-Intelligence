import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
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
  bool _confirmed = false;
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
    final rows = await ref.read(trustedRecipeRepositoryProvider).load();
    final matches = rows.where((row) => row.id == widget.recipeId);
    if (matches.isEmpty || !mounted) return;
    await _setDraft(matches.single.recipe);
  }

  String _text(String english) => context.strings.text(english);
  String get _locale =>
      BilLocalePolicy.canonicalTag(Localizations.localeOf(context));
  String _unit(String unit) =>
      FoodPresentationLocalizer.servingUnit(unit, _locale);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.strings.text(
            widget.recipeId == null ? 'Create recipe' : 'Edit recipe',
          ),
        ),
        centerTitle: true,
      ),
      body: _draft == null ? _input() : _review(_draft!),
    );
  }

  Widget _input() => RecipeDraftForm(initial: _formDraft, onReview: _setDraft);

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
      if (recipe.sourceUrl != null) Text(recipe.sourceUrl.toString()),
      const SizedBox(height: 20),
      Text(
        _text('Ingredients'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      for (final item in recipe.ingredients)
        ListTile(
          dense: true,
          title: Text(
            FoodPresentationLocalizer.foodName(
              name: item.name,
              localeTag: _locale,
              isCustom: widget.initialDraft == null,
            ),
          ),
          subtitle: _matchFor(item)?.foodName == null
              ? null
              : Text(
                  FoodPresentationLocalizer.foodName(
                    name: _matchFor(item)!.foodName!,
                    localeTag: _locale,
                  ),
                ),
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
      Card(
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
      const SizedBox(height: 18),
      if (widget.initialDraft != null) ...[
        CheckboxListTile(
          key: const Key('confirm-reviewed-recipe-evidence'),
          value: _confirmed,
          onChanged: _allResolved
              ? (value) => setState(() => _confirmed = value == true)
              : null,
          title: Text(
            context.strings.text(
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
    final matches = await TrustedRecipeIngredientReconciler(
      ref.read(foodRuntimeSearchAuthorityProvider),
    ).reconcile(draft);
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _formDraft = draft;
      _matches = matches;
      _confirmed = false;
      _error = null;
    });
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
      final readback = await repository.load();
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
      '${context.strings.get('protein')} ${_number(value.proteinG)} ${_unit('g')} · '
      '${context.strings.get('carbs')} ${_number(value.carbohydrateG)} ${_unit('g')} · '
      '${context.strings.get('fat')} ${_number(value.fatG)} ${_unit('g')}\n'
      '${_text('Source')}: ${value.provenance.source} (${value.provenance.recordId})';
}
