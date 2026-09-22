part of 'daily_log_input_sections.dart';

String dailyLogPrivateNoteLabel() =>
    _inputText('Private daily note', 'ملاحظة يومية خاصة');

String _inputText(String en, String ar) {
  final activeLocale = AppLocalizations.activeLocale;
  final tag = BilLocalePolicy.canonicalTag(activeLocale);
  final locale = activeLocale.languageCode.toLowerCase();
  if (locale == 'ar') return ar;
  if (en.endsWith(' selected')) {
    final count = en.split(' ').first;
    return switch (locale) {
      'fr' => '$count sélectionnés',
      'es' => '$count seleccionados',
      'tr' => '$count seçildi',
      _ => (RuntimeCopy.resolve('{count} selected', tag) ?? en).replaceFirst(
        '{count}',
        count,
      ),
    };
  }
  return _dailyInputCopy[en]?[locale] ?? RuntimeCopy.resolve(en, tag) ?? en;
}

const _dailyInputCopy = <String, Map<String, String>>{
  'Exercise': {'fr': 'Exercice', 'es': 'Ejercicio', 'tr': 'Egzersiz'},
  'Browse workouts': {
    'fr': 'Parcourir les entraînements',
    'es': 'Explorar entrenamientos',
    'tr': 'Antrenmanlara göz at',
  },
  'What did you do?': {
    'fr': 'Qu’avez-vous fait ?',
    'es': '¿Qué hiciste?',
    'tr': 'Ne yaptınız?',
  },
  'Example: brisk walk · 30 min': {
    'fr': 'Exemple : marche rapide · 30 min',
    'es': 'Ejemplo: caminata rápida · 30 min',
    'tr': 'Örnek: tempolu yürüyüş · 30 dk',
  },
  'Saved with this day. You can edit or clear it at any time.': {
    'fr':
        'Enregistré avec cette journée. Vous pouvez le modifier ou l’effacer à tout moment.',
    'es': 'Se guarda con este día. Puedes editarlo o borrarlo cuando quieras.',
    'tr':
        'Bu günle birlikte kaydedilir. İstediğiniz zaman düzenleyebilir veya silebilirsiniz.',
  },
  'Water': {'fr': 'Eau', 'es': 'Agua', 'tr': 'Su'},
  'ml': {'fr': 'ml', 'es': 'ml', 'tr': 'ml'},
  'Water amount (ml)': {
    'fr': 'Quantité d’eau (ml)',
    'es': 'Cantidad de agua (ml)',
    'tr': 'Su miktarı (ml)',
  },
  'Add water': {'fr': 'Ajouter de l’eau', 'es': 'Añadir agua', 'tr': 'Su ekle'},
  'Water total': {'fr': 'Total d’eau', 'es': 'Agua total', 'tr': 'Toplam su'},
  'Remove water entry': {
    'fr': 'Supprimer cette saisie d’eau',
    'es': 'Eliminar registro de agua',
    'tr': 'Su kaydını kaldır',
  },
  'Water data unavailable': {
    'fr': 'Données d’eau indisponibles',
    'es': 'Datos de agua no disponibles',
    'tr': 'Su verileri kullanılamıyor',
  },
  'Body context': {
    'fr': 'Contexte du corps',
    'es': 'Contexto corporal',
    'tr': 'Beden bağlamı',
  },
  'Select anything that may help explain today’s measurements.': {
    'fr': 'Sélectionnez tout élément pouvant expliquer les mesures du jour.',
    'es': 'Selecciona lo que pueda ayudar a explicar las mediciones de hoy.',
    'tr': 'Bugünkü ölçümleri açıklamaya yardımcı olabilecek öğeleri seçin.',
  },
  'Private daily note': {
    'fr': 'Note quotidienne privée',
    'es': 'Nota diaria privada',
    'tr': 'Özel günlük not',
  },
  'How did today feel?': {
    'fr': 'Comment s’est passée la journée ?',
    'es': '¿Cómo te sentiste hoy?',
    'tr': 'Bugün nasıl hissettiniz?',
  },
  'Add body context': {
    'fr': 'Ajouter un contexte corporel',
    'es': 'Añadir contexto corporal',
    'tr': 'Beden bağlamı ekle',
  },
  'Optional': {'fr': 'Facultatif', 'es': 'Opcional', 'tr': 'İsteğe bağlı'},
  'Other context': {
    'fr': 'Autre contexte',
    'es': 'Otro contexto',
    'tr': 'Diğer bağlam',
  },
  'Add a short optional note': {
    'fr': 'Ajoutez une courte note facultative',
    'es': 'Añade una nota breve opcional',
    'tr': 'Kısa bir isteğe bağlı not ekleyin',
  },
};
