part of 'reference_preferences_pages.dart';

class _DerivedMacroGrams extends ConsumerStatefulWidget {
  const _DerivedMacroGrams();

  @override
  ConsumerState<_DerivedMacroGrams> createState() => _DerivedMacroGramsState();
}

class _DerivedMacroGramsState extends ConsumerState<_DerivedMacroGrams> {
  int generation = 0;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(preferencesRepositoryProvider);
    return StreamBuilder<List<String?>>(
      key: ValueKey(generation),
      stream: Stream<List<String?>>.multi((controller) {
        final values = List<String?>.filled(4, null);
        final ready = List<bool>.filled(4, false);
        final keys = [
          'goal.calories',
          'goal.carbsPercent',
          'goal.proteinPercent',
          'goal.fatPercent',
        ];
        final subscriptions = <dynamic>[];
        for (var index = 0; index < keys.length; index++) {
          subscriptions.add(
            repository.watch(keys[index]).listen((value) {
              values[index] = value;
              ready[index] = true;
              if (ready.every((item) => item)) {
                controller.add(List.of(values));
              }
            }, onError: controller.addError),
          );
        }
        controller.onCancel = () async {
          for (final subscription in subscriptions) {
            await subscription.cancel();
          }
        };
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            title: Text(context.strings.text('Unavailable')),
            trailing: TextButton.icon(
              onPressed: () => setState(() => generation += 1),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.strings.text('Retry')),
            ),
          );
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final grams = deriveMacroGrams(snapshot.data!);
        final valid = grams != null;
        const labels = ['Carbohydrates', 'Protein', 'Fat'];
        return Column(
          children: [
            if (!valid)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  _nutritionGoalText(
                    context,
                    'Set calories and percentages totaling 100% to calculate grams.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            for (var index = 0; index < labels.length; index++)
              ListTile(
                title: Text(_nutritionGoalText(context, labels[index])),
                trailing: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    valid ? '${grams[index].toStringAsFixed(1)} g' : '—',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: Color(0xFF0A6FF5),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

@visibleForTesting
List<double>? deriveMacroGrams(List<String?> stored) {
  if (stored.length != 4) return null;
  final parsed = stored.map((value) => double.tryParse(value ?? '')).toList();
  if (!parsed.every((value) => value != null && value.isFinite && value >= 0)) {
    return null;
  }
  final calories = parsed[0]!;
  final carbs = parsed[1]!;
  final protein = parsed[2]!;
  final fat = parsed[3]!;
  if (calories <= 0 ||
      calories > 10000 ||
      carbs > 100 ||
      protein > 100 ||
      fat > 100 ||
      (carbs + protein + fat - 100).abs() >= 0.01) {
    return null;
  }
  return [
    calories * carbs / 400,
    calories * protein / 400,
    calories * fat / 900,
  ];
}

String _diaryText(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  return _diarySupplementalCopy[key]?[code] ??
      _diaryCopy[code]?[key] ??
      context.strings.text(key);
}

const _diarySupplementalCopy = <String, Map<String, String>>{
  'Diary sharing is not available yet. Your diary remains private.': {
    'ar': 'مشاركة اليوميات غير متاحة بعد. تظل يومياتك خاصة.',
    'fr':
        'Le partage du journal n’est pas encore disponible. Votre journal reste privé.',
    'es':
        'Compartir el diario aún no está disponible. Tu diario sigue siendo privado.',
    'tr': 'Günlük paylaşımı henüz kullanılamıyor. Günlüğünüz gizli kalır.',
  },
  'Customize the four supported meal names. Empty slots are hidden from the diary.': {
    'ar':
        'خصّص أسماء الوجبات الأربع المدعومة. تُخفى الخانات الفارغة من اليوميات.',
    'fr':
        'Personnalisez les quatre noms de repas pris en charge. Les champs vides sont masqués dans le journal.',
    'es':
        'Personaliza los cuatro nombres de comidas disponibles. Los campos vacíos se ocultan del diario.',
    'tr':
        'Desteklenen dört öğün adını özelleştirin. Boş alanlar günlükte gizlenir.',
  },
};

String _nutritionGoalText(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  return (_nutritionGoalCopy[code] ?? _nutritionGoalCopy['en']!)[key] ??
      _diaryText(context, key);
}

const _nutritionGoalCopy = <String, Map<String, String>>{
  'en': {},
  'ar': {
    'Set calories and percentages totaling 100% to calculate grams.':
        'حدّد السعرات والنسب بحيث يكون مجموعها 100٪ لحساب الغرامات.',
    'Daily macro goals in grams': 'أهداف المغذيات الكبرى اليومية بالجرام',
    'Calorie and macro goals': 'أهداف السعرات والعناصر الكبرى',
    'Default goal': 'الهدف الافتراضي',
    'Additional nutrient goals': 'أهداف المغذيات الإضافية',
    'Calories': 'السعرات',
    'Carbohydrates': 'الكربوهيدرات',
    'Protein': 'البروتين',
    'Fat': 'الدهون',
    'Saturated fat': 'الدهون المشبعة',
    'Polyunsaturated fat': 'الدهون المتعددة غير المشبعة',
    'Monounsaturated fat': 'الدهون الأحادية غير المشبعة',
    'Trans fat': 'الدهون المتحولة',
    'Cholesterol': 'الكوليسترول',
    'Sodium': 'الصوديوم',
    'Potassium': 'البوتاسيوم',
    'Fiber': 'الألياف',
    'Sugar': 'السكر',
    'Vitamin A': 'فيتامين أ',
    'Vitamin C': 'فيتامين ج',
    'Calcium': 'الكالسيوم',
    'Iron': 'الحديد',
    'Cancel': 'إلغاء',
    'Save': 'حفظ',
  },
  'fr': {
    'Daily macro goals in grams': 'Objectifs quotidiens de macros en grammes',
    'Calorie and macro goals': 'Objectifs calories et macronutriments',
    'Default goal': 'Objectif par défaut',
    'Additional nutrient goals': 'Objectifs nutritionnels supplémentaires',
    'Calories': 'Calories',
    'Carbohydrates': 'Glucides',
    'Protein': 'Protéines',
    'Fat': 'Lipides',
    'Saturated fat': 'Graisses saturées',
    'Polyunsaturated fat': 'Graisses polyinsaturées',
    'Monounsaturated fat': 'Graisses monoinsaturées',
    'Trans fat': 'Graisses trans',
    'Cholesterol': 'Cholestérol',
    'Sodium': 'Sodium',
    'Potassium': 'Potassium',
    'Fiber': 'Fibres',
    'Sugar': 'Sucres',
    'Vitamin A': 'Vitamine A',
    'Vitamin C': 'Vitamine C',
    'Calcium': 'Calcium',
    'Iron': 'Fer',
    'Cancel': 'Annuler',
    'Save': 'Enregistrer',
  },
  'es': {
    'Daily macro goals in grams': 'Objetivos diarios de macros en gramos',
    'Calorie and macro goals': 'Objetivos de calorías y macronutrientes',
    'Default goal': 'Objetivo predeterminado',
    'Additional nutrient goals': 'Objetivos de nutrientes adicionales',
    'Calories': 'Calorías',
    'Carbohydrates': 'Carbohidratos',
    'Protein': 'Proteína',
    'Fat': 'Grasas',
    'Saturated fat': 'Grasas saturadas',
    'Polyunsaturated fat': 'Grasas poliinsaturadas',
    'Monounsaturated fat': 'Grasas monoinsaturadas',
    'Trans fat': 'Grasas trans',
    'Cholesterol': 'Colesterol',
    'Sodium': 'Sodio',
    'Potassium': 'Potasio',
    'Fiber': 'Fibra',
    'Sugar': 'Azúcar',
    'Vitamin A': 'Vitamina A',
    'Vitamin C': 'Vitamina C',
    'Calcium': 'Calcio',
    'Iron': 'Hierro',
    'Cancel': 'Cancelar',
    'Save': 'Guardar',
  },
  'tr': {
    'Daily macro goals in grams': 'Gram cinsinden günlük makro hedefleri',
    'Calorie and macro goals': 'Kalori ve makro hedefleri',
    'Default goal': 'Varsayılan hedef',
    'Additional nutrient goals': 'Ek besin hedefleri',
    'Calories': 'Kalori',
    'Carbohydrates': 'Karbonhidrat',
    'Protein': 'Protein',
    'Fat': 'Yağ',
    'Saturated fat': 'Doymuş yağ',
    'Polyunsaturated fat': 'Çoklu doymamış yağ',
    'Monounsaturated fat': 'Tekli doymamış yağ',
    'Trans fat': 'Trans yağ',
    'Cholesterol': 'Kolesterol',
    'Sodium': 'Sodyum',
    'Potassium': 'Potasyum',
    'Fiber': 'Lif',
    'Sugar': 'Şeker',
    'Vitamin A': 'A vitamini',
    'Vitamin C': 'C vitamini',
    'Calcium': 'Kalsiyum',
    'Iron': 'Demir',
    'Cancel': 'İptal',
    'Save': 'Kaydet',
  },
};

const _diaryCopy = <String, Map<String, String>>{
  'en': {
    'my_foods': 'My foods',
    'meals': 'Meals',
    'recipes': 'Recipes',
    'private': 'Private',
    'public': 'Public',
    'friends': 'Friends only',
    'locked': 'Locked with a key',
    'Diary sharing is not available yet. Your diary remains private.':
        'Diary sharing is not available yet. Your diary remains private.',
    'Customize the four supported meal names. Empty slots are hidden from the diary.':
        'Customize the four supported meal names. Empty slots are hidden from the diary.',
  },
  'ar': {
    'Unit preferences': 'تفضيلات الوحدات',
    'Weight': 'الوزن',
    'Pounds': 'أرطال',
    'Kilograms': 'كيلوغرامات',
    'Stone': 'ستون',
    'Height': 'الطول',
    'Feet/Inches': 'قدم/بوصة',
    'Centimeters': 'سنتيمترات',
    'Distance': 'المسافة',
    'Miles': 'أميال',
    'Kilometers': 'كيلومترات',
    'Energy': 'الطاقة',
    'Calories': 'سعرات حرارية',
    'Kilojoules': 'كيلوجول',
    'Water': 'الماء',
    'Cups': 'أكواب',
    'Milliliters': 'ملليلترات',
    'Fluid ounces': 'أونصات سائلة',
    'App appearance': 'مظهر التطبيق',
    'Select theme': 'اختر المظهر',
    'System default': 'إعداد النظام',
    'Light theme': 'المظهر الفاتح',
    'Dark theme': 'المظهر الداكن',
    'Diary settings': 'إعدادات اليوميات',
    'Show carbs, protein and fat by meal':
        'عرض الكربوهيدرات والبروتين والدهون لكل وجبة',
    'View carbs, protein and fat by gram or percent.':
        'اعرض العناصر الكبرى بالغرام أو بالنسبة المئوية.',
    'Show all meals in diary tabs': 'عرض جميع الوجبات في تبويبات اليوميات',
    'Use multi-add by default': 'استخدام الإضافة المتعددة افتراضيًا',
    'Show diary food insights': 'عرض رؤى الطعام في اليوميات',
    'Always show water in diary': 'إظهار الماء دائمًا في اليوميات',
    'Default search tab': 'تبويب البحث الافتراضي',
    'Diary sharing': 'مشاركة اليوميات',
    'Customize meal names': 'تخصيص أسماء الوجبات',
    'Customize nutrient dashboard': 'تخصيص لوحة العناصر الغذائية',
    'Calories and macros': 'السعرات والعناصر الكبرى',
    'Heart healthy': 'صحي للقلب',
    'Low carb': 'منخفض الكربوهيدرات',
    'Custom': 'مخصص',
    'Track net carbs': 'تتبّع صافي الكربوهيدرات',
    'Show food timestamps': 'عرض توقيت الطعام',
    'Learn how when you eat impacts your energy, workouts and more.':
        'تعرّف على تأثير توقيت الطعام في طاقتك وتمارينك.',
    'all': 'الكل',
    'my_foods': 'أطعمتي',
    'meals': 'الوجبات',
    'recipes': 'الوصفات',
    'private': 'خاص',
    'public': 'عام',
    'friends': 'الأصدقاء فقط',
    'locked': 'مقفل بمفتاح',
    'sharing_warning':
        'قد تكشف مشاركة اليوميات وزنك وعاداتك الغذائية للأشخاص الذين تختارهم. اختر نطاقًا مناسبًا.',
    'Create access key': 'إنشاء مفتاح وصول',
    'Access key': 'مفتاح الوصول',
    'Key must contain at least 6 characters': 'يجب ألا يقل المفتاح عن 6 أحرف',
    'meal_names_hint': 'اكتب حتى ستة أسماء. تُخفى الخانات الفارغة من اليوميات.',
    'meal_names_hint_four':
        'خصّص أسماء الوجبات الأربع. تُخفى الخانات الفارغة من اليوميات.',
    'Meal': 'الوجبة',
    'Save': 'حفظ',
    'Saved': 'تم الحفظ',
    'Cancel': 'إلغاء',
    'Breakfast': 'الفطور',
    'Lunch': 'الغداء',
    'Dinner': 'العشاء',
    'Snack': 'الوجبات الخفيفة',
  },
  'fr': {
    'Unit preferences': 'Préférences d’unités',
    'Weight': 'Poids',
    'Pounds': 'Livres',
    'Kilograms': 'Kilogrammes',
    'Stone': 'Stones',
    'Height': 'Taille',
    'Feet/Inches': 'Pieds/pouces',
    'Centimeters': 'Centimètres',
    'Distance': 'Distance',
    'Miles': 'Miles',
    'Kilometers': 'Kilomètres',
    'Energy': 'Énergie',
    'Calories': 'Calories',
    'Kilojoules': 'Kilojoules',
    'Water': 'Eau',
    'Cups': 'Tasses',
    'Milliliters': 'Millilitres',
    'Fluid ounces': 'Onces liquides',
    'App appearance': "Apparence de l’application",
    'Select theme': 'Choisir le thème',
    'System default': 'Réglage du système',
    'Light theme': 'Thème clair',
    'Dark theme': 'Thème sombre',
    'Diary settings': 'Paramètres du journal',
    'Show carbs, protein and fat by meal':
        'Afficher glucides, protéines et lipides par repas',
    'View carbs, protein and fat by gram or percent.':
        'Afficher les macronutriments en grammes ou en pourcentage.',
    'Show all meals in diary tabs': 'Afficher tous les repas dans les onglets',
    'Use multi-add by default': "Utiliser l’ajout multiple par défaut",
    'Show diary food insights': 'Afficher les analyses alimentaires',
    'Always show water in diary': "Toujours afficher l’eau",
    'Default search tab': 'Onglet de recherche par défaut',
    'Diary sharing': 'Partage du journal',
    'Customize meal names': 'Personnaliser les noms des repas',
    'Customize nutrient dashboard': 'Personnaliser le tableau nutritionnel',
    'Calories and macros': 'Calories et macronutriments',
    'Heart healthy': 'Santé du cœur',
    'Low carb': 'Faible en glucides',
    'Custom': 'Personnalisé',
    'Track net carbs': 'Suivre les glucides nets',
    'Show food timestamps': 'Afficher les heures des aliments',
    'Learn how when you eat impacts your energy, workouts and more.':
        "Découvrez comment l’heure des repas influence votre énergie et vos entraînements.",
    'all': 'Tous',
    'my_foods': 'Mes aliments',
    'meals': 'Repas',
    'recipes': 'Recettes',
    'private': 'Privé',
    'public': 'Public',
    'friends': 'Amis uniquement',
    'locked': 'Verrouillé par une clé',
    'sharing_warning':
        'Le partage peut révéler votre poids et vos habitudes alimentaires aux personnes choisies.',
    'Create access key': 'Créer une clé d’accès',
    'Access key': 'Clé d’accès',
    'Key must contain at least 6 characters':
        'La clé doit contenir au moins 6 caractères',
    'meal_names_hint':
        'Saisissez jusqu’à six noms. Les champs vides sont masqués dans le journal.',
    'Meal': 'Repas',
    'Save': 'Enregistrer',
    'Saved': 'Enregistré',
    'Cancel': 'Annuler',
  },
  'es': {
    'Unit preferences': 'Preferencias de unidades',
    'Weight': 'Peso',
    'Pounds': 'Libras',
    'Kilograms': 'Kilogramos',
    'Stone': 'Stones',
    'Height': 'Altura',
    'Feet/Inches': 'Pies/pulgadas',
    'Centimeters': 'Centímetros',
    'Distance': 'Distancia',
    'Miles': 'Millas',
    'Kilometers': 'Kilómetros',
    'Energy': 'Energía',
    'Calories': 'Calorías',
    'Kilojoules': 'Kilojulios',
    'Water': 'Agua',
    'Cups': 'Tazas',
    'Milliliters': 'Mililitros',
    'Fluid ounces': 'Onzas líquidas',
    'App appearance': 'Apariencia de la aplicación',
    'Select theme': 'Elegir tema',
    'System default': 'Configuración del sistema',
    'Light theme': 'Tema claro',
    'Dark theme': 'Tema oscuro',
    'Diary settings': 'Ajustes del diario',
    'Show carbs, protein and fat by meal':
        'Mostrar carbohidratos, proteínas y grasas por comida',
    'View carbs, protein and fat by gram or percent.':
        'Ver macronutrientes en gramos o porcentaje.',
    'Show all meals in diary tabs': 'Mostrar todas las comidas en las pestañas',
    'Use multi-add by default': 'Usar adición múltiple por defecto',
    'Show diary food insights': 'Mostrar información alimentaria',
    'Always show water in diary': 'Mostrar siempre el agua',
    'Default search tab': 'Pestaña de búsqueda predeterminada',
    'Diary sharing': 'Compartir diario',
    'Customize meal names': 'Personalizar nombres de comidas',
    'Customize nutrient dashboard': 'Personalizar panel de nutrientes',
    'Calories and macros': 'Calorías y macronutrientes',
    'Heart healthy': 'Saludable para el corazón',
    'Low carb': 'Bajo en carbohidratos',
    'Custom': 'Personalizado',
    'Track net carbs': 'Registrar carbohidratos netos',
    'Show food timestamps': 'Mostrar horas de alimentos',
    'Learn how when you eat impacts your energy, workouts and more.':
        'Descubre cómo el horario influye en tu energía y entrenamientos.',
    'all': 'Todos',
    'my_foods': 'Mis alimentos',
    'meals': 'Comidas',
    'recipes': 'Recetas',
    'private': 'Privado',
    'public': 'Público',
    'friends': 'Solo amigos',
    'locked': 'Bloqueado con clave',
    'sharing_warning':
        'Compartir puede mostrar tu peso y hábitos alimentarios a las personas elegidas.',
    'Create access key': 'Crear clave de acceso',
    'Access key': 'Clave de acceso',
    'Key must contain at least 6 characters':
        'La clave debe tener al menos 6 caracteres',
    'meal_names_hint':
        'Escribe hasta seis nombres. Los campos vacíos se ocultan en el diario.',
    'Meal': 'Comida',
    'Save': 'Guardar',
    'Saved': 'Guardado',
    'Cancel': 'Cancelar',
  },
  'tr': {
    'Unit preferences': 'Birim tercihleri',
    'Weight': 'Ağırlık',
    'Pounds': 'Pound',
    'Kilograms': 'Kilogram',
    'Stone': 'Stone',
    'Height': 'Boy',
    'Feet/Inches': 'Fit/inç',
    'Centimeters': 'Santimetre',
    'Distance': 'Mesafe',
    'Miles': 'Mil',
    'Kilometers': 'Kilometre',
    'Energy': 'Enerji',
    'Calories': 'Kalori',
    'Kilojoules': 'Kilojul',
    'Water': 'Su',
    'Cups': 'Bardak',
    'Milliliters': 'Mililitre',
    'Fluid ounces': 'Sıvı ons',
    'App appearance': 'Uygulama görünümü',
    'Select theme': 'Tema seçin',
    'System default': 'Sistem ayarı',
    'Light theme': 'Açık tema',
    'Dark theme': 'Koyu tema',
    'Diary settings': 'Günlük ayarları',
    'Show carbs, protein and fat by meal':
        'Öğün başına karbonhidrat, protein ve yağ göster',
    'View carbs, protein and fat by gram or percent.':
        'Makroları gram veya yüzde olarak görüntüleyin.',
    'Show all meals in diary tabs': 'Tüm öğünleri günlük sekmelerinde göster',
    'Use multi-add by default': 'Çoklu eklemeyi varsayılan kullan',
    'Show diary food insights': 'Günlük beslenme analizlerini göster',
    'Always show water in diary': 'Günlükte suyu her zaman göster',
    'Default search tab': 'Varsayılan arama sekmesi',
    'Diary sharing': 'Günlük paylaşımı',
    'Customize meal names': 'Öğün adlarını özelleştir',
    'Customize nutrient dashboard': 'Besin panelini özelleştir',
    'Calories and macros': 'Kalori ve makrolar',
    'Heart healthy': 'Kalp dostu',
    'Low carb': 'Düşük karbonhidrat',
    'Custom': 'Özel',
    'Track net carbs': 'Net karbonhidratı izle',
    'Show food timestamps': 'Yiyecek saatlerini göster',
    'Learn how when you eat impacts your energy, workouts and more.':
        'Yemek saatlerinin enerji ve egzersize etkisini öğrenin.',
    'all': 'Tümü',
    'my_foods': 'Yiyeceklerim',
    'meals': 'Öğünler',
    'recipes': 'Tarifler',
    'private': 'Özel',
    'public': 'Herkese açık',
    'friends': 'Yalnızca arkadaşlar',
    'locked': 'Anahtarla kilitli',
    'sharing_warning':
        'Günlüğü paylaşmak kilonuzu ve yeme alışkanlıklarınızı seçtiğiniz kişilere gösterebilir.',
    'Create access key': 'Erişim anahtarı oluştur',
    'Access key': 'Erişim anahtarı',
    'Key must contain at least 6 characters':
        'Anahtar en az 6 karakter olmalıdır',
    'meal_names_hint': 'En fazla altı ad yazın. Boş alanlar günlükte gizlenir.',
    'Meal': 'Öğün',
    'Save': 'Kaydet',
    'Saved': 'Kaydedildi',
    'Cancel': 'İptal',
  },
};
