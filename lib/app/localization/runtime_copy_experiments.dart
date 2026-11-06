import 'bil_locale_policy.dart';
import 'runtime_copy_extended.dart';

/// Completes the five base locales for experiment captions whose reviewed
/// twenty extended-locale entries already exist. Reuse those entries unchanged
/// so regional Portuguese and scripted Chinese keep their canonical wording.
abstract final class ExperimentsRuntimeCopy {
  static const _baseTags = <String>{'ar', 'en', 'fr', 'es', 'tr'};

  static const baseValues = <String, Map<String, String>>{
    'Your saved data was not changed. Try again.': {
      'ar': 'لم تتغير بياناتك المحفوظة. حاول مرة أخرى.',
      'en': 'Your saved data was not changed. Try again.',
      'fr': 'Vos données enregistrées n\'ont pas changé. Réessayez.',
      'es': 'Tus datos guardados no han cambiado. Inténtalo de nuevo.',
      'tr': 'Kaydedilmiş verileriniz değişmedi. Yeniden deneyin.',
    },
    'Learn what works for your body': {
      'ar': 'تعرّف على ما يناسب جسمك',
      'en': 'Learn what works for your body',
      'fr': 'Découvrez ce qui convient à votre corps',
      'es': 'Descubre qué funciona para tu cuerpo',
      'tr': 'Vücudunuz için neyin işe yaradığını öğrenin',
    },
    'BIL is observing one change': {
      'ar': 'يراقب BIL تغييرًا واحدًا',
      'en': 'BIL is observing one change',
      'fr': 'BIL observe un seul changement',
      'es': 'BIL está observando un cambio',
      'tr': 'BIL tek bir değişikliği gözlemliyor',
    },
    'A few useful days can guide a practical decision. Longer history simply makes the signal stronger.': {
      'ar':
          'قد تساعد بضعة أيام مفيدة في توجيه قرار عملي. ويجعل السجل الأطول الإشارة أوضح.',
      'en':
          'A few useful days can guide a practical decision. Longer history simply makes the signal stronger.',
      'fr':
          'Quelques jours utiles peuvent guider une décision pratique. Un historique plus long rend simplement le signal plus solide.',
      'es':
          'Unos días útiles pueden orientar una decisión práctica. Un historial más largo simplemente refuerza la señal.',
      'tr':
          'Birkaç yararlı gün, pratik bir karara yol gösterebilir. Daha uzun geçmiş yalnızca sinyali güçlendirir.',
    },
    'Keep the change simple. Continue logging normally and BIL will carry the context into Coach replies.': {
      'ar':
          'أبقِ التغيير بسيطًا. واصل التسجيل كالمعتاد، وسيأخذ BIL هذا السياق في الحسبان ضمن ردود المدرب.',
      'en':
          'Keep the change simple. Continue logging normally and BIL will carry the context into Coach replies.',
      'fr':
          'Gardez le changement simple. Continuez à consigner vos données normalement et BIL intégrera ce contexte aux réponses du Coach.',
      'es':
          'Mantén el cambio sencillo. Sigue registrando con normalidad y BIL incorporará ese contexto a las respuestas del Coach.',
      'tr':
          'Değişikliği basit tutun. Her zamanki gibi kayıt tutmaya devam edin; BIL bu bağlamı Koç yanıtlarına taşıyacaktır.',
    },
    'Active experiment': {
      'ar': 'تجربة نشطة',
      'en': 'Active experiment',
      'fr': 'Expérience active',
      'es': 'Experimento activo',
      'tr': 'Aktif deney',
    },
    'Delete experiment': {
      'ar': 'حذف التجربة',
      'en': 'Delete experiment',
      'fr': 'Supprimer l\'expérience',
      'es': 'Eliminar experimento',
      'tr': 'Deneyi sil',
    },
    'Day': {'ar': 'اليوم', 'en': 'Day', 'fr': 'Jour', 'es': 'Día', 'tr': 'Gün'},
    'Record what happened': {
      'ar': 'سجّل ما حدث',
      'en': 'Record what happened',
      'fr': 'Notez ce qui s\'est passé',
      'es': 'Registra lo que ocurrió',
      'tr': 'Ne olduğunu kaydedin',
    },
    '7 days': {
      'ar': '7 أيام',
      'en': '7 days',
      'fr': '7 jours',
      'es': '7 días',
      'tr': '7 gün',
    },
    '3 days': {
      'ar': '3 أيام',
      'en': '3 days',
      'fr': '3 jours',
      'es': '3 días',
      'tr': '3 gün',
    },
    '14 days': {
      'ar': '14 يومًا',
      'en': '14 days',
      'fr': '14 jours',
      'es': '14 días',
      'tr': '14 gün',
    },
    'Protein-first breakfast': {
      'ar': 'فطور يبدأ بالبروتين',
      'en': 'Protein-first breakfast',
      'fr': 'Petit-déjeuner commençant par des protéines',
      'es': 'Desayuno que empieza por proteína',
      'tr': 'Proteinle başlayan kahvaltı',
    },
    'Learn whether mornings feel steadier': {
      'ar': 'تعرّف إن كانت فترة الصباح أكثر استقرارًا',
      'en': 'Learn whether mornings feel steadier',
      'fr': 'Découvrez si vos matinées sont plus stables',
      'es': 'Descubre si las mañanas se sienten más estables',
      'tr': 'Sabahların daha dengeli hissedilip hissedilmediğini öğrenin',
    },
    'A protein-first breakfast may improve my satiety and energy through the morning.': {
      'ar':
          'قد يحسّن الفطور الذي يبدأ بالبروتين شعوري بالشبع والطاقة خلال الصباح.',
      'en':
          'A protein-first breakfast may improve my satiety and energy through the morning.',
      'fr':
          'Un petit-déjeuner commençant par des protéines pourrait améliorer ma satiété et mon énergie durant la matinée.',
      'es':
          'Un desayuno que empieza por proteína podría mejorar mi saciedad y energía durante la mañana.',
      'tr':
          'Proteinle başlayan bir kahvaltı, sabah boyunca tokluğumu ve enerjimi iyileştirebilir.',
    },
    'Start breakfast with a consistent protein source': {
      'ar': 'ابدأ الفطور بمصدر بروتين ثابت',
      'en': 'Start breakfast with a consistent protein source',
      'fr': 'Commencez le petit-déjeuner par une source de protéines constante',
      'es': 'Empieza el desayuno con una fuente de proteína constante',
      'tr': 'Kahvaltıya tutarlı bir protein kaynağıyla başlayın',
    },
    'Keep breakfast time and normal activity reasonably consistent': {
      'ar': 'حافظ قدر الإمكان على ثبات موعد الفطور والنشاط المعتاد',
      'en': 'Keep breakfast time and normal activity reasonably consistent',
      'fr':
          'Gardez l\'heure du petit-déjeuner et l\'activité habituelle relativement constantes',
      'es':
          'Mantén razonablemente constantes la hora del desayuno y la actividad habitual',
      'tr': 'Kahvaltı saatini ve olağan aktiviteyi makul ölçüde tutarlı tutun',
    },
    'Breakfast, hunger, energy, and daily nutrition logs': {
      'ar': 'سجلات الفطور والجوع والطاقة والتغذية اليومية',
      'en': 'Breakfast, hunger, energy, and daily nutrition logs',
      'fr':
          'Journaux du petit-déjeuner, de la faim, de l\'énergie et de l\'alimentation quotidienne',
      'es': 'Registros del desayuno, hambre, energía y nutrición diaria',
      'tr': 'Kahvaltı, açlık, enerji ve günlük beslenme kayıtları',
    },
    'Consistent sleep window': {
      'ar': 'موعد نوم ثابت',
      'en': 'Consistent sleep window',
      'fr': 'Plage de sommeil régulière',
      'es': 'Horario de sueño constante',
      'tr': 'Tutarlı uyku aralığı',
    },
    'Test recovery without chasing one night': {
      'ar': 'اختبر التعافي دون التركيز على ليلة واحدة',
      'en': 'Test recovery without chasing one night',
      'fr': 'Testez la récupération sans vous focaliser sur une seule nuit',
      'es': 'Prueba la recuperación sin centrarte en una sola noche',
      'tr': 'Tek bir geceye odaklanmadan toparlanmayı test edin',
    },
    'A consistent sleep window may improve my reported energy and recovery.': {
      'ar': 'قد يحسّن ثبات موعد النوم مستويات الطاقة والتعافي التي أسجلها.',
      'en':
          'A consistent sleep window may improve my reported energy and recovery.',
      'fr':
          'Une plage de sommeil régulière pourrait améliorer l\'énergie et la récupération que je rapporte.',
      'es':
          'Un horario de sueño constante podría mejorar la energía y recuperación que registro.',
      'tr':
          'Tutarlı bir uyku aralığı, bildirdiğim enerji ve toparlanmayı iyileştirebilir.',
    },
    'Use the same bedtime window each night': {
      'ar': 'التزم بالفترة الزمنية نفسها للنوم كل ليلة',
      'en': 'Use the same bedtime window each night',
      'fr': 'Gardez la même plage de coucher chaque soir',
      'es': 'Usa la misma franja para acostarte cada noche',
      'tr': 'Her gece aynı yatış saati aralığını kullanın',
    },
    'Keep caffeine timing and training reasonably consistent': {
      'ar': 'حافظ قدر الإمكان على ثبات موعد الكافيين والتدريب',
      'en': 'Keep caffeine timing and training reasonably consistent',
      'fr':
          'Gardez les horaires de caféine et l\'entraînement relativement constants',
      'es':
          'Mantén razonablemente constantes el horario de la cafeína y el entrenamiento',
      'tr': 'Kafein saatini ve antrenmanı makul ölçüde tutarlı tutun',
    },
    'Sleep hours, energy, and activity logs': {
      'ar': 'سجلات ساعات النوم والطاقة والنشاط',
      'en': 'Sleep hours, energy, and activity logs',
      'fr': 'Journaux des heures de sommeil, de l\'énergie et de l\'activité',
      'es': 'Registros de horas de sueño, energía y actividad',
      'tr': 'Uyku süresi, enerji ve aktivite kayıtları',
    },
    'Walk after dinner': {
      'ar': 'المشي بعد العشاء',
      'en': 'Walk after dinner',
      'fr': 'Marcher après le dîner',
      'es': 'Caminar después de cenar',
      'tr': 'Akşam yemeğinden sonra yürüyüş',
    },
    'Observe digestion, sleep, and consistency': {
      'ar': 'راقب الهضم والنوم والانتظام',
      'en': 'Observe digestion, sleep, and consistency',
      'fr': 'Observez la digestion, le sommeil et la régularité',
      'es': 'Observa la digestión, el sueño y la constancia',
      'tr': 'Sindirimi, uykuyu ve tutarlılığı gözlemleyin',
    },
    'A short walk after dinner may improve how I feel later in the evening.': {
      'ar': 'قد يحسّن مشي قصير بعد العشاء شعوري في وقت لاحق من المساء.',
      'en':
          'A short walk after dinner may improve how I feel later in the evening.',
      'fr':
          'Une courte marche après le dîner pourrait améliorer mon ressenti plus tard dans la soirée.',
      'es':
          'Un paseo corto después de cenar podría mejorar cómo me siento más tarde esa noche.',
      'tr':
          'Akşam yemeğinden sonra kısa bir yürüyüş, akşamın ilerleyen saatlerinde nasıl hissettiğimi iyileştirebilir.',
    },
    'Take a 10-minute walk after dinner': {
      'ar': 'امشِ لمدة 10 دقائق بعد العشاء',
      'en': 'Take a 10-minute walk after dinner',
      'fr': 'Faites une marche de 10 minutes après le dîner',
      'es': 'Da un paseo de 10 minutos después de cenar',
      'tr': 'Akşam yemeğinden sonra 10 dakikalık yürüyüş yapın',
    },
    'Keep dinner timing and portion broadly comparable': {
      'ar': 'حافظ على تقارب موعد العشاء وحجم الحصة عمومًا',
      'en': 'Keep dinner timing and portion broadly comparable',
      'fr':
          'Gardez l\'horaire du dîner et les portions globalement comparables',
      'es':
          'Mantén aproximadamente comparables la hora de la cena y las porciones',
      'tr': 'Akşam yemeği saatini ve porsiyonu genel olarak benzer tutun',
    },
    'Dinner, activity, sleep, and how you felt': {
      'ar': 'العشاء والنشاط والنوم وكيف شعرت',
      'en': 'Dinner, activity, sleep, and how you felt',
      'fr': 'Dîner, activité, sommeil et votre ressenti',
      'es': 'Cena, actividad, sueño y cómo te sentiste',
      'tr': 'Akşam yemeği, aktivite, uyku ve nasıl hissettiğiniz',
    },
  };

  static String? resolve(String source, String localeTag) {
    final base = baseValues[source];
    if (base == null) return null;
    final canonical = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (canonical == null) return null;
    return _baseTags.contains(canonical)
        ? base[canonical]
        : ExtendedRuntimeCopy.values[source]?[canonical];
  }

  static bool get balanced => baseValues.entries.every(
    (entry) =>
        entry.value.length == _baseTags.length &&
        entry.value.keys.toSet().containsAll(_baseTags) &&
        entry.value['en'] == entry.key &&
        BilLocalePolicy.productionTags.every(
          (tag) => resolve(entry.key, tag)?.trim().isNotEmpty == true,
        ),
  );
}
