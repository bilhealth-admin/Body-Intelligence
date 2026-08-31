part of 'recipe_library_page.dart';

double _recipeCardExtent(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0);
  return 306 + ((scale - 1) * 106);
}

double _recipePreviewWidth(BuildContext context) =>
    (MediaQuery.sizeOf(context).width * .62).clamp(212.0, 252.0);

int _recipeColumnCount(double crossAxisExtent) {
  if (crossAxisExtent < 340) return 1;
  return ((crossAxisExtent + 12) / 232).floor().clamp(2, 6);
}

String _recipeCategoryLabel(BuildContext context, String category) {
  return switch (category) {
    'regional' => wellnessCopy(context, 'Regional', 'إقليمية'),
    'quick' => wellnessCopy(context, 'Quick', 'سريعة'),
    'plant' => wellnessCopy(context, 'Plant-forward', 'نباتية'),
    'saved' => wellnessCopy(context, 'Saved', 'محفوظة'),
    _ => wellnessCopy(context, 'All', 'الكل'),
  };
}

String _recipeCountLabel(BuildContext context, int visible, int total) {
  return context.strings
      .text('{visible} of {total} recipes')
      .replaceFirst('{visible}', context.strings.number(visible))
      .replaceFirst('{total}', context.strings.number(total));
}

String _recipeMinutesLabel(BuildContext context, int minutes) {
  return context.strings
      .text('{count} min')
      .replaceFirst('{count}', context.strings.number(minutes));
}

String _recipeServingsLabel(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'ar' => 'الحصص',
    'fr' => 'Portions',
    'es' => 'Porciones',
    'tr' => 'Porsiyon',
    'en' => 'Servings',
    _ => context.strings.text('Servings'),
  };
}

String _recipeTimeLabel(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'ar' => 'الوقت',
    'fr' => 'Durée',
    'es' => 'Tiempo',
    'tr' => 'Süre',
    'en' => 'Time',
    _ => context.strings.text('Time'),
  };
}

class _RecipeDiscoveryHeader extends StatelessWidget {
  const _RecipeDiscoveryHeader({
    required this.searchController,
    required this.category,
    required this.cuisine,
    required this.visibleCount,
    required this.totalCount,
    required this.showPremiumMarker,
    required this.premiumSemanticLabel,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onChooseCuisine,
    required this.onCategorySelected,
  });

  final TextEditingController searchController;
  final String category;
  final String cuisine;
  final int visibleCount;
  final int totalCount;
  final bool showPremiumMarker;
  final String premiumSemanticLabel;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onChooseCuisine;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final heading = cuisine != 'all'
        ? recipeCuisineLabel(context, cuisine)
        : category == 'all'
        ? recipeCuisineLabel(context, 'all')
        : category == 'saved'
        ? wellnessCopy(context, 'Saved recipes', 'الوصفات المحفوظة')
        : _recipeCategoryLabel(context, category);
    const categories = ['all', 'regional', 'quick', 'plant', 'saved'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('recipe-search-field'),
          controller: searchController,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: .42),
            prefixIcon: Icon(Icons.search_rounded, color: scheme.onSurface),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: context.strings.text('Clear'),
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.close_rounded),
                  ),
            hintText: wellnessCopy(
              context,
              'Search recipes or tags',
              'ابحث عن وصفة أو وسم',
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: .68),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              key: const Key('recipe-cuisine-selector'),
              avatar: const Icon(Icons.public_rounded, size: 17),
              label: Text(recipeCuisineLabel(context, cuisine)),
              onPressed: onChooseCuisine,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(
                color: cuisine == 'all'
                    ? scheme.outlineVariant
                    : scheme.primary.withValues(alpha: .48),
              ),
              backgroundColor: cuisine == 'all'
                  ? scheme.surfaceContainerLow
                  : scheme.primaryContainer.withValues(alpha: .62),
            ),
            for (final value in categories)
              ChoiceChip(
                key: ValueKey('recipe-category-$value'),
                label: Text(_recipeCategoryLabel(context, value)),
                selected: category == value,
                showCheckmark: value != 'all',
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) => onCategorySelected(value),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                heading,
                key: const Key('recipe-cuisine-heading'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.25,
                ),
              ),
            ),
            if (showPremiumMarker) ...[
              const SizedBox(width: 8),
              PremiumLabelBadge(
                key: const Key('recipe-premium-page-label'),
                semanticLabel: premiumSemanticLabel,
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          _recipeCountLabel(context, visibleCount, totalCount),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RecipeEmptyState extends StatelessWidget {
  const _RecipeEmptyState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.secondaryContainer,
              ),
              child: Icon(
                Icons.search_off_rounded,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              wellnessCopy(
                context,
                'No matching recipes.',
                'لا توجد وصفات مطابقة.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onReset,
              child: Text(wellnessCopy(context, 'All', 'الكل')),
            ),
          ],
        ),
      ),
    );
  }
}

TextDirection _directionForLocale(String locale) {
  final language = locale.split(RegExp('[-_]')).first.toLowerCase();
  return const {'ar', 'fa', 'ur'}.contains(language)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

TextDirection _directionForText(String value) =>
    RegExp(r'[\u0600-\u06ff]').hasMatch(value)
    ? TextDirection.rtl
    : TextDirection.ltr;

String _localeForText(String value, String declaredLocale) {
  final declaredDirection = _directionForLocale(declaredLocale);
  return _directionForText(value) == declaredDirection ? declaredLocale : 'en';
}

String _nutritionLine(Map<String, Object?> nutrients) {
  String value(String key, {String? fallbackKey}) {
    final raw =
        nutrients[key] ?? (fallbackKey == null ? null : nutrients[fallbackKey]);
    if (raw is! num || !raw.isFinite) return '—';
    return raw == raw.roundToDouble()
        ? raw.toInt().toString()
        : raw.toStringAsFixed(1);
  }

  return '${value('kcal')} kcal · '
      '${value('proteinG')} g protein · '
      '${value('carbsG', fallbackKey: 'carbohydrateG')} g carbs · '
      '${value('fatG')} g fat';
}

class _CatalogUnavailable extends StatelessWidget {
  const _CatalogUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42),
            const SizedBox(height: 12),
            Text(
              wellnessCopy(
                context,
                'The recipe catalog is unavailable.',
                'دليل الوصفات غير متاح.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(wellnessCopy(context, 'Retry', 'إعادة المحاولة')),
            ),
          ],
        ),
      ),
    );
  }
}
