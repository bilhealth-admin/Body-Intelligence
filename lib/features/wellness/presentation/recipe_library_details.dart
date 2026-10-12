part of 'recipe_library_page.dart';

class _RecipeDetails extends StatelessWidget {
  const _RecipeDetails({required this.detail, required this.imageResult});

  final RecipeCatalogDetail detail;
  final Future<WellnessMediaCacheResult>? imageResult;

  @override
  Widget build(BuildContext context) {
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final resolved = detail.resolveLocalization(locale);
    final displayTitle = detail.summary.resolveTitle(locale);
    final localization = resolved.value;
    final record = detail.record;
    final ingredients = (localization['ingredients'] as List).cast<String>();
    final sourceIngredients = (detail.record['ingredients'] as List)
        .cast<Map<String, dynamic>>();
    final steps = (localization['steps'] as List).cast<String>();
    final contentLanguageMismatch = [...ingredients, ...steps].any(
      (value) =>
          _directionForText(value) != _directionForLocale(resolved.locale),
    );
    final nutrition = record['nutrition'] as Map<String, dynamic>;
    final ingredientsEvidenceComplete =
        !RecipeIngredientEvidence.recordNeedsReview(record);
    final perServing = nutrition['perServing'] as Map<String, dynamic>;
    final cardFacts = RecipeCatalogCardFacts.fromDetail(detail);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      minChildSize: .6,
      maxChildSize: .96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _RecipeArtwork(
                recipe: detail.summary,
                title: displayTitle.text,
                imageResult: imageResult,
                useOriginalDecodeSize: true,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            displayTitle.text,
            locale: BilLocalePolicy.localeFromTag(displayTitle.locale),
            textDirection: _directionForLocale(displayTitle.locale),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (resolved.isFallback || contentLanguageMismatch) ...[
            const SizedBox(height: 6),
            Text(
              wellnessCopy(
                context,
                contentLanguageMismatch
                    ? 'Some recipe details remain in their source language; each line is displayed in its correct reading direction.'
                    : 'Shown in the original language (${resolved.locale.toUpperCase()}); this recipe is not translated into your app language.',
                contentLanguageMismatch
                    ? 'بعض تفاصيل الوصفة ما زالت بلغتها المصدرية؛ يُعرض كل سطر باتجاه القراءة الصحيح.'
                    : 'تُعرض باللغة الأصلية (${resolved.locale.toUpperCase()})؛ هذه الوصفة غير مترجمة إلى لغة التطبيق.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _RecipeDetailFacts(
            minutes: detail.summary.totalMinutes,
            facts: cardFacts,
          ),
          const SizedBox(height: 14),
          Text(
            wellnessCopy(context, 'Ingredients', 'المكوّنات'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          for (
            var ingredientIndex = 0;
            ingredientIndex < ingredients.length;
            ingredientIndex++
          )
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Directionality(
                textDirection: _directionForText(ingredients[ingredientIndex]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ${ingredients[ingredientIndex]}',
                      locale: BilLocalePolicy.localeFromTag(
                        _localeForText(
                          ingredients[ingredientIndex],
                          resolved.locale,
                        ),
                      ),
                    ),
                    if (ingredientIndex < sourceIngredients.length)
                      Text(
                        '${context.strings.number(sourceIngredients[ingredientIndex]['grams'] as num)} '
                        '${FoodPresentationLocalizer.servingUnit('g', locale)} · '
                        '${RecipeSourceCopy.state(sourceIngredients[ingredientIndex]['sourcePreparation'] as String? ?? 'as-sold', locale)}',
                        style: Theme.of(context).textTheme.bodySmall,
                        textDirection: _directionForLocale(locale),
                      ),
                  ],
                ),
              ),
            ),
          RecipeSourceDisclosure(ingredients: sourceIngredients),
          const SizedBox(height: 18),
          Text(
            wellnessCopy(context, 'Method', 'الطريقة'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          for (var index = 0; index < steps.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Directionality(
                textDirection: _directionForText(steps[index]),
                child: Text(
                  '${index + 1}. ${steps[index]}',
                  locale: BilLocalePolicy.localeFromTag(
                    _localeForText(steps[index], resolved.locale),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            wellnessCopy(
              context,
              ingredientsEvidenceComplete
                  ? 'Calculated values with complete ingredient record links'
                  : 'Nutrition values need review.',
              ingredientsEvidenceComplete
                  ? 'قيم محسوبة مع اكتمال روابط سجلات المكوّنات'
                  : 'القيم الغذائية تحتاج إلى مراجعة.',
            ),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: _directionForLocale(locale),
            child: Text(
              _nutritionLine(
                context,
                ingredientsEvidenceComplete ? perServing : const {},
              ),
              textAlign: TextAlign.start,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            wellnessCopy(
              context,
              'Review ingredients and serving size before logging. User confirmation is not professional nutrition verification.',
              'راجع المكوّنات وحجم الحصة قبل التسجيل. تأكيد المستخدم ليس تحققًا غذائيًا مهنيًا.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TrustedRecipeImportPage(
                    initialDraft: CatalogRecipeDraft.fromDetail(detail, locale),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(
              wellnessCopy(
                context,
                'Review and save recipe',
                'راجع الوصفة واحفظها',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
