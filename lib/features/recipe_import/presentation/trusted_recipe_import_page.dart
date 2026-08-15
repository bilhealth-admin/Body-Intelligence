import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trusted_recipe.dart';
import '../providers/trusted_recipe_providers.dart';
import '../repositories/trusted_recipe_repository.dart';
import '../services/trusted_recipe_parser.dart';
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
  final _controller = TextEditingController();
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
        _controller.text = jsonEncode(widget.initialDraft!.toJson());
        return _setDraft(widget.initialDraft!);
      });
    }
  }

  Future<void> _loadExisting() async {
    final rows = await ref.read(trustedRecipeRepositoryProvider).load();
    final matches = rows.where((row) => row.id == widget.recipeId);
    if (matches.isEmpty || !mounted) return;
    _controller.text = jsonEncode(matches.single.recipe.toJson());
    await _setDraft(matches.single.recipe);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _ImportCopy get copy =>
      _copies[Localizations.localeOf(context).languageCode] ?? _copies['en']!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(copy.title), centerTitle: true),
      body: _draft == null ? _input() : _review(_draft!),
    );
  }

  Widget _input() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(copy.inputBody, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 16),
      TextField(
        key: const Key('trusted-recipe-input'),
        controller: _controller,
        minLines: 12,
        maxLines: 24,
        autocorrect: false,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          hintText: copy.hint,
          errorText: _error,
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('review-imported-recipe'),
        onPressed: _parse,
        icon: const Icon(Icons.fact_check_outlined),
        label: Text(copy.review),
      ),
      const SizedBox(height: 12),
      Text(copy.offlineNotice, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  Widget _review(TrustedRecipeDraft recipe) => ListView(
    key: const Key('trusted-recipe-review'),
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        copy.reviewTitle,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(recipe.name, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        copy.summary(recipe.servings, recipe.prepMinutes, recipe.cookMinutes),
      ),
      if (recipe.sourceUrl != null) Text(recipe.sourceUrl.toString()),
      const SizedBox(height: 20),
      Text(copy.ingredients, style: Theme.of(context).textTheme.titleMedium),
      for (final item in recipe.ingredients)
        ListTile(
          dense: true,
          title: Text(item.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_number(item.quantity)} ${item.unit}'),
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
      Text(copy.steps, style: Theme.of(context).textTheme.titleMedium),
      for (var index = 0; index < recipe.steps.length; index++)
        ListTile(
          dense: true,
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text(recipe.steps[index]),
        ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: Icon(
            recipe.nutrition == null
                ? Icons.info_outline
                : Icons.verified_outlined,
          ),
          title: Text(
            recipe.nutrition == null
                ? copy.noNutrition
                : copy.verifiedNutrition,
          ),
          subtitle: recipe.nutrition == null
              ? Text(copy.noNutritionBody)
              : Text(copy.nutrition(recipe.nutrition!)),
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
          title: const Text(
            'I reviewed the ingredients, serving size, and source links.',
          ),
          subtitle: Text(
            _allResolved
                ? 'This is your confirmation, not professional nutrition verification.'
                : 'One or more ingredients still need an exact food-record match.',
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
        child: Text(copy.save),
      ),
      TextButton(
        onPressed: _saving ? null : () => setState(() => _draft = null),
        child: Text(copy.edit),
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );

  void _parse() {
    try {
      final draft = TrustedRecipeParser.parse(_controller.text);
      _setDraft(draft);
    } on TrustedRecipeParseException catch (error) {
      setState(() => _error = copy.error(error.code));
    }
  }

  Future<void> _setDraft(TrustedRecipeDraft draft) async {
    final matches = await TrustedRecipeIngredientReconciler(
      ref.read(foodRuntimeSearchAuthorityProvider),
    ).reconcile(draft);
    if (!mounted) return;
    setState(() {
      _draft = draft;
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
      if (mounted) setState(() => _error = copy.duplicate);
    } on Object {
      if (mounted) setState(() => _error = copy.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _number(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(2);
}

final class _ImportCopy {
  const _ImportCopy({
    required this.title,
    required this.inputBody,
    required this.hint,
    required this.review,
    required this.offlineNotice,
    required this.reviewTitle,
    required this.ingredients,
    required this.steps,
    required this.noNutrition,
    required this.noNutritionBody,
    required this.verifiedNutrition,
    required this.save,
    required this.edit,
    required this.duplicate,
    required this.saveFailed,
    required this.words,
  });
  final String title,
      inputBody,
      hint,
      review,
      offlineNotice,
      reviewTitle,
      ingredients,
      steps,
      noNutrition,
      noNutritionBody,
      verifiedNutrition,
      save,
      edit,
      duplicate,
      saveFailed;
  final Map<String, String> words;
  String error(String code) => words[code] ?? words['invalid']!;
  String summary(int servings, int prep, int cook) =>
      '${words['servings']}: $servings · ${words['prep']}: $prep min · ${words['cook']}: $cook min';
  String nutrition(TrustedRecipeNutrition value) =>
      '${value.caloriesKcal.round()} kcal · P ${value.proteinG} g · C ${value.carbohydrateG} g · F ${value.fatG} g\n${words['source']}: ${value.provenance.source} (${value.provenance.recordId})';
}

const _copies = <String, _ImportCopy>{
  'en': _ImportCopy(
    title: 'Import recipe',
    inputBody:
        'Paste recipe JSON. A web URL alone is never fetched in local mode.',
    hint: '{"name":"...","servings":2,...}',
    review: 'Review recipe',
    offlineNotice:
        'Nothing is saved until you review and confirm. Nutrition requires source provenance.',
    reviewTitle: 'Review before saving',
    ingredients: 'Ingredients',
    steps: 'Method',
    noNutrition: 'Nutrition not included',
    noNutritionBody: 'No nutrition values will be inferred or invented.',
    verifiedNutrition: 'Nutrition with provenance',
    save: 'Save reviewed recipe',
    edit: 'Back to edit',
    duplicate: 'This recipe is already saved.',
    saveFailed: 'The recipe could not be saved.',
    words: {
      'url_fetch_disabled':
          'URL fetching is disabled. Paste exported recipe JSON instead.',
      'nutrition_provenance_required':
          'Nutrition was rejected because provenance is missing.',
      'invalid':
          'Check the required fields, quantities, units, times, and steps.',
      'servings': 'Servings',
      'prep': 'Prep',
      'cook': 'Cook',
      'source': 'Source',
    },
  ),
  'ar': _ImportCopy(
    title: 'استيراد وصفة',
    inputBody: 'الصق JSON للوصفة. لا يُجلب رابط الويب وحده في الوضع المحلي.',
    hint: '{"name":"...","servings":2,...}',
    review: 'مراجعة الوصفة',
    offlineNotice:
        'لن يُحفظ شيء قبل المراجعة والتأكيد. التغذية تتطلب مصدرًا موثقًا.',
    reviewTitle: 'راجع قبل الحفظ',
    ingredients: 'المكونات',
    steps: 'الطريقة',
    noNutrition: 'لا توجد قيم غذائية',
    noNutritionBody: 'لن نستنتج أو نفبرك أي قيم غذائية.',
    verifiedNutrition: 'تغذية ذات مصدر موثق',
    save: 'حفظ الوصفة المراجعة',
    edit: 'العودة للتعديل',
    duplicate: 'هذه الوصفة محفوظة بالفعل.',
    saveFailed: 'تعذر حفظ الوصفة.',
    words: {
      'url_fetch_disabled': 'جلب الروابط معطل. الصق JSON المصدر للوصفة.',
      'nutrition_provenance_required': 'رُفضت التغذية لعدم وجود مصدر موثق.',
      'invalid': 'تحقق من الحقول والكميات والوحدات والأوقات والخطوات.',
      'servings': 'الحصص',
      'prep': 'التحضير',
      'cook': 'الطهي',
      'source': 'المصدر',
    },
  ),
  'fr': _ImportCopy(
    title: 'Importer une recette',
    inputBody:
        'Collez le JSON. Une URL seule n’est jamais récupérée en mode local.',
    hint: '{"name":"...","servings":2,...}',
    review: 'Vérifier la recette',
    offlineNotice:
        'Rien n’est enregistré avant validation. La nutrition exige une provenance.',
    reviewTitle: 'Vérifier avant d’enregistrer',
    ingredients: 'Ingrédients',
    steps: 'Préparation',
    noNutrition: 'Nutrition non incluse',
    noNutritionBody: 'Aucune valeur nutritionnelle ne sera inventée.',
    verifiedNutrition: 'Nutrition avec provenance',
    save: 'Enregistrer la recette vérifiée',
    edit: 'Retour à la modification',
    duplicate: 'Cette recette est déjà enregistrée.',
    saveFailed: 'Impossible d’enregistrer la recette.',
    words: {
      'url_fetch_disabled':
          'La récupération d’URL est désactivée. Collez le JSON exporté.',
      'nutrition_provenance_required':
          'Nutrition rejetée : provenance manquante.',
      'invalid': 'Vérifiez les champs, quantités, unités, durées et étapes.',
      'servings': 'Portions',
      'prep': 'Préparation',
      'cook': 'Cuisson',
      'source': 'Source',
    },
  ),
  'es': _ImportCopy(
    title: 'Importar receta',
    inputBody: 'Pega el JSON. Una URL sola nunca se descarga en modo local.',
    hint: '{"name":"...","servings":2,...}',
    review: 'Revisar receta',
    offlineNotice:
        'Nada se guarda sin revisión. La nutrición exige procedencia.',
    reviewTitle: 'Revisar antes de guardar',
    ingredients: 'Ingredientes',
    steps: 'Preparación',
    noNutrition: 'Nutrición no incluida',
    noNutritionBody: 'No se inferirán ni inventarán valores.',
    verifiedNutrition: 'Nutrición con procedencia',
    save: 'Guardar receta revisada',
    edit: 'Volver a editar',
    duplicate: 'Esta receta ya está guardada.',
    saveFailed: 'No se pudo guardar la receta.',
    words: {
      'url_fetch_disabled':
          'La descarga de URL está desactivada. Pega el JSON exportado.',
      'nutrition_provenance_required':
          'Nutrición rechazada: falta procedencia.',
      'invalid': 'Revisa campos, cantidades, unidades, tiempos y pasos.',
      'servings': 'Porciones',
      'prep': 'Preparación',
      'cook': 'Cocción',
      'source': 'Fuente',
    },
  ),
  'tr': _ImportCopy(
    title: 'Tarif içe aktar',
    inputBody:
        'Tarif JSON verisini yapıştırın. Yerel modda URL tek başına alınmaz.',
    hint: '{"name":"...","servings":2,...}',
    review: 'Tarifi incele',
    offlineNotice:
        'İnceleyip onaylamadan kaydedilmez. Besin değerleri kaynak kanıtı gerektirir.',
    reviewTitle: 'Kaydetmeden önce incele',
    ingredients: 'Malzemeler',
    steps: 'Yapılışı',
    noNutrition: 'Besin değeri eklenmedi',
    noNutritionBody: 'Hiçbir besin değeri tahmin veya uydurma olmayacak.',
    verifiedNutrition: 'Kaynaklı besin değerleri',
    save: 'İncelenen tarifi kaydet',
    edit: 'Düzenlemeye dön',
    duplicate: 'Bu tarif zaten kayıtlı.',
    saveFailed: 'Tarif kaydedilemedi.',
    words: {
      'url_fetch_disabled':
          'URL alma kapalı. Dışa aktarılan JSON verisini yapıştırın.',
      'nutrition_provenance_required':
          'Kaynak kanıtı olmadığı için besin değerleri reddedildi.',
      'invalid':
          'Alanları, miktarları, birimleri, süreleri ve adımları kontrol edin.',
      'servings': 'Porsiyon',
      'prep': 'Hazırlık',
      'cook': 'Pişirme',
      'source': 'Kaynak',
    },
  ),
};
