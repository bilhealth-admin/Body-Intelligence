part of 'meals_recipes_foods_page.dart';

class _RecipeChoiceTile extends StatelessWidget {
  const _RecipeChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      leading: Icon(icon, size: 30),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(subtitle),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

String _recipeChoiceCopy(BuildContext context, String key) {
  final language = Localizations.localeOf(context).languageCode;
  const copy = <String, Map<String, String>>{
    'en': {
      'title': 'Add a recipe',
      'webTitle': 'Import from the web',
      'webBody':
          'Paste a recipe link, then review every ingredient before saving.',
      'manualTitle': 'Enter ingredients manually',
      'manualBody': 'Build the recipe from reviewed foods and serving amounts.',
    },
    'ar': {
      'title': 'إضافة وصفة',
      'webTitle': 'الاستيراد من الويب',
      'webBody': 'الصق رابط الوصفة ثم راجع كل مكوّن قبل الحفظ.',
      'manualTitle': 'إدخال المكونات يدويًا',
      'manualBody': 'أنشئ الوصفة من أطعمة وكميات حصص تمت مراجعتها.',
    },
    'fr': {
      'title': 'Ajouter une recette',
      'webTitle': 'Importer depuis le Web',
      'webBody':
          'Collez un lien, puis vérifiez chaque ingrédient avant de sauvegarder.',
      'manualTitle': 'Saisir les ingrédients',
      'manualBody': 'Créez la recette avec des aliments et portions vérifiés.',
    },
    'es': {
      'title': 'Añadir una receta',
      'webTitle': 'Importar desde la web',
      'webBody': 'Pega un enlace y revisa cada ingrediente antes de guardar.',
      'manualTitle': 'Introducir ingredientes',
      'manualBody': 'Crea la receta con alimentos y porciones revisados.',
    },
    'tr': {
      'title': 'Tarif ekle',
      'webTitle': 'Web’den içe aktar',
      'webBody':
          'Bağlantıyı yapıştırın ve kaydetmeden önce malzemeleri inceleyin.',
      'manualTitle': 'Malzemeleri elle gir',
      'manualBody': 'Tarifi incelenmiş yiyecekler ve porsiyonlarla oluşturun.',
    },
  };
  final english = copy['en']![key]!;
  return copy[language]?[key] ??
      RuntimeCopy.resolve(
        english,
        BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      ) ??
      english;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
    child: Column(
      children: [
        Icon(icon, size: 80, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(body, textAlign: TextAlign.center),
      ],
    ),
  );
}

String _c(BuildContext context, String key) {
  final english = _copy['en']?[key] ?? key;
  return _copy[Localizations.localeOf(context).languageCode]?[key] ??
      RuntimeCopy.resolve(
        english,
        BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      ) ??
      english;
}

const _copy = <String, Map<String, String>>{
  'en': {
    'My nutrition': 'My nutrition',
    'My meals': 'My meals',
    'My recipes': 'My recipes',
    'My foods': 'My foods',
    'Create meal': 'Create meal',
    'Copy previous meal': 'Copy previous meal',
    'Saved meals could not be loaded.': 'Saved meals could not be loaded.',
    'Log your go-to meals faster': 'Log your go-to meals faster',
    'Meals repeated in your diary appear here for quick reuse.':
        'Meals repeated in your diary appear here for quick reuse.',
    'items': 'items',
    'Copy to today': 'Copy to today',
    'Meal copied to today.': 'Meal copied to today.',
    'This meal is already present today.':
        'This meal is already present today.',
    'Create recipe': 'Create recipe',
    'Discover': 'Discover',
    'Import': 'Import',
    'Build your recipe collection': 'Build your recipe collection',
    'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.':
        'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.',
    'Import recipe': 'Import recipe',
    'Recipe files require review before foods or nutrition values are added. Use Create recipe to review ingredients locally.':
        'Recipe files require review before foods or nutrition values are added. Use Create recipe to review ingredients locally.',
    'Close': 'Close',
  },
  'ar': {
    'My nutrition': 'تغذيتي',
    'My meals': 'وجباتي',
    'My recipes': 'وصفاتي',
    'My foods': 'أطعمتي',
    'Create meal': 'إنشاء وجبة',
    'Copy previous meal': 'نسخ وجبة سابقة',
    'Saved meals could not be loaded.': 'تعذر تحميل الوجبات المحفوظة.',
    'Log your go-to meals faster': 'سجّل وجباتك المعتادة أسرع',
    'Meals repeated in your diary appear here for quick reuse.':
        'تظهر هنا الوجبات المتكررة في يومياتك لإعادة استخدامها بسرعة.',
    'items': 'عناصر',
    'Copy to today': 'نسخ إلى اليوم',
    'Meal copied to today.': 'نُسخت الوجبة إلى اليوم.',
    'This meal is already present today.': 'هذه الوجبة موجودة اليوم بالفعل.',
    'Create recipe': 'إنشاء وصفة',
    'Discover': 'اكتشف',
    'Import': 'استيراد',
    'Build your recipe collection': 'أنشئ مجموعة وصفاتك',
    'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.':
        'اكتشف وصفات محلية واحفظ مفضلاتك. تُوسم التغذية المحسوبة بوضوح ولا تُختلق القيم.',
    'Import recipe': 'استيراد وصفة',
    'Recipe files require review before foods or nutrition values are added. Use Create recipe to review ingredients locally.':
        'تتطلب ملفات الوصفات مراجعة قبل إضافة الطعام أو القيم الغذائية. استخدم إنشاء وصفة لمراجعة المكونات محليًا.',
    'Close': 'إغلاق',
  },
  'fr': {
    'My nutrition': 'Ma nutrition',
    'My meals': 'Mes repas',
    'My recipes': 'Mes recettes',
    'My foods': 'Mes aliments',
    'Create meal': 'Créer un repas',
    'Copy previous meal': 'Copier un repas précédent',
    'Saved meals could not be loaded.':
        'Impossible de charger les repas enregistrés.',
    'Log your go-to meals faster': 'Enregistrez plus vite vos repas habituels',
    'Meals repeated in your diary appear here for quick reuse.':
        'Les repas répétés dans votre journal apparaissent ici.',
    'items': 'éléments',
    'Copy to today': "Copier aujourd’hui",
    'Meal copied to today.': "Repas copié aujourd’hui.",
    'This meal is already present today.':
        'Ce repas est déjà présent aujourd’hui.',
    'Create recipe': 'Créer une recette',
    'Discover': 'Découvrir',
    'Import': 'Importer',
    'Build your recipe collection': 'Créez votre collection de recettes',
    'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.':
        'Découvrez des recettes locales et enregistrez vos favorites. La nutrition calculée est clairement indiquée.',
    'Import recipe': 'Importer une recette',
    'Recipe files require review before foods or nutrition values are added. Use Create recipe to review ingredients locally.':
        'Les fichiers de recette doivent être vérifiés avant tout ajout.',
    'Close': 'Fermer',
  },
  'es': {
    'My nutrition': 'Mi nutrición',
    'My meals': 'Mis comidas',
    'My recipes': 'Mis recetas',
    'My foods': 'Mis alimentos',
    'Create meal': 'Crear comida',
    'Copy previous meal': 'Copiar comida anterior',
    'Saved meals could not be loaded.':
        'No se pudieron cargar las comidas guardadas.',
    'Log your go-to meals faster': 'Registra más rápido tus comidas habituales',
    'Meals repeated in your diary appear here for quick reuse.':
        'Las comidas repetidas aparecen aquí para reutilizarlas.',
    'items': 'elementos',
    'Copy to today': 'Copiar a hoy',
    'Meal copied to today.': 'Comida copiada a hoy.',
    'This meal is already present today.': 'Esta comida ya está presente hoy.',
    'Create recipe': 'Crear receta',
    'Discover': 'Descubrir',
    'Import': 'Importar',
    'Build your recipe collection': 'Crea tu colección de recetas',
    'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.':
        'Descubre recetas locales y guarda tus favoritas. La nutrición calculada se indica claramente.',
    'Import recipe': 'Importar receta',
    'Recipe files require review before foods or nutrition values are added. Use Create recipe to review ingredients locally.':
        'Los archivos de recetas deben revisarse antes de añadir datos.',
    'Close': 'Cerrar',
  },
  'tr': {
    'My nutrition': 'Beslenmem',
    'My meals': 'Öğünlerim',
    'My recipes': 'Tariflerim',
    'My foods': 'Yiyeceklerim',
    'Create meal': 'Öğün oluştur',
    'Copy previous meal': 'Önceki öğünü kopyala',
    'Saved meals could not be loaded.': 'Kayıtlı öğünler yüklenemedi.',
    'Log your go-to meals faster': 'Sık öğünlerinizi daha hızlı kaydedin',
    'Meals repeated in your diary appear here for quick reuse.':
        'Günlüğünüzde tekrarlanan öğünler burada görünür.',
    'items': 'öğe',
    'Copy to today': 'Bugüne kopyala',
    'Meal copied to today.': 'Öğün bugüne kopyalandı.',
    'This meal is already present today.': 'Bu öğün bugün zaten mevcut.',
    'Create recipe': 'Tarif oluştur',
    'Discover': 'Keşfet',
    'Import': 'İçe aktar',
    'Build your recipe collection': 'Tarif koleksiyonunuzu oluşturun',
    'Discover local recipes and save favorites. Calculated nutrition is labeled and never invented.':
        'Yerel tarifleri keşfedin ve favorilerinizi kaydedin. Hesaplanan beslenme açıkça etiketlenir.',
    'Import recipe': 'Tarif içe aktar',
    'Recipe files require review before foods or nutrition values are added. Use Create recipe to review ingredients locally.':
        'Tarif dosyaları veri eklenmeden önce incelenmelidir.',
    'Close': 'Kapat',
  },
};
