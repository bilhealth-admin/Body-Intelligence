import 'package:flutter/widgets.dart' show Locale;

import '../../app/localization/app_localizations.dart';

String dashboardFiveLocaleText(
  String english,
  String arabic, {
  Locale? locale,
}) {
  final resolvedLocale = locale ?? AppLocalizations.activeLocale;
  final authored =
      _dashboardAuthoredCopy[english]?[resolvedLocale.languageCode];
  if (authored != null) return authored;
  if (resolvedLocale.languageCode == 'ar') return arabic;
  final localized = AppLocalizations(resolvedLocale).text(english);
  return localized;
}

const _dashboardAuthoredCopy = <String, Map<String, String>>{
  'ONE BEST ACTION': {
    'fr': 'MEILLEURE ACTION',
    'es': 'MEJOR ACCIÓN',
    'tr': 'EN İYİ EYLEM',
  },
  'View decision details': {
    'fr': 'Voir les détails de la décision',
    'es': 'Ver detalles de la decisión',
    'tr': 'Karar ayrıntılarını gör',
  },
  'I’ll do it': {'fr': 'Je vais le faire', 'es': 'Lo haré', 'tr': 'Yapacağım'},
  'Done': {'fr': 'Terminé', 'es': 'Hecho', 'tr': 'Tamamlandı'},
  'Not suitable': {
    'fr': 'Pas adapté',
    'es': 'No es adecuado',
    'tr': 'Uygun değil',
  },
  'Take action now': {
    'fr': 'Agir maintenant',
    'es': 'Actuar ahora',
    'tr': 'Şimdi harekete geç',
  },
  'Why BIL believes this': {
    'fr': 'Pourquoi BIL le pense',
    'es': 'Por qué BIL piensa esto',
    'tr': 'BIL neden böyle düşünüyor',
  },
  'Interpretation': {
    'fr': 'Interprétation',
    'es': 'Interpretación',
    'tr': 'Yorum',
  },
  'Evidence used': {
    'fr': 'Preuves utilisées',
    'es': 'Evidencia utilizada',
    'tr': 'Kullanılan kanıt',
  },
  'Confidence': {'fr': 'Confiance', 'es': 'Confianza', 'tr': 'Güven'},
  'Evidence gap': {
    'fr': 'Manque de preuves',
    'es': 'Falta de evidencia',
    'tr': 'Kanıt açığı',
  },
  'Why BIL is holding back': {
    'fr': 'Pourquoi BIL reste prudent',
    'es': 'Por qué BIL se contiene',
    'tr': 'BIL neden bekliyor',
  },
  'Evidence': {'fr': 'Preuves', 'es': 'Evidencia', 'tr': 'Kanıt'},
  'LOGGING COMPLETENESS': {
    'fr': 'COMPLÉTUDE DU SUIVI',
    'es': 'INTEGRIDAD DEL REGISTRO',
    'tr': 'KAYIT TAMLIĞI',
  },
  'Open BIL Guide': {
    'fr': 'Ouvrir le guide BIL',
    'es': 'Abrir la guía de BIL',
    'tr': 'BIL Rehberini aç',
  },
  'BIL GUIDE': {'fr': 'GUIDE BIL', 'es': 'GUÍA BIL', 'tr': 'BIL REHBERİ'},
  'Ready to begin': {
    'fr': 'Prêt à commencer',
    'es': 'Listo para empezar',
    'tr': 'Başlamaya hazır',
  },
  'Preparing your daily brief': {
    'fr': 'Préparation de votre résumé quotidien',
    'es': 'Preparando tu resumen diario',
    'tr': 'Günlük özetiniz hazırlanıyor',
  },
  'Retry': {'fr': 'Réessayer', 'es': 'Reintentar', 'tr': 'Tekrar dene'},
  'Customize Today': {
    'fr': 'Personnaliser Aujourd’hui',
    'es': 'Personalizar Hoy',
    'tr': 'Bugünü özelleştir',
  },
  'Restore default view': {
    'fr': 'Rétablir l’affichage par défaut',
    'es': 'Restaurar vista predeterminada',
    'tr': 'Varsayılan görünümü geri yükle',
  },
  'Done editing': {
    'fr': 'Terminer la modification',
    'es': 'Terminar edición',
    'tr': 'Düzenlemeyi bitir',
  },
  'Today preferences could not be saved. Please try again.': {
    'fr': 'Impossible d’enregistrer les préférences d’aujourd’hui. Réessayez.',
    'es': 'No se pudieron guardar las preferencias de Hoy. Inténtalo de nuevo.',
    'tr': 'Bugün tercihleri kaydedilemedi. Tekrar deneyin.',
  },
  'A private conversation with your health intelligence': {
    'fr': 'Une conversation privée avec votre intelligence santé',
    'es': 'Una conversación privada con tu inteligencia de salud',
    'tr': 'Sağlık zekânızla özel bir sohbet',
  },
  'Goal, food, exercise, and remaining energy': {
    'fr': 'Objectif, alimentation, exercice et énergie restante',
    'es': 'Objetivo, comida, ejercicio y energía restante',
    'tr': 'Hedef, yemek, egzersiz ve kalan enerji',
  },
  'Protein and fat progress': {
    'fr': 'Progression des protéines et lipides',
    'es': 'Progreso de proteína y grasa',
    'tr': 'Protein ve yağ ilerlemesi',
  },
  'Steps and exercise status': {
    'fr': 'État des pas et de l’exercice',
    'es': 'Estado de pasos y ejercicio',
    'tr': 'Adım ve egzersiz durumu',
  },
  'Food, water, and weight shortcuts': {
    'fr': 'Raccourcis alimentation, eau et poids',
    'es': 'Atajos de comida, agua y peso',
    'tr': 'Yemek, su ve kilo kısayolları',
  },
  'Sleep, recipes, workouts, and community': {
    'fr': 'Sommeil, recettes, entraînements et communauté',
    'es': 'Sueño, recetas, entrenamientos y comunidad',
    'tr': 'Uyku, tarifler, antrenmanlar ve topluluk',
  },
  'One Best Action, evidence, and Body Twin': {
    'fr': 'Meilleure action, preuves et jumeau corporel',
    'es': 'Mejor acción, evidencia y gemelo corporal',
    'tr': 'En iyi eylem, kanıt ve beden ikizi',
  },
  'Explanations, confidence, and evidence': {
    'fr': 'Explications, confiance et preuves',
    'es': 'Explicaciones, confianza y evidencia',
    'tr': 'Açıklamalar, güven ve kanıt',
  },
  'Measured trends from your saved records': {
    'fr': 'Tendances mesurées à partir de vos données enregistrées',
    'es': 'Tendencias medidas desde tus registros guardados',
    'tr': 'Kaydedilmiş verilerinizden ölçülen eğilimler',
  },
  'Health sources and synchronization status': {
    'fr': 'Sources de santé et état de synchronisation',
    'es': 'Fuentes de salud y estado de sincronización',
    'tr': 'Sağlık kaynakları ve eşitleme durumu',
  },
  'Your explainable body model and its evidence': {
    'fr': 'Votre modèle corporel explicable et ses preuves',
    'es': 'Tu modelo corporal explicable y su evidencia',
    'tr': 'Açıklanabilir beden modeliniz ve kanıtları',
  },
  'Choose what appears on Today. Your data stays saved and every card can be restored at any time.': {
    'fr':
        'Choisissez ce qui apparaît dans Aujourd’hui. Vos données restent enregistrées et chaque carte peut être restaurée.',
    'es':
        'Elige qué aparece en Hoy. Tus datos permanecen guardados y puedes restaurar cualquier tarjeta.',
    'tr':
        'Bugün ekranında nelerin görüneceğini seçin. Verileriniz kayıtlı kalır ve her kart geri getirilebilir.',
  },
  'Choose the information that matters most to you': {
    'fr': 'Choisissez les informations les plus importantes pour vous',
    'es': 'Elige la información más importante para ti',
    'tr': 'Sizin için en önemli bilgileri seçin',
  },
  'Calorie focused': {
    'fr': 'Axé sur les calories',
    'es': 'Enfoque en calorías',
    'tr': 'Kalori odaklı',
  },
  'Calories consumed, activity, and remaining energy.': {
    'fr': 'Calories consommées, activité et énergie restante.',
    'es': 'Calorías consumidas, actividad y energía restante.',
    'tr': 'Tüketilen kalori, aktivite ve kalan enerji.',
  },
  'Macronutrients focused': {
    'fr': 'Axé sur les macronutriments',
    'es': 'Enfoque en macronutrientes',
    'tr': 'Makro besin odaklı',
  },
  'Carbs, protein, fat, and remaining calories.': {
    'fr': 'Glucides, protéines, lipides et calories restantes.',
    'es': 'Carbohidratos, proteína, grasa y calorías restantes.',
    'tr': 'Karbonhidrat, protein, yağ ve kalan kalori.',
  },
  'Heart and activity view': {
    'fr': 'Vue cœur et activité',
    'es': 'Vista de corazón y actividad',
    'tr': 'Kalp ve aktivite görünümü',
  },
  'Nutrition, activity, and connected health together.': {
    'fr': 'Nutrition, activité et santé connectée réunies.',
    'es': 'Nutrición, actividad y salud conectada juntas.',
    'tr': 'Beslenme, aktivite ve bağlı sağlık bir arada.',
  },
  'Low carb': {
    'fr': 'Faible en glucides',
    'es': 'Bajo en carbohidratos',
    'tr': 'Düşük karbonhidrat',
  },
  'Macros, calories, quick logging, and evidence.': {
    'fr': 'Macros, calories, saisie rapide et preuves.',
    'es': 'Macros, calorías, registro rápido y evidencia.',
    'tr': 'Makrolar, kalori, hızlı kayıt ve kanıt.',
  },
  'Custom': {'fr': 'Personnalisé', 'es': 'Personalizado', 'tr': 'Özel'},
  'Choose each card below.': {
    'fr': 'Choisissez chaque carte ci-dessous.',
    'es': 'Elige cada tarjeta a continuación.',
    'tr': 'Aşağıdan her kartı seçin.',
  },
  'Custom cards': {
    'fr': 'Cartes personnalisées',
    'es': 'Tarjetas personalizadas',
    'tr': 'Özel kartlar',
  },
  'Add nutrient goal cards': {
    'fr': 'Ajouter des cartes de nutriments',
    'es': 'Añadir tarjetas de nutrientes',
    'tr': 'Besin hedefi kartları ekle',
  },
  'Save cards': {
    'fr': 'Enregistrer les cartes',
    'es': 'Guardar tarjetas',
    'tr': 'Kartları kaydet',
  },
  'Protein': {'fr': 'Protéines', 'es': 'Proteína', 'tr': 'Protein'},
  'Carbohydrates': {
    'fr': 'Glucides',
    'es': 'Carbohidratos',
    'tr': 'Karbonhidratlar',
  },
  'Fat': {'fr': 'Lipides', 'es': 'Grasas', 'tr': 'Yağ'},
  'Fiber': {'fr': 'Fibres', 'es': 'Fibra', 'tr': 'Lif'},
  'Sodium': {'fr': 'Sodium', 'es': 'Sodio', 'tr': 'Sodyum'},
  'Potassium': {'fr': 'Potassium', 'es': 'Potasio', 'tr': 'Potasyum'},
  'Loading saved view': {
    'fr': 'Chargement de la vue enregistrée',
    'es': 'Cargando la vista guardada',
    'tr': 'Kayıtlı görünüm yükleniyor',
  },
  'Saved view could not be loaded.': {
    'fr': 'Impossible de charger la vue enregistrée.',
    'es': 'No se pudo cargar la vista guardada.',
    'tr': 'Kayıtlı görünüm yüklenemedi.',
  },
  'Loading saved cards': {
    'fr': 'Chargement des cartes enregistrées',
    'es': 'Cargando tarjetas guardadas',
    'tr': 'Kayıtlı kartlar yükleniyor',
  },
  'Cards could not be loaded. Tap to retry.': {
    'fr': 'Impossible de charger les cartes. Touchez pour réessayer.',
    'es': 'No se pudieron cargar las tarjetas. Toca para reintentar.',
    'tr': 'Kartlar yüklenemedi. Yeniden denemek için dokunun.',
  },
  'selected': {'fr': 'sélectionnées', 'es': 'seleccionadas', 'tr': 'seçildi'},
  'Retry subscription check': {
    'fr': 'Revérifier l’abonnement',
    'es': 'Volver a comprobar la suscripción',
    'tr': 'Aboneliği yeniden denetle',
  },
  'Saved setting could not be loaded. Tap to retry.': {
    'fr': 'Impossible de charger le réglage. Touchez pour réessayer.',
    'es': 'No se pudo cargar el ajuste. Toca para reintentar.',
    'tr': 'Ayar yüklenemedi. Yeniden denemek için dokunun.',
  },
  'above the reference target': {
    'fr': 'au-dessus de l’objectif de référence',
    'es': 'por encima del objetivo de referencia',
    'tr': 'referans hedefin üzerinde',
  },
  'remaining': {'fr': 'restants', 'es': 'restantes', 'tr': 'kaldı'},
  'Value unavailable in the logged food evidence.': {
    'fr': 'Valeur indisponible dans les données alimentaires enregistrées.',
    'es': 'Valor no disponible en la evidencia de alimentos registrada.',
    'tr': 'Kayıtlı besin kanıtında değer kullanılamıyor.',
  },
  'Partial evidence; foods with unavailable values are excluded.': {
    'fr':
        'Preuves partielles ; les aliments sans valeur disponible sont exclus.',
    'es':
        'Evidencia parcial; se excluyen alimentos con valores no disponibles.',
    'tr': 'Kısmi kanıt; değeri olmayan yiyecekler hariç tutulur.',
  },
  'Partial evidence: total includes only foods with known values.': {
    'fr':
        'Preuves partielles : le total ne comprend que les aliments aux valeurs connues.',
    'es':
        'Evidencia parcial: el total solo incluye alimentos con valores conocidos.',
    'tr': 'Kısmi kanıt: toplam yalnızca değeri bilinen yiyecekleri içerir.',
  },
};
