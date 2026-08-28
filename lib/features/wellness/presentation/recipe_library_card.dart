part of 'recipe_library_page.dart';

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.title,
    required this.titleLocale,
    required this.isFallback,
    required this.initialFacts,
    required this.facts,
    required this.imageResult,
    required this.favorite,
    required this.onFavorite,
    required this.onOpen,
  });

  final RecipeCatalogSummary recipe;
  final String title;
  final String titleLocale;
  final bool isFallback;
  final RecipeCatalogCardFacts? initialFacts;
  final Future<RecipeCatalogCardFacts>? facts;
  final Future<WellnessMediaCacheResult>? imageResult;
  final bool favorite;
  final VoidCallback? onFavorite;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .65)),
        ),
        child: InkWell(
          onTap: onOpen,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageHeight = (constraints.maxHeight * .43).clamp(
                132.0,
                168.0,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: imageHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _RecipeArtwork(
                          recipe: recipe,
                          title: title,
                          imageResult: imageResult,
                        ),
                        PositionedDirectional(
                          start: 9,
                          bottom: 9,
                          child: _RecipeCategoryPill(category: recipe.category),
                        ),
                        if (isFallback)
                          PositionedDirectional(
                            start: 9,
                            top: 9,
                            child: _RecipeLocalePill(locale: titleLocale),
                          ),
                        PositionedDirectional(
                          top: 7,
                          end: 7,
                          child: IconButton.filledTonal(
                            tooltip: wellnessCopy(
                              context,
                              favorite ? 'Remove saved recipe' : 'Save recipe',
                              favorite ? 'إزالة الوصفة المحفوظة' : 'حفظ الوصفة',
                            ),
                            onPressed: onFavorite,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              backgroundColor: scheme.surface.withValues(
                                alpha: .9,
                              ),
                              foregroundColor: favorite
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                            icon: Icon(
                              favorite
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_outline_rounded,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Tooltip(
                            message: title,
                            child: Text(
                              title,
                              locale: BilLocalePolicy.localeFromTag(
                                titleLocale,
                              ),
                              textDirection: _directionForLocale(titleLocale),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    height: 1.18,
                                    fontWeight: FontWeight.w900,
                                    fontFamily:
                                        _directionForLocale(titleLocale) ==
                                            TextDirection.rtl
                                        ? 'BILArabic'
                                        : null,
                                  ),
                            ),
                          ),
                          const Spacer(),
                          _RecipeCardFacts(
                            minutes: recipe.totalMinutes,
                            initialFacts: initialFacts,
                            facts: facts,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RecipeCardFacts extends StatelessWidget {
  const _RecipeCardFacts({
    required this.minutes,
    required this.initialFacts,
    required this.facts,
  });

  final int minutes;
  final RecipeCatalogCardFacts? initialFacts;
  final Future<RecipeCatalogCardFacts>? facts;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecipeCatalogCardFacts>(
      future: facts,
      initialData: initialFacts,
      builder: (context, snapshot) {
        final value = snapshot.data;
        final waiting =
            facts != null && snapshot.connectionState != ConnectionState.done;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _RecipeFactCell(
                    icon: Icons.schedule_rounded,
                    label: _recipeTimeLabel(context),
                    value: _recipeMinutesLabel(context, minutes),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: waiting
                      ? const _RecipeFactSkeleton()
                      : _RecipeFactCell(
                          icon: Icons.people_alt_outlined,
                          label: _recipeServingsLabel(context),
                          value: value == null
                              ? '—'
                              : context.strings.number(value.servings),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.strings.text('Per serving'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: waiting
                      ? const _RecipeFactSkeleton()
                      : _RecipeFactCell(
                          icon: Icons.local_fire_department_outlined,
                          label: context.strings.get('calories'),
                          value: value == null
                              ? '—'
                              : '${context.strings.number(value.kcalPerServing.round())} kcal',
                        ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: waiting
                      ? const _RecipeFactSkeleton()
                      : _RecipeFactCell(
                          icon: Icons.fitness_center_rounded,
                          label: context.strings.get('protein'),
                          value: value == null
                              ? '—'
                              : '${context.strings.number(value.proteinGramsPerServing, decimalDigits: value.proteinGramsPerServing == value.proteinGramsPerServing.roundToDouble() ? 0 : 1)} g',
                        ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RecipeFactCell extends StatelessWidget {
  const _RecipeFactCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: '$label: $value',
      child: Semantics(
        excludeSemantics: true,
        label: label,
        value: value,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: .52),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: Row(
              children: [
                Icon(icon, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeFactSkeleton extends StatelessWidget {
  const _RecipeFactSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: .62);
    return ExcludeSemantics(
      child: Container(
        height: 26,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _RecipeDetailFacts extends StatelessWidget {
  const _RecipeDetailFacts({required this.minutes, required this.facts});

  final int minutes;
  final RecipeCatalogCardFacts facts;

  @override
  Widget build(BuildContext context) {
    final calories = context.strings.number(facts.kcalPerServing.round());
    final protein = context.strings.number(
      facts.proteinGramsPerServing,
      decimalDigits:
          facts.proteinGramsPerServing ==
              facts.proteinGramsPerServing.roundToDouble()
          ? 0
          : 1,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _RecipeDetailFact(
              icon: Icons.schedule_rounded,
              label: _recipeTimeLabel(context),
              value: _recipeMinutesLabel(context, minutes),
            ),
            _RecipeDetailFact(
              icon: Icons.people_alt_outlined,
              label: _recipeServingsLabel(context),
              value: context.strings.number(facts.servings),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.strings.text('Per serving'),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _RecipeDetailFact(
              icon: Icons.local_fire_department_outlined,
              label: context.strings.get('calories'),
              value: '$calories kcal',
            ),
            _RecipeDetailFact(
              icon: Icons.fitness_center_rounded,
              label: context.strings.get('protein'),
              value: '$protein g',
            ),
          ],
        ),
      ],
    );
  }
}

class _RecipeDetailFact extends StatelessWidget {
  const _RecipeDetailFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      excludeSemantics: true,
      label: label,
      value: value,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: scheme.onPrimaryContainer),
              const SizedBox(width: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeArtwork extends StatelessWidget {
  const _RecipeArtwork({
    required this.recipe,
    required this.title,
    required this.imageResult,
  });

  final RecipeCatalogSummary recipe;
  final String title;
  final Future<WellnessMediaCacheResult>? imageResult;

  @override
  Widget build(BuildContext context) {
    final asset = bundledRecipeImageAssets[recipe.id];
    if (asset != null) {
      return Image.asset(
        asset,
        key: ValueKey('recipe-image-${recipe.id}'),
        fit: BoxFit.cover,
        cacheWidth: 720,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => _RecipeFallbackArtwork(recipe: recipe),
      );
    }
    final future = imageResult;
    if (future == null) return _RecipeFallbackArtwork(recipe: recipe);
    return FutureBuilder<WellnessMediaCacheResult>(
      future: future,
      builder: (context, snapshot) {
        final result = snapshot.data;
        final file = result?.isReady == true ? result?.file : null;
        if (file == null) return _RecipeFallbackArtwork(recipe: recipe);
        return Image.file(
          file,
          key: ValueKey('recipe-remote-image-${recipe.id}'),
          fit: BoxFit.cover,
          cacheWidth: 720,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => _RecipeFallbackArtwork(recipe: recipe),
        );
      },
    );
  }
}

class _RecipeFallbackArtwork extends StatelessWidget {
  const _RecipeFallbackArtwork({required this.recipe});

  final RecipeCatalogSummary recipe;

  @override
  Widget build(BuildContext context) {
    const palettes = <(Color, Color, Color)>[
      (Color(0xff173f38), Color(0xff4f9a78), Color(0xffd7f2df)),
      (Color(0xff57311f), Color(0xffc77845), Color(0xffffe2bf)),
      (Color(0xff253a67), Color(0xff6c8cc9), Color(0xffdce8ff)),
      (Color(0xff5b294b), Color(0xffb46891), Color(0xffffdfef)),
      (Color(0xff38421b), Color(0xff8ca14c), Color(0xffedf3bf)),
    ];
    final seed = recipe.id.codeUnits.fold<int>(0, (a, b) => a + b);
    final palette = palettes[seed % palettes.length];
    final icon = recipe.mealTypes.contains('breakfast')
        ? Icons.wb_sunny_outlined
        : recipe.mealTypes.contains('dinner')
        ? Icons.nights_stay_outlined
        : Icons.soup_kitchen_outlined;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [palette.$1, palette.$2],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PositionedDirectional(
              top: -34,
              end: -18,
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.$3.withValues(alpha: .16),
                  border: Border.all(color: palette.$3.withValues(alpha: .24)),
                ),
              ),
            ),
            PositionedDirectional(
              bottom: -52,
              start: -34,
              child: Container(
                width: 138,
                height: 138,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.$3.withValues(alpha: .1),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.$3.withValues(alpha: .92),
                  border: Border.all(color: Colors.white.withValues(alpha: .5)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x30000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: palette.$1, size: 29),
              ),
            ),
            PositionedDirectional(
              end: 12,
              bottom: 10,
              child: Text(
                'BIL',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .42),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeCategoryPill extends StatelessWidget {
  const _RecipeCategoryPill({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(
            _recipeCategoryLabel(context, category),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _RecipeLocalePill extends StatelessWidget {
  const _RecipeLocalePill({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final label = wellnessCopy(
      context,
      'Original · {language}',
      'الأصلية · {language}',
    ).replaceAll('{language}', locale.toUpperCase());
    return Semantics(
      excludeSemantics: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.scrim.withValues(alpha: .62),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            locale.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: .4,
            ),
          ),
        ),
      ),
    );
  }
}
