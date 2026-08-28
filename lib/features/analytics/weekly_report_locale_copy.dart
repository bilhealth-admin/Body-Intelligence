part of 'weekly_report_page.dart';

/// Feature-local closure for copy that is intentionally absent from the
/// shared runtime catalog in French, Spanish, or Turkish. Other supported
/// locales continue through the reviewed global catalog.
String _weeklySurfaceText(BuildContext context, String english) {
  final locale = Localizations.localeOf(context);
  final translations = _weeklySurfaceCopy[english];
  return translations?[locale.toLanguageTag()] ??
      translations?[locale.languageCode] ??
      context.strings.text(english);
}

const _weeklySurfaceCopy = <String, Map<String, String>>{
  'No foods logged': {
    'ar': 'لا توجد أطعمة مسجلة',
    'fr': 'Aucun aliment enregistré',
    'es': 'No hay alimentos registrados',
    'tr': 'Kaydedilmiş yiyecek yok',
  },
  'Foods logged': {
    'ar': 'الأطعمة المسجلة',
    'fr': 'Aliments enregistrés',
    'es': 'Alimentos registrados',
    'tr': 'Kaydedilen yiyecekler',
  },
  'Member since': {
    'ar': 'عضو منذ',
    'fr': 'Membre depuis',
    'es': 'Miembro desde',
    'tr': 'Üyelik başlangıcı',
  },
  'Sleep': {'ar': 'النوم', 'fr': 'Sommeil', 'es': 'Sueño', 'tr': 'Uyku'},
  'Fasting': {'ar': 'الصيام', 'fr': 'Jeûne', 'es': 'Ayuno', 'tr': 'Oruç'},
  'Body context': {
    'ar': 'سياق الجسم',
    'fr': 'Contexte corporel',
    'es': 'Contexto corporal',
    'tr': 'Vücut bağlamı',
  },
  'Active energy': {
    'ar': 'الطاقة النشطة',
    'fr': 'Énergie active',
    'es': 'Energía activa',
    'tr': 'Aktif enerji',
  },
  'Choose report week': {
    'fr': 'Choisir la semaine du rapport',
    'es': 'Elegir la semana del informe',
    'tr': 'Rapor haftasını seç',
  },
  'Open nutrition importer': {
    'fr': 'Ouvrir l’importateur nutritionnel',
    'es': 'Abrir el importador de nutrición',
    'tr': 'Beslenme içe aktarıcısını aç',
  },
  'Connect a supported app or device to bring saved activity into your weekly picture.': {
    'fr':
        'Connectez une application ou un appareil compatible pour ajouter l’activité enregistrée à votre bilan hebdomadaire.',
    'es':
        'Conecta una aplicación o dispositivo compatible para añadir la actividad guardada a tu resumen semanal.',
    'tr':
        'Kaydedilmiş etkinliği haftalık özetinize eklemek için desteklenen bir uygulama veya cihaz bağlayın.',
  },
  'Connect apps and devices': {
    'fr': 'Connecter des applications et appareils',
    'es': 'Conectar aplicaciones y dispositivos',
    'tr': 'Uygulamaları ve cihazları bağla',
  },
  'Continue to log in every day to keep your streak going.': {
    'fr': 'Continuez à enregistrer chaque jour pour maintenir votre série.',
    'es': 'Sigue registrando datos cada día para mantener tu racha.',
    'tr': 'Serinizi sürdürmek için her gün kayıt yapmaya devam edin.',
  },
  'NUTRITION SUPERSTARS': {
    'ar': 'نجوم التغذية',
    'fr': 'VEDETTES DE LA NUTRITION',
    'es': 'ESTRELLAS DE LA NUTRICIÓN',
    'tr': 'BESLENME YILDIZLARI',
  },
  'Plants packed with vitamins, minerals and antioxidants.': {
    'ar': 'نباتات غنية بالفيتامينات والمعادن ومضادات الأكسدة.',
    'fr': 'Des végétaux riches en vitamines, minéraux et antioxydants.',
    'es': 'Vegetales llenos de vitaminas, minerales y antioxidantes.',
    'tr': 'Vitamin, mineral ve antioksidan bakımından zengin bitkiler.',
  },
  'FULL OF FIBER': {
    'ar': 'غنية بالألياف',
    'fr': 'RICHE EN FIBRES',
    'es': 'LLENO DE FIBRA',
    'tr': 'LİF DOLU',
  },
  'Fresh fruits add fiber, color and natural sweetness.': {
    'ar': 'تضيف الفواكه الطازجة الألياف واللون والحلاوة الطبيعية.',
    'fr': 'Les fruits frais apportent fibres, couleur et douceur naturelle.',
    'es': 'Las frutas frescas aportan fibra, color y dulzor natural.',
    'tr': 'Taze meyveler lif, renk ve doğal tatlılık katar.',
  },
  'NUTRITION POWERHOUSES': {
    'ar': 'مصادر غذائية قوية',
    'fr': 'CONCENTRÉS DE NUTRITION',
    'es': 'POTENCIAS NUTRICIONALES',
    'tr': 'BESLENME GÜÇ KAYNAKLARI',
  },
  'Protein-rich foods help maintain and repair muscle.': {
    'ar': 'تساعد الأطعمة الغنية بالبروتين في الحفاظ على العضلات وإصلاحها.',
    'fr':
        'Les aliments riches en protéines aident à maintenir et réparer les muscles.',
    'es':
        'Los alimentos ricos en proteínas ayudan a mantener y reparar los músculos.',
    'tr':
        'Protein açısından zengin yiyecekler kasların korunmasına ve onarılmasına yardımcı olur.',
  },
  'ENJOY MINDFULLY': {
    'ar': 'استمتع بوعي',
    'fr': 'SAVOUREZ EN PLEINE CONSCIENCE',
    'es': 'DISFRUTA CON ATENCIÓN',
    'tr': 'BİLİNÇLİCE TÜKETİN',
  },
  'Snacks count too—logging them makes the weekly picture honest.': {
    'ar': 'الوجبات الخفيفة مهمة أيضًا؛ تسجيلها يجعل صورة الأسبوع دقيقة.',
    'fr':
        'Les collations comptent aussi : les enregistrer rend le bilan hebdomadaire fidèle.',
    'es':
        'Los tentempiés también cuentan: registrarlos hace que el resumen semanal sea fiel.',
    'tr':
        'Atıştırmalıklar da önemlidir; onları kaydetmek haftalık özeti gerçeğe uygun tutar.',
  },
  'KNOW YOUR PATTERN': {
    'ar': 'اعرف نمطك',
    'fr': 'CONNAISSEZ VOTRE TENDANCE',
    'es': 'CONOCE TU PATRÓN',
    'tr': 'DÜZENİNİZİ TANIYIN',
  },
  'Alcohol can affect sleep, hydration and recovery.': {
    'ar': 'قد يؤثر الكحول في النوم والترطيب والتعافي.',
    'fr':
        'L’alcool peut affecter le sommeil, l’hydratation et la récupération.',
    'es':
        'El alcohol puede afectar el sueño, la hidratación y la recuperación.',
    'tr': 'Alkol uyku, sıvı dengesi ve toparlanmayı etkileyebilir.',
  },
  'More on the way': {
    'fr': 'D’autres analyses arrivent',
    'es': 'Hay más en camino',
    'tr': 'Daha fazlası yolda',
  },
  'Keep logging foods to unlock more personalized patterns and weekly insights.': {
    'ar': 'واصل تسجيل الطعام لاكتشاف مزيد من الأنماط المخصصة والرؤى الأسبوعية.',
    'fr':
        'Continuez à enregistrer vos aliments pour révéler davantage de tendances personnalisées et d’analyses hebdomadaires.',
    'es':
        'Sigue registrando alimentos para descubrir más patrones personalizados y análisis semanales.',
    'tr':
        'Daha kişisel düzenleri ve haftalık analizleri görmek için yiyecekleri kaydetmeye devam edin.',
  },
  'FOOD INSIGHTS': {
    'fr': 'ANALYSES ALIMENTAIRES',
    'es': 'ANÁLISIS DE ALIMENTOS',
    'tr': 'BESLENME ANALİZLERİ',
  },
  'Your feedback helps us make these weekly patterns more useful.': {
    'ar': 'تساعدنا ملاحظتك في جعل هذه الأنماط الأسبوعية أكثر فائدة.',
    'fr':
        'Votre avis nous aide à rendre ces tendances hebdomadaires plus utiles.',
    'es':
        'Tus comentarios nos ayudan a hacer más útiles estos patrones semanales.',
    'tr':
        'Geri bildiriminiz bu haftalık düzenleri daha yararlı hâle getirmemize yardımcı olur.',
  },
  'BIL INSIGHT': {
    'fr': 'ANALYSE BIL',
    'es': 'ANÁLISIS BIL',
    'tr': 'BIL ANALİZİ',
  },
  'Weekly calories chart': {
    'ar': 'مخطط السعرات الأسبوعي',
    'fr': 'Graphique hebdomadaire des calories',
    'es': 'Gráfico semanal de calorías',
    'tr': 'Haftalık kalori grafiği',
  },
  'Seven day exercise and steps chart': {
    'ar': 'مخطط التمارين والخطوات لسبعة أيام',
    'fr': 'Graphique des exercices et des pas sur sept jours',
    'es': 'Gráfico de ejercicio y pasos de siete días',
    'tr': 'Yedi günlük egzersiz ve adım grafiği',
  },
  'No steps logged': {
    'ar': 'لا توجد خطوات مسجلة',
    'fr': 'Aucun pas enregistré',
    'es': 'No hay pasos registrados',
    'tr': 'Kaydedilmiş adım yok',
  },
};
