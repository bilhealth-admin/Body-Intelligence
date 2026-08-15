part of 'daily_log_page.dart';

extension _DailyLogMealEntryPresentation on _DailyLogPageState {
  String get _mealLocale =>
      Localizations.localeOf(context).languageCode.toLowerCase();
  String _mealCopy(String key) {
    final english = _mealEntryCopy['en']?[key] ?? key;
    return _mealEntryCopy[_mealLocale]?[key] ??
        RuntimeCopy.resolve(
          english,
          BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
        ) ??
        english;
  }

  Widget _buildMealEntry({
    required AsyncValue<List<UsualMealCandidate>> usualMeals,
    required DateTime date,
  }) {
    return PremiumSurface(
      key: mealEntryKey,
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              context.strings.text('Meal type'),
              style: PremiumDesignTokens.cardHeading(context),
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final type in const [
                  'breakfast',
                  'lunch',
                  'dinner',
                  'snack',
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      showCheckmark: true,
                      avatar: Icon(switch (type) {
                        'breakfast' => Icons.wb_sunny_outlined,
                        'lunch' => Icons.restaurant_rounded,
                        'dinner' => Icons.nights_stay_outlined,
                        _ => Icons.cookie_outlined,
                      }, size: 20),
                      label: Text(
                        context.strings.text(
                          '${type[0].toUpperCase()}${type.substring(1)}',
                        ),
                      ),
                      selected: mealType == type,
                      onSelected: mealSaving
                          ? null
                          : (_) {
                              _updateState(() {
                                mealType = type;
                                selectedFood = null;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                foodSearch.openView();
                              });
                            },
                    ),
                  ),
              ],
            ),
          ),
          usualMeals.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => ActionableErrorState(
              title: context.strings.text(
                'Your usual meals could not be loaded.',
              ),
              onRetry: () => ref.invalidate(usualMealsProvider(mealType)),
            ),
            data: (candidates) {
              if (candidates.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: PremiumDesignTokens.spaceSm),
                  Text(
                    _mealCopy('usualMeals'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceXs),
                  for (final candidate in candidates)
                    Card.outlined(
                      child: ListTile(
                        leading: const Icon(Icons.replay_outlined),
                        title: Text(
                          candidate.source.items
                              .map(
                                (item) => candidate
                                    .source
                                    .foodsById[item.foodId]
                                    ?.name,
                              )
                              .whereType<String>()
                              .join(' + '),
                        ),
                        subtitle: Text(
                          '${_mealCopy('logged')} ${candidate.occurrences} ${_mealCopy('times')}',
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: () async {
                            await ref
                                .read(mealRepositoryProvider)
                                .repeatMeal(candidate: candidate, date: date);
                            ref.invalidate(usualMealsProvider(mealType));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.strings.text('Meal saved locally.'),
                                ),
                              ),
                            );
                          },
                          child: Text(_mealCopy('add')),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          SearchAnchor(
            searchController: foodSearch,
            viewHintText: _mealCopy('searchDetail'),
            builder: (context, controller) => SearchBar(
              enabled: !mealSaving,
              controller: controller,
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.surface,
              ),
              side: WidgetStatePropertyAll(
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              hintText: _mealCopy('searchFoods'),
              onTap: mealSaving ? null : controller.openView,
            ),
            suggestionsBuilder: (context, controller) async {
              final locale = _mealLocale;
              final query = controller.text.trim();
              if (query.isEmpty) {
                final repository = ref.read(foodRepositoryProvider);
                final collections = await Future.wait([
                  repository.watchFavorites().first,
                  repository.watchRecent().first,
                ]);
                final favorites = collections[0];
                final favoriteIds = favorites.map((food) => food.id).toSet();
                final recent = collections[1]
                    .where((food) => !favoriteIds.contains(food.id))
                    .take(8)
                    .toList(growable: false);
                if (favorites.isEmpty && recent.isEmpty) {
                  return <Widget>[
                    ListTile(
                      leading: const Icon(Icons.search_rounded),
                      title: Text(_mealCopy('startSearch')),
                    ),
                  ];
                }
                return <Widget>[
                  if (favorites.isNotEmpty)
                    _mealSearchSectionHeader(
                      _mealCopy('favorites'),
                      Icons.favorite_rounded,
                    ),
                  for (final food in favorites.take(8))
                    _mealSearchFoodTile(
                      food: food,
                      controller: controller,
                      languageCode: locale,
                    ),
                  if (recent.isNotEmpty)
                    _mealSearchSectionHeader(
                      _mealCopy('recent'),
                      Icons.history_rounded,
                    ),
                  for (final food in recent)
                    _mealSearchFoodTile(
                      food: food,
                      controller: controller,
                      languageCode: locale,
                    ),
                ];
              }
              final results = await ref
                  .read(foodRuntimeSearchAuthorityProvider)
                  .search(query, limit: 20);
              if (results.isEmpty) {
                final correction = _DailyLogPageState._searchAssistance
                    .correctionFor(controller.text);
                final suggestions = _DailyLogPageState._searchAssistance
                    .suggestionsFor(controller.text);
                return <Widget>[
                  if (correction != null)
                    ListTile(
                      leading: const Icon(Icons.auto_fix_high),
                      title: Text('${_mealCopy('didYouMean')} $correction?'),
                      onTap: () {
                        controller.text = correction;
                        controller.openView();
                      },
                    ),
                  for (final suggestion in suggestions)
                    ListTile(
                      leading: const Icon(Icons.search),
                      title: Text(suggestion),
                      onTap: () {
                        controller.text = suggestion;
                        controller.openView();
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: Text(_mealCopy('noResult')),
                  ),
                ];
              }
              return results.map(
                (food) => _mealSearchFoodTile(
                  food: food,
                  controller: controller,
                  languageCode: locale,
                ),
              );
            },
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Row(
            children: [
              Expanded(
                child: _mealToolButton(
                  onPressed: mealSaving ? null : _scanBarcode,
                  icon: Icons.qr_code_scanner_rounded,
                  label: _mealCopy('barcode'),
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _mealToolButton(
                  onPressed: mealSaving ? null : _captureMealVoice,
                  icon: Icons.mic_rounded,
                  label: _mealCopy('voiceInput'),
                  color: const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _mealToolButton(
                  onPressed: mealSaving ? null : _analyzeMealImage,
                  icon: Icons.center_focus_strong_rounded,
                  label: _mealCopy('mealPhoto'),
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _mealToolButton(
                  onPressed: mealSaving ? null : _manualBarcode,
                  icon: Icons.add_circle_outline_rounded,
                  label: _mealCopy('quickAdd'),
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          if (selectedFood != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle),
              title: Text(
                _arabic && selectedFood!.arabicName != null
                    ? selectedFood!.arabicName!
                    : selectedFood!.name,
              ),
              subtitle: Text(
                '${context.strings.text('Source')}: '
                '${context.strings.text(selectedFood!.source)} · '
                '${context.strings.text(selectedFood!.verified ? 'Verified' : 'Unverified')} · '
                '${selectedFood!.servingSize.toStringAsFixed(0)} '
                '${_unit(selectedFood!.servingUnit)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<bool>(
                    future: ref
                        .read(foodRepositoryProvider)
                        .isFavorite(selectedFood!.id),
                    builder: (context, snapshot) {
                      final favorite = snapshot.data ?? false;
                      return IconButton(
                        key: const ValueKey('daily-log-toggle-favorite'),
                        tooltip: favorite
                            ? _mealCopy('removeFavorite')
                            : _mealCopy('saveFavorite'),
                        onPressed:
                            mealSaving ||
                                snapshot.connectionState ==
                                    ConnectionState.waiting
                            ? null
                            : () async {
                                await ref
                                    .read(foodRepositoryProvider)
                                    .setFavorite(selectedFood!.id, !favorite);
                                ref.invalidate(favoriteFoodsProvider);
                                if (mounted) _updateState(() {});
                              },
                        icon: Icon(
                          favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    onPressed: mealSaving
                        ? null
                        : () => _updateState(() => selectedFood = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          if (selectedFood != null) ...[
            const SizedBox(height: PremiumDesignTokens.spaceXs),
            Text(
              _mealCopy('chooseServing'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              key: const Key('daily-log-serving-choices'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final multiplier in const <double>[0.5, 1, 1.5, 2])
                  ActionChip(
                    avatar: multiplier == 1
                        ? const Icon(Icons.check_circle_outline, size: 18)
                        : null,
                    label: Text(
                      '${multiplier.toStringAsFixed(multiplier == multiplier.roundToDouble() ? 0 : 1)}× '
                      '${selectedFood!.servingSize.toStringAsFixed(0)} ${_unit(selectedFood!.servingUnit)}',
                    ),
                    onPressed: mealSaving
                        ? null
                        : () {
                            final value =
                                selectedFood!.servingSize * multiplier;
                            quantity.text = value.toStringAsFixed(
                              value == value.roundToDouble() ? 0 : 1,
                            );
                            _updateState(() {});
                          },
                  ),
              ],
            ),
          ],
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          TextField(
            enabled: !mealSaving,
            controller: quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.strings.text('Quantity'),
              helperText: selectedFood == null
                  ? _mealCopy('chooseFoodFirst')
                  : '${context.strings.text('Serving unit')}: '
                        '${_unit(selectedFood!.servingUnit)}',
            ),
            onSubmitted: mealSaving ? null : (_) => _saveMeal(),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          FilledButton.tonalIcon(
            onPressed: selectedFood == null || mealSaving ? null : _saveMeal,
            icon: const Icon(Icons.restaurant_menu),
            label: Text(
              context.strings.text(mealSaving ? 'Saving…' : 'Save meal'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealToolButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: Container(
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mealSearchSectionHeader(String title, IconData icon) {
    return ListTile(
      enabled: false,
      dense: true,
      leading: Icon(icon, size: 18),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _mealSearchFoodTile({
    required Food food,
    required SearchController controller,
    required String languageCode,
  }) {
    final accent = food.verified
        ? const Color(0xFF10B981)
        : Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.12),
          child: Icon(
            food.isCustom ? Icons.person_rounded : Icons.restaurant_rounded,
            color: accent,
          ),
        ),
        title: Text(
          languageCode != 'ar' || food.arabicName == null
              ? food.name
              : food.arabicName!,
          textDirection:
              intl.Bidi.detectRtlDirectionality(
                languageCode != 'ar' || food.arabicName == null
                    ? food.name
                    : food.arabicName!,
              )
              ? TextDirection.rtl
              : TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _mealCopy(food.verified ? 'verifiedSource' : 'unverifiedSource'),
            ),
            Text(
              context.strings.text(food.source),
              textDirection: intl.Bidi.detectRtlDirectionality(food.source)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _foodMacroSummary(food, languageCode: languageCode),
              textDirection: BilLocalePolicy.directionFor(
                Localizations.localeOf(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: IconButton.filledTonal(
          tooltip: _mealCopy('add'),
          icon: const Icon(Icons.add_rounded),
          onPressed: () => _selectFood(food, controller),
        ),
        onTap: () => _selectFood(food, controller),
      ),
    );
  }

  void _selectFood(Food food, SearchController controller) {
    _updateState(() {
      selectedFood = food;
      final serving = food.servingSize;
      quantity.text = serving.toStringAsFixed(
        serving == serving.roundToDouble() ? 0 : 1,
      );
    });
    controller.closeView(food.name);
  }

  String _foodMacroSummary(Food food, {required String languageCode}) {
    final calories = _catalogNutrientText(
      food,
      TrackedNutrient.calories,
      food.calories,
      decimals: 0,
    );
    final protein = _catalogNutrientText(
      food,
      TrackedNutrient.protein,
      food.protein,
    );
    final carbs = _catalogNutrientText(
      food,
      TrackedNutrient.carbohydrates,
      food.carbs,
    );
    final fat = _catalogNutrientText(food, TrackedNutrient.fat, food.fats);
    final fiber = _catalogNutrientText(food, TrackedNutrient.fiber, food.fiber);
    final sodium = _catalogNutrientText(
      food,
      TrackedNutrient.sodium,
      food.sodium,
      decimals: 0,
    );
    final potassium = _catalogNutrientText(
      food,
      TrackedNutrient.potassium,
      food.potassium,
      decimals: 0,
    );
    final englishWords = _mealMacroCopy['en']!;
    final words =
        _mealMacroCopy[languageCode] ??
        englishWords
            .map(
              (word) =>
                  RuntimeCopy.resolve(
                    word,
                    BilLocalePolicy.canonicalTag(
                      Localizations.localeOf(context),
                    ),
                  ) ??
                  word,
            )
            .toList(growable: false);
    return '$calories ${words[0]} · $protein ${words[1]} · $carbs ${words[2]} · $fat ${words[3]}\n'
        '$fiber ${words[4]} · $sodium ${words[5]} · $potassium ${words[6]}';
  }

  String _catalogNutrientText(
    Food food,
    TrackedNutrient nutrient,
    double value, {
    int decimals = 1,
  }) {
    if (food.source != 'bil-mobile-catalog' ||
        NutrientEvidenceMask.contains(food.nutrientEvidenceMask, nutrient) ||
        value != 0) {
      return value.toStringAsFixed(decimals);
    }
    return '—';
  }
}

const _mealEntryCopy = <String, Map<String, String>>{
  'en': {
    'usualMeals':
        'Your usual meals — nothing is added without your confirmation',
    'logged': 'Logged',
    'times': 'times',
    'add': 'Add',
    'searchDetail': 'Search English, Arabic, keyword, or barcode',
    'searchFoods': 'Search foods',
    'startSearch': 'Start typing a food name or scan its barcode.',
    'favorites': 'Favorites',
    'recent': 'Recently used',
    'didYouMean': 'Did you mean:',
    'noResult':
        'No result after correction. Open the food catalog to download more.',
    'mealPhoto': 'Meal photo',
    'voiceInput': 'Voice input',
    'barcode': 'Barcode',
    'quickAdd': 'Quick add',
    'chooseServing': 'Choose a serving',
    'removeFavorite': 'Remove from favorites',
    'verifiedSource': 'Verified nutrition record',
    'unverifiedSource': 'Unverified nutrition record',
    'saveFavorite': 'Save to favorites',
    'chooseFoodFirst': 'Choose a food before saving.',
  },
  'ar': {
    'usualMeals': 'وجباتك المعتادة — لن تتم الإضافة دون تأكيدك',
    'logged': 'سجلتها',
    'times': 'مرات',
    'add': 'أضف',
    'searchDetail': 'ابحث بالاسم العربي أو الإنجليزي أو الباركود',
    'searchFoods': 'ابحث عن طعام',
    'startSearch': 'ابدأ بكتابة اسم الطعام أو امسح الباركود.',
    'favorites': 'المفضلة',
    'recent': 'المستخدمة حديثًا',
    'didYouMean': 'هل تقصد:',
    'noResult': 'لم نجد نتيجة بعد التصحيح. افتح دليل الأطعمة لتنزيل المزيد.',
    'mealPhoto': 'تصوير الوجبة',
    'voiceInput': 'إدخال صوتي',
    'barcode': 'باركود',
    'quickAdd': 'إضافة سريعة',
    'chooseServing': 'اختر الحصة',
    'removeFavorite': 'إزالة من المفضلة',
    'verifiedSource': 'سجل تغذية موثّق',
    'unverifiedSource': 'سجل تغذية غير موثّق',
    'saveFavorite': 'حفظ في المفضلة',
    'chooseFoodFirst': 'اختر طعامًا قبل حفظ الوجبة.',
  },
  'fr': {
    'usualMeals':
        'Vos repas habituels — rien n’est ajouté sans votre confirmation',
    'logged': 'Enregistré',
    'times': 'fois',
    'add': 'Ajouter',
    'searchDetail': 'Rechercher par nom, mot-clé ou code-barres',
    'searchFoods': 'Rechercher des aliments',
    'startSearch': 'Saisissez un aliment ou scannez son code-barres.',
    'favorites': 'Favoris',
    'recent': 'Utilisés récemment',
    'didYouMean': 'Vouliez-vous dire :',
    'noResult':
        'Aucun résultat après correction. Ouvrez le catalogue pour en télécharger davantage.',
    'mealPhoto': 'Photo du repas',
    'voiceInput': 'Saisie vocale',
    'barcode': 'Code-barres',
    'quickAdd': 'Ajout rapide',
    'chooseServing': 'Choisir une portion',
    'removeFavorite': 'Retirer des favoris',
    'saveFavorite': 'Ajouter aux favoris',
    'chooseFoodFirst': 'Choisissez un aliment avant d’enregistrer le repas.',
  },
  'es': {
    'usualMeals':
        'Tus comidas habituales — no se añade nada sin tu confirmación',
    'logged': 'Registrada',
    'times': 'veces',
    'add': 'Añadir',
    'searchDetail': 'Buscar por nombre, palabra clave o código de barras',
    'searchFoods': 'Buscar alimentos',
    'startSearch': 'Escribe un alimento o escanea su código de barras.',
    'favorites': 'Favoritos',
    'recent': 'Usados recientemente',
    'didYouMean': 'Quizá quisiste decir:',
    'noResult':
        'No hay resultados tras la corrección. Abre el catálogo para descargar más.',
    'mealPhoto': 'Foto de la comida',
    'voiceInput': 'Entrada de voz',
    'barcode': 'Código',
    'quickAdd': 'Añadir rápido',
    'chooseServing': 'Elegir una porción',
    'removeFavorite': 'Quitar de favoritos',
    'saveFavorite': 'Guardar en favoritos',
    'chooseFoodFirst': 'Elige un alimento antes de guardar la comida.',
  },
  'tr': {
    'usualMeals': 'Her zamanki öğünlerin — onayın olmadan hiçbir şey eklenmez',
    'logged': 'Kaydedildi',
    'times': 'kez',
    'add': 'Ekle',
    'searchDetail': 'Ad, anahtar kelime veya barkodla ara',
    'searchFoods': 'Yiyecek ara',
    'startSearch': 'Bir yiyecek adı yazın veya barkodunu tarayın.',
    'favorites': 'Favoriler',
    'recent': 'Son kullanılanlar',
    'didYouMean': 'Bunu mu demek istediniz:',
    'noResult':
        'Düzeltmeden sonra sonuç bulunamadı. Daha fazlasını indirmek için kataloğu açın.',
    'mealPhoto': 'Öğün fotoğrafı',
    'voiceInput': 'Sesli giriş',
    'barcode': 'Barkod',
    'quickAdd': 'Hızlı ekle',
    'chooseServing': 'Porsiyon seçin',
    'removeFavorite': 'Favorilerden kaldır',
    'saveFavorite': 'Favorilere kaydet',
    'chooseFoodFirst': 'Öğünü kaydetmeden önce bir yiyecek seçin.',
  },
};

const _mealMacroCopy = <String, List<String>>{
  'en': [
    'kcal',
    'g protein',
    'g carbs',
    'g fat',
    'g fiber',
    'mg sodium',
    'mg potassium',
  ],
  'ar': [
    'سعرة',
    'غ بروتين',
    'غ كربوهيدرات',
    'غ دهون',
    'غ ألياف',
    'ملغ صوديوم',
    'ملغ بوتاسيوم',
  ],
  'fr': [
    'kcal',
    'g protéines',
    'g glucides',
    'g lipides',
    'g fibres',
    'mg sodium',
    'mg potassium',
  ],
  'es': [
    'kcal',
    'g proteína',
    'g carbohidratos',
    'g grasa',
    'g fibra',
    'mg sodio',
    'mg potasio',
  ],
  'tr': [
    'kcal',
    'g protein',
    'g karbonhidrat',
    'g yağ',
    'g lif',
    'mg sodyum',
    'mg potasyum',
  ],
};
