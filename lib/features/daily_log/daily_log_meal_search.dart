part of 'daily_log_page.dart';

extension _DailyLogMealSearchPresentation on _DailyLogPageState {
  Future<Iterable<Widget>> _mealQuerySuggestions(
    SearchController controller,
    String query,
    String locale,
  ) async {
    // SearchAnchor can keep an older async suggestion request alive while a
    // user types quickly (or an accessibility/ADB input method commits a whole
    // word at once). Resolve every in-flight request against the latest field
    // value so a slow result for `a` can never replace the result for `apple`.
    var effectiveQuery = query.trim();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    effectiveQuery = controller.text.trim();
    if (effectiveQuery.isEmpty) return const <Widget>[];

    var results = await ref
        .read(foodRuntimeSearchAuthorityProvider)
        .search(effectiveQuery, limit: 20);
    for (var refresh = 0; refresh < 3; refresh++) {
      final latestQuery = controller.text.trim();
      if (latestQuery == effectiveQuery) break;
      if (latestQuery.isEmpty) return const <Widget>[];
      effectiveQuery = latestQuery;
      results = await ref
          .read(foodRuntimeSearchAuthorityProvider)
          .search(effectiveQuery, limit: 20);
    }

    final resultLocale = FoodPresentationLocalizer.resultLocaleForQuery(
      query: effectiveQuery,
      interfaceLocaleTag: locale,
    );
    if (results.isEmpty) {
      final correction = _DailyLogPageState._searchAssistance
          .explicitCorrectionFor(effectiveQuery);
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
        ListTile(
          leading: const Icon(Icons.search_off_rounded),
          title: Text(_mealCopy('noResult')),
        ),
      ];
    }
    final uniqueResults = <Food>[];
    final identities = <String>{};
    for (final food in results) {
      if (!FoodPresentationLocalizer.hasLocalizedBrowseName(
        name: food.name,
        arabicName: food.arabicName,
        localeTag: resultLocale,
        isCustom: food.isCustom,
        source: food.source,
      )) {
        continue;
      }
      final displayName = _displayFoodName(food, resultLocale);
      final identity = _mealFoodDisplayIdentity(food, displayName);
      if (identities.add(identity)) uniqueResults.add(food);
    }
    if (uniqueResults.isEmpty) {
      return <Widget>[
        ListTile(
          leading: const Icon(Icons.translate_rounded),
          title: Text(_mealCopy('noResult')),
        ),
      ];
    }
    return uniqueResults.map(
      (food) => _mealSearchFoodTile(
        food: food,
        controller: controller,
        languageCode: resultLocale,
      ),
    );
  }

  Widget _mealSearchFoodTile({
    required Food food,
    required SearchController controller,
    required String languageCode,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    final displayName = _displayFoodName(food, languageCode);
    final servingSize = intl.NumberFormat.decimalPattern(
      languageCode,
    ).format(food.servingSize);
    final servingText = FoodPresentationLocalizer.browseServingText(
      amount: servingSize,
      unit: food.servingUnit,
      localeTag: languageCode,
    );
    final caloriesUnit = FoodPresentationLocalizer.servingUnit(
      'kcal',
      languageCode,
    );
    final caloriesKnown = NutrientEvidenceMask.contains(
      food.nutrientEvidenceMask,
      TrackedNutrient.calories,
    );
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.35;
    if (largeText) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectFood(food, controller, displayName),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      key: food.verified
                          ? const Key('daily-search-verified-food-badge')
                          : null,
                      backgroundColor: food.verified
                          ? const Color(0xFFE2F8EC)
                          : accent.withValues(alpha: 0.10),
                      child: Icon(
                        food.verified
                            ? Icons.verified_rounded
                            : food.isCustom
                            ? Icons.person_rounded
                            : Icons.shield_outlined,
                        color: food.verified ? const Color(0xFF087A43) : accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            textDirection:
                                intl.Bidi.detectRtlDirectionality(displayName)
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (caloriesKnown || servingText != null)
                            Text(
                              '${caloriesKnown ? '${food.calories.round()} $caloriesUnit' : ''}'
                              '${caloriesKnown && servingText != null ? ' · ' : ''}'
                              '${servingText ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  key: const Key('daily-search-add-food-action'),
                  onPressed: () => _selectFood(food, controller, displayName),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _mealCopy('add'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
        leading: CircleAvatar(
          key: food.verified
              ? const Key('daily-search-verified-food-badge')
              : null,
          backgroundColor: food.verified
              ? const Color(0xFFE2F8EC)
              : accent.withValues(alpha: 0.10),
          child: Icon(
            food.verified
                ? Icons.verified_rounded
                : food.isCustom
                ? Icons.person_rounded
                : Icons.shield_outlined,
            color: food.verified ? const Color(0xFF087A43) : accent,
          ),
        ),
        title: Text(
          displayName,
          textDirection: intl.Bidi.detectRtlDirectionality(displayName)
              ? TextDirection.rtl
              : TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (caloriesKnown || servingText != null)
              Row(
                children: [
                  if (caloriesKnown) ...[
                    Text(
                      food.calories.round().toString(),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 3),
                    Text(caloriesUnit, style: const TextStyle(fontSize: 13)),
                  ],
                  if (caloriesKnown && servingText != null)
                    const Text(' · ', style: TextStyle(fontSize: 13)),
                  if (servingText != null)
                    Flexible(
                      child: Text(
                        servingText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
            if (largeText) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _selectFood(food, controller, displayName),
                child: Row(
                  children: [
                    const Icon(Icons.add_rounded, size: 19),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _mealCopy('add'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        trailing: largeText
            ? null
            : FilledButton.tonalIcon(
                key: const Key('daily-search-add-food-action'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 9, 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _selectFood(food, controller, displayName),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: Text(_mealCopy('add')),
              ),
        onTap: () => _selectFood(food, controller, displayName),
      ),
    );
  }

  String _displayFoodName(Food food, String languageCode) {
    return FoodPresentationLocalizer.foodName(
      name: food.name,
      arabicName: food.arabicName,
      localeTag: languageCode,
      isCustom: food.isCustom,
      source: food.source,
    );
  }

  void _selectFood(Food food, SearchController controller, String displayName) {
    _updateState(() {
      selectedFood = food;
      final sourceGrams = dailyLogAmountInGrams(
        amount: food.servingSize,
        unit: food.servingUnit,
      );
      mealQuantityUnit = 'g';
      final amount = sourceGrams ?? food.servingSize;
      quantity.text = amount.toStringAsFixed(
        amount == amount.roundToDouble() ? 0 : 1,
      );
    });
    controller.closeView(displayName);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusMealEntry());
  }

  String _mealFoodDisplayIdentity(Food food, String displayName) {
    final normalizedName = displayName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+'), ' ')
        .trim();
    return '$normalizedName|${food.servingUnit.trim().toLowerCase()}|'
        '${food.servingSize.toStringAsFixed(2)}';
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
    'popular': 'Most popular',
    'servingSize': 'Serving size',
    'servings': 'Servings',
    'time': 'Time',
    'meal': 'Meal',
    'carbs': 'Carbs',
    'fat': 'Fat',
    'protein': 'Protein',
    'didYouMean': 'Did you mean:',
    'noResult': 'No match yet. Try a broader name, brand, or barcode.',
    'mealPhoto': 'Meal photo',
    'voiceInput': 'Voice input',
    'barcode': 'Barcode',
    'quickAdd': 'Quick add',
    'barcodeScan': 'Barcode scan',
    'voiceLog': 'Voice log',
    'mealScan': 'Meal scan',
    'chooseServing': 'Choose a serving',
    'removeFavorite': 'Remove from favorites',
    'verifiedSource': 'Verified nutrition record',
    'unverifiedSource': 'Unverified nutrition record',
    'usdaFoundationSource': 'USDA FoodData Central · Foundation food database',
    'usdaLegacySource': 'USDA FoodData Central · Legacy reference database',
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
    'popular': 'الأكثر شيوعًا',
    'servingSize': 'حجم الحصة',
    'servings': 'عدد الحصص',
    'time': 'الوقت',
    'meal': 'الوجبة',
    'carbs': 'الكربوهيدرات',
    'fat': 'الدهون',
    'protein': 'البروتين',
    'didYouMean': 'هل تقصد:',
    'noResult':
        'لا توجد نتيجة مطابقة بعد. جرّب اسمًا أبسط أو علامة تجارية أو باركود.',
    'mealPhoto': 'تصوير الوجبة',
    'voiceInput': 'إدخال صوتي',
    'barcode': 'باركود',
    'quickAdd': 'إضافة سريعة',
    'barcodeScan': 'مسح الباركود',
    'voiceLog': 'تسجيل صوتي',
    'mealScan': 'مسح الوجبة',
    'chooseServing': 'اختر الحصة',
    'removeFavorite': 'إزالة من المفضلة',
    'verifiedSource': 'سجل تغذية موثّق',
    'unverifiedSource': 'سجل تغذية غير موثّق',
    'usdaFoundationSource': 'USDA FoodData Central · قاعدة الأغذية الأساسية',
    'usdaLegacySource': 'USDA FoodData Central · قاعدة المراجع القديمة',
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
    'popular': 'Les plus populaires',
    'servingSize': 'Taille de la portion',
    'servings': 'Portions',
    'time': 'Heure',
    'meal': 'Repas',
    'carbs': 'Glucides',
    'fat': 'Lipides',
    'protein': 'Protéines',
    'didYouMean': 'Vouliez-vous dire :',
    'noResult':
        'Aucun résultat pour le moment. Essayez un nom plus simple, une marque ou un code-barres.',
    'mealPhoto': 'Photo du repas',
    'voiceInput': 'Saisie vocale',
    'barcode': 'Code-barres',
    'quickAdd': 'Ajout rapide',
    'barcodeScan': 'Scanner le code',
    'voiceLog': 'Saisie vocale',
    'mealScan': 'Scanner le repas',
    'chooseServing': 'Choisir une portion',
    'removeFavorite': 'Retirer des favoris',
    'usdaFoundationSource':
        'USDA FoodData Central · Base des aliments de référence',
    'usdaLegacySource': 'USDA FoodData Central · Ancienne base de référence',
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
    'popular': 'Más populares',
    'servingSize': 'Tamaño de la porción',
    'servings': 'Porciones',
    'time': 'Hora',
    'meal': 'Comida',
    'carbs': 'Carbohidratos',
    'fat': 'Grasas',
    'protein': 'Proteína',
    'didYouMean': 'Quizá quisiste decir:',
    'noResult':
        'Aún no hay coincidencias. Prueba un nombre más simple, una marca o un código de barras.',
    'mealPhoto': 'Foto de la comida',
    'voiceInput': 'Entrada de voz',
    'barcode': 'Código',
    'quickAdd': 'Añadir rápido',
    'barcodeScan': 'Escanear código',
    'voiceLog': 'Registro por voz',
    'mealScan': 'Escanear comida',
    'chooseServing': 'Elegir una porción',
    'removeFavorite': 'Quitar de favoritos',
    'usdaFoundationSource':
        'USDA FoodData Central · Base de alimentos de referencia',
    'usdaLegacySource': 'USDA FoodData Central · Base de referencia histórica',
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
    'popular': 'En popüler',
    'servingSize': 'Porsiyon boyutu',
    'servings': 'Porsiyonlar',
    'time': 'Saat',
    'meal': 'Öğün',
    'carbs': 'Karbonhidrat',
    'fat': 'Yağ',
    'protein': 'Protein',
    'didYouMean': 'Bunu mu demek istediniz:',
    'noResult':
        'Henüz eşleşme yok. Daha sade bir ad, marka veya barkod deneyin.',
    'mealPhoto': 'Öğün fotoğrafı',
    'voiceInput': 'Sesli giriş',
    'barcode': 'Barkod',
    'quickAdd': 'Hızlı ekle',
    'barcodeScan': 'Barkod tara',
    'voiceLog': 'Sesli kayıt',
    'mealScan': 'Öğün tara',
    'chooseServing': 'Porsiyon seçin',
    'removeFavorite': 'Favorilerden kaldır',
    'usdaFoundationSource': 'USDA FoodData Central · Temel gıda veritabanı',
    'usdaLegacySource': 'USDA FoodData Central · Eski referans veritabanı',
    'saveFavorite': 'Favorilere kaydet',
    'chooseFoodFirst': 'Öğünü kaydetmeden önce bir yiyecek seçin.',
  },
};

/// Testable localization boundary shared by Search and Add Food.
String dailyLogMealCopyForLocale(String key, String localeTag) {
  final english = _mealEntryCopy['en']?[key] ?? key;
  final language = localeTag.split('-').first;
  return _mealEntryCopy[localeTag]?[key] ??
      _mealEntryCopy[language]?[key] ??
      RuntimeCopy.resolve(english, localeTag) ??
      english;
}

/// True only when the copy is explicitly authored for this locale. This
/// separates a legitimate shared term (for example, "Protein" in Turkish)
/// from an accidental English fallback.
bool dailyLogMealHasReviewedCopy(String key, String localeTag) {
  if (localeTag == 'en') return _mealEntryCopy['en']?.containsKey(key) == true;
  final language = localeTag.split('-').first;
  if (_mealEntryCopy[localeTag]?.containsKey(key) == true ||
      _mealEntryCopy[language]?.containsKey(key) == true) {
    return true;
  }
  final english = _mealEntryCopy['en']?[key];
  return english != null && RuntimeCopy.resolve(english, localeTag) != null;
}
