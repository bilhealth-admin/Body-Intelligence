part of 'progress_page.dart';

class _ProgressCopy {
  const _ProgressCopy(this.v);
  final Map<String, String> v;
  String t(String key) => v[key]!;
  String get progress => t('progress');
  String get metric => t('metric');
  String get range => t('range');
  String get selectMetric => t('selectMetric');
  String get selectRange => t('selectRange');
  String get stepsUnit => t('stepsUnit');
  String get latest => t('latest');
  String get noRecords => t('noRecords');
  String get unavailable => t('unavailable');
  String get currentOnly => t('currentOnly');
  String get noCurrentMeasurement => t('noCurrentMeasurement');
  String get hipsUnavailable => t('hipsUnavailable');
  String get addEditWeight => t('addEditWeight');
  String get editMeasurements => t('editMeasurements');
  String get shareProgress => t('shareProgress');
  String get average => t('average');
  String get best => t('best');
  String get total => t('total');
  String get start => t('start');
  String get current => t('current');
  String get change => t('change');
  String get entries => t('entries');
  String get retry => t('retry');
  String get shareUnavailable => t('shareUnavailable');
  String get neck => t('neck');
  String get waist => t('waist');
  String metricLabel(ProgressMetric value) => t(value.name);
  String rangeLabel(ProgressRange value) => t(value.name);
  String recordCount(int count) => '${t('records')}: $count';
  String chartSummary(
    String metric,
    String range,
    int count,
    double minimum,
    double maximum,
    double latest,
    String unit,
  ) =>
      '$metric, $range. $count ${t('records')}. '
      '${t('minimum')}: ${minimum.toStringAsFixed(1)} $unit. '
      '${t('maximum')}: ${maximum.toStringAsFixed(1)} $unit. '
      '${t('latest')}: ${latest.toStringAsFixed(1)} $unit.';
  String shareText(
    String metric,
    String range,
    int count,
    double start,
    double current,
    double change,
    String unit, {
    bool wholeNumbers = false,
  }) {
    String format(double value) =>
        wholeNumbers ? value.round().toString() : value.toStringAsFixed(1);
    return '$metric · $range\n'
        '${t('records')}: $count\n'
        '${t('start')}: ${format(start)} $unit\n'
        '${t('current')}: ${format(current)} $unit\n'
        '${t('change')}: ${change >= 0 ? '+' : ''}${format(change)} $unit';
  }

  static _ProgressCopy of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return _ProgressCopy(progressCopyForLocale(locale.toLanguageTag()));
  }
}

Map<String, String> progressCopyForLocale(String localeTag) {
  final language = localeTag.replaceAll('_', '-').split('-').first;
  final authored = _progressCopy[language];
  if (authored != null) return authored;
  return {
    for (final entry in _progressCopy['en']!.entries)
      entry.key: RuntimeCopy.resolve(entry.value, localeTag) ?? entry.value,
  };
}

const _progressCopy = <String, Map<String, String>>{
  'en': {
    'progress': 'Progress',
    'metric': 'Metric',
    'range': 'Date range',
    'selectMetric': 'Select a measurement',
    'selectRange': 'Select a date range',
    'steps': 'Steps',
    'weight': 'Weight',
    'neck': 'Neck',
    'waist': 'Waist',
    'hips': 'Hips',
    'chest': 'Chest',
    'arm': 'Arm',
    'thigh': 'Thigh',
    'week': '1w',
    'month': '1m',
    'twoMonths': '2m',
    'threeMonths': '3m',
    'sixMonths': '6m',
    'year': '1y',
    'all': 'All',
    'stepsUnit': 'steps',
    'latest': 'Latest',
    'records': 'Recorded days',
    'noRecords': 'No real records are available for this metric and range.',
    'unavailable': 'Local progress data is temporarily unavailable.',
    'currentOnly':
        'This is the current profile measurement. Measurement history is not stored yet.',
    'noCurrentMeasurement':
        'No current measurement is saved. Add or edit it in your profile.',
    'hipsUnavailable':
        'Hip measurement is unavailable because the current profile schema does not store it.',
    'addEditWeight': 'Add or edit weight',
    'editMeasurements': 'Edit measurements',
    'shareProgress': 'Share progress',
    'average': 'Average',
    'best': 'Best',
    'total': 'Total',
    'start': 'Start',
    'current': 'Current',
    'change': 'Change',
    'entries': 'Entries',
    'retry': 'Retry',
    'minimum': 'Minimum',
    'maximum': 'Maximum',
    'shareUnavailable': 'Sharing is unavailable on this device.',
  },
  'ar': {
    'progress': 'التقدم',
    'metric': 'المقياس',
    'range': 'الفترة الزمنية',
    'selectMetric': 'اختر قياسًا',
    'selectRange': 'اختر فترة زمنية',
    'steps': 'الخطوات',
    'weight': 'الوزن',
    'neck': 'الرقبة',
    'waist': 'الخصر',
    'hips': 'الورك',
    'chest': 'الصدر',
    'arm': 'الذراع',
    'thigh': 'الفخذ',
    'week': 'أسبوع',
    'month': 'شهر',
    'twoMonths': 'شهران',
    'threeMonths': '3 أشهر',
    'sixMonths': '6 أشهر',
    'year': 'سنة',
    'all': 'الكل',
    'stepsUnit': 'خطوة',
    'latest': 'الأحدث',
    'records': 'أيام مسجلة',
    'noRecords': 'لا توجد سجلات حقيقية لهذا المقياس وهذه المدة.',
    'unavailable': 'بيانات التقدم المحلية غير متاحة مؤقتًا.',
    'currentOnly':
        'هذه قياسة الملف الشخصي الحالية. لا يُحفظ تاريخ القياسات بعد.',
    'noCurrentMeasurement':
        'لا توجد قياسة حالية محفوظة. أضفها أو عدّلها في ملفك.',
    'hipsUnavailable': 'قياس الورك غير متاح لأن مخطط الملف الحالي لا يخزنه.',
    'addEditWeight': 'إضافة أو تعديل الوزن',
    'editMeasurements': 'تعديل القياسات',
    'shareProgress': 'مشاركة التقدم',
    'average': 'المتوسط',
    'best': 'الأفضل',
    'total': 'الإجمالي',
    'start': 'البداية',
    'current': 'الحالي',
    'change': 'التغير',
    'entries': 'الإدخالات',
    'retry': 'إعادة المحاولة',
    'minimum': 'الأدنى',
    'maximum': 'الأعلى',
    'shareUnavailable': 'المشاركة غير متاحة على هذا الجهاز.',
  },
  'fr': {
    'progress': 'Progression',
    'metric': 'Mesure',
    'range': 'Période',
    'selectMetric': 'Choisir une mesure',
    'selectRange': 'Choisir une période',
    'steps': 'Pas',
    'weight': 'Poids',
    'neck': 'Cou',
    'waist': 'Tour de taille',
    'hips': 'Hanches',
    'chest': 'Poitrine',
    'arm': 'Bras',
    'thigh': 'Cuisse',
    'week': '1 sem.',
    'month': '1 mois',
    'twoMonths': '2 mois',
    'threeMonths': '3 mois',
    'sixMonths': '6 mois',
    'year': '1 an',
    'all': 'Tout',
    'stepsUnit': 'pas',
    'latest': 'Dernière valeur',
    'records': 'Jours enregistrés',
    'noRecords': 'Aucune donnée réelle pour cette mesure et cette période.',
    'unavailable': 'Les données locales sont temporairement indisponibles.',
    'currentOnly':
        'Il s’agit de la mesure actuelle du profil. L’historique n’est pas encore stocké.',
    'noCurrentMeasurement':
        'Aucune mesure actuelle enregistrée. Ajoutez-la dans votre profil.',
    'hipsUnavailable':
        'La mesure des hanches est indisponible car le schéma actuel ne la stocke pas.',
    'addEditWeight': 'Ajouter ou modifier le poids',
    'editMeasurements': 'Modifier les mesures',
    'shareProgress': 'Partager la progression',
    'average': 'Moyenne',
    'best': 'Meilleur',
    'total': 'Total',
    'start': 'Début',
    'current': 'Actuel',
    'change': 'Variation',
    'entries': 'Entrées',
    'retry': 'Réessayer',
    'minimum': 'Minimum',
    'maximum': 'Maximum',
    'shareUnavailable': 'Le partage est indisponible sur cet appareil.',
  },
  'es': {
    'progress': 'Progreso',
    'metric': 'Métrica',
    'range': 'Periodo',
    'selectMetric': 'Seleccionar medida',
    'selectRange': 'Seleccionar periodo',
    'steps': 'Pasos',
    'weight': 'Peso',
    'neck': 'Cuello',
    'waist': 'Cintura',
    'hips': 'Caderas',
    'chest': 'Pecho',
    'arm': 'Brazo',
    'thigh': 'Muslo',
    'week': '1 sem.',
    'month': '1 mes',
    'twoMonths': '2 meses',
    'threeMonths': '3 meses',
    'sixMonths': '6 meses',
    'year': '1 año',
    'all': 'Todo',
    'stepsUnit': 'pasos',
    'latest': 'Último',
    'records': 'Días registrados',
    'noRecords': 'No hay registros reales para esta métrica y periodo.',
    'unavailable': 'Los datos locales no están disponibles temporalmente.',
    'currentOnly':
        'Esta es la medida actual del perfil. Aún no se guarda historial.',
    'noCurrentMeasurement':
        'No hay una medida actual guardada. Añádela en tu perfil.',
    'hipsUnavailable':
        'La medida de caderas no está disponible porque el esquema actual no la almacena.',
    'addEditWeight': 'Añadir o editar peso',
    'editMeasurements': 'Editar medidas',
    'shareProgress': 'Compartir progreso',
    'average': 'Promedio',
    'best': 'Mejor',
    'total': 'Total',
    'start': 'Inicio',
    'current': 'Actual',
    'change': 'Cambio',
    'entries': 'Entradas',
    'retry': 'Reintentar',
    'minimum': 'Mínimo',
    'maximum': 'Máximo',
    'shareUnavailable': 'Compartir no está disponible en este dispositivo.',
  },
  'tr': {
    'progress': 'İlerleme',
    'metric': 'Ölçüm',
    'range': 'Tarih aralığı',
    'selectMetric': 'Ölçüm seç',
    'selectRange': 'Tarih aralığı seç',
    'steps': 'Adımlar',
    'weight': 'Kilo',
    'neck': 'Boyun',
    'waist': 'Bel',
    'hips': 'Kalça',
    'chest': 'Göğüs',
    'arm': 'Kol',
    'thigh': 'Uyluk',
    'week': '1 hf.',
    'month': '1 ay',
    'twoMonths': '2 ay',
    'threeMonths': '3 ay',
    'sixMonths': '6 ay',
    'year': '1 yıl',
    'all': 'Tümü',
    'stepsUnit': 'adım',
    'latest': 'En son',
    'records': 'Kayıtlı gün',
    'noRecords': 'Bu ölçüm ve aralık için gerçek kayıt yok.',
    'unavailable': 'Yerel ilerleme verileri geçici olarak kullanılamıyor.',
    'currentOnly':
        'Bu, mevcut profil ölçümüdür. Ölçüm geçmişi henüz saklanmıyor.',
    'noCurrentMeasurement': 'Kayıtlı güncel ölçüm yok. Profilinizden ekleyin.',
    'hipsUnavailable':
        'Kalça ölçümü mevcut profil şemasında saklanmadığı için kullanılamıyor.',
    'addEditWeight': 'Kilo ekle veya düzenle',
    'editMeasurements': 'Ölçümleri düzenle',
    'shareProgress': 'İlerlemeyi paylaş',
    'average': 'Ortalama',
    'best': 'En iyi',
    'total': 'Toplam',
    'start': 'Başlangıç',
    'current': 'Güncel',
    'change': 'Değişim',
    'entries': 'Kayıtlar',
    'retry': 'Yeniden dene',
    'minimum': 'En düşük',
    'maximum': 'En yüksek',
    'shareUnavailable': 'Paylaşım bu cihazda kullanılamıyor.',
  },
};
