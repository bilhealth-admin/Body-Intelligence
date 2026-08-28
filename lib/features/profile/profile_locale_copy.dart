import 'package:flutter/widgets.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy_profile.dart';

String profileLocaleText(BuildContext context, String english, String arabic) {
  return profileLocaleTextForLocale(
    Localizations.localeOf(context),
    english,
    arabic,
  );
}

String profileLocaleTextForLocale(
  Locale locale,
  String english,
  String arabic,
) {
  final language = locale.languageCode;
  final tag = BilLocalePolicy.canonicalTag(locale);
  final reviewed = ProfileRuntimeCopy.resolve(english, tag);
  if (reviewed != null) return reviewed;
  if (language == 'ar') return arabic;
  return _authored[english]?[tag] ??
      _authored[english]?[language] ??
      AppLocalizations(locale).text(english);
}

String profileWeeklySessionsText(BuildContext context, int sessions) {
  return profileWeeklySessionsTextForLocale(
    Localizations.localeOf(context),
    sessions,
  );
}

String profileWeeklySessionsTextForLocale(Locale locale, int sessions) {
  return _fillProfileTemplate(
    _weeklySessionsTemplates[_profileSupportedTag(locale)]!,
    {'sessions': '$sessions'},
  );
}

String profileGoalTimelineRangeText(
  Locale locale, {
  required String minimumWeeks,
  required String maximumWeeks,
  required String earliestDate,
  required String latestDate,
}) {
  return _fillProfileTemplate(
    _goalTimelineRangeTemplates[_profileSupportedTag(locale)]!,
    {
      'min': minimumWeeks,
      'max': maximumWeeks,
      'earliest': earliestDate,
      'latest': latestDate,
    },
  );
}

String profileGoalTimelineSupportingText(
  Locale locale, {
  required String direction,
  required String lowRate,
  required String highRate,
  required String adherence,
}) {
  return _fillProfileTemplate(
    _goalTimelineSupportingTemplates[_profileSupportedTag(locale)]!,
    {
      'direction': direction,
      'low': lowRate,
      'high': highRate,
      'adherence': adherence,
    },
  );
}

bool get profileTimelineCopyBalanced {
  final supported = ProfileRuntimeCopy.supported;
  return <Map<String, String>>[
    _weeklySessionsTemplates,
    _goalTimelineRangeTemplates,
    _goalTimelineSupportingTemplates,
  ].every(
    (templates) =>
        templates.length == supported.length &&
        templates.keys.toSet().containsAll(supported) &&
        supported.containsAll(templates.keys) &&
        templates.values.every((value) => value.trim().isNotEmpty),
  );
}

String _profileSupportedTag(Locale locale) {
  return BilLocalePolicy.canonicalSupportedTag(
        BilLocalePolicy.canonicalTag(locale),
      ) ??
      'en';
}

String _fillProfileTemplate(String template, Map<String, String> replacements) {
  var value = template;
  for (final entry in replacements.entries) {
    value = value.replaceAll('{${entry.key}}', entry.value);
  }
  return value;
}

const _weeklySessionsTemplates = <String, String>{
  'ar': '{sessions} مرات أسبوعيًا',
  'en': '{sessions} per week',
  'fr': '{sessions} fois par semaine',
  'es': '{sessions} veces por semana',
  'tr': 'Haftada {sessions} kez',
  'de': '{sessions}-mal pro Woche',
  'it': '{sessions} volte a settimana',
  'pt-BR': '{sessions} vezes por semana',
  'pt-PT': '{sessions} vezes por semana',
  'ur': 'فی ہفتہ {sessions} بار',
  'fa': '{sessions} بار در هفته',
  'hi': 'प्रति सप्ताह {sessions} बार',
  'id': '{sessions} kali per minggu',
  'ms': '{sessions} kali seminggu',
  'ja': '週{sessions}回',
  'ko': '주 {sessions}회',
  'zh-Hans': '每周 {sessions} 次',
  'zh-Hant': '每週 {sessions} 次',
  'ru': '{sessions} раз в неделю',
  'bn': 'সপ্তাহে {sessions} বার',
  'vi': '{sessions} lần mỗi tuần',
  'th': '{sessions} ครั้งต่อสัปดาห์',
  'pl': '{sessions} razy w tygodniu',
  'nl': '{sessions} keer per week',
  'uk': '{sessions} разів на тиждень',
};

const _goalTimelineRangeTemplates = <String, String>{
  'ar': '{min}–{max} أسبوعًا · {earliest}–{latest}',
  'en': '{min}–{max} weeks · {earliest}–{latest}',
  'fr': '{min}–{max} semaines · {earliest}–{latest}',
  'es': '{min}–{max} semanas · {earliest}–{latest}',
  'tr': '{min}–{max} hafta · {earliest}–{latest}',
  'de': '{min}–{max} Wochen · {earliest}–{latest}',
  'it': '{min}–{max} settimane · {earliest}–{latest}',
  'pt-BR': '{min}–{max} semanas · {earliest}–{latest}',
  'pt-PT': '{min}–{max} semanas · {earliest}–{latest}',
  'ur': '{min}–{max} ہفتے · {earliest}–{latest}',
  'fa': '{min}–{max} هفته · {earliest}–{latest}',
  'hi': '{min}–{max} सप्ताह · {earliest}–{latest}',
  'id': '{min}–{max} minggu · {earliest}–{latest}',
  'ms': '{min}–{max} minggu · {earliest}–{latest}',
  'ja': '{min}〜{max}週間 · {earliest}〜{latest}',
  'ko': '{min}~{max}주 · {earliest}~{latest}',
  'zh-Hans': '{min}–{max} 周 · {earliest}–{latest}',
  'zh-Hant': '{min}–{max} 週 · {earliest}–{latest}',
  'ru': '{min}–{max} недель · {earliest}–{latest}',
  'bn': '{min}–{max} সপ্তাহ · {earliest}–{latest}',
  'vi': '{min}–{max} tuần · {earliest}–{latest}',
  'th': '{min}–{max} สัปดาห์ · {earliest}–{latest}',
  'pl': '{min}–{max} tyg. · {earliest}–{latest}',
  'nl': '{min}–{max} weken · {earliest}–{latest}',
  'uk': '{min}–{max} тижнів · {earliest}–{latest}',
};

const _goalTimelineSupportingTemplates = <String, String>{
  'ar':
      'نطاق {direction} مخطط: {low}–{high} كجم/أسبوع بافتراض التزام {adherence}٪. تقدير وليس ضمانًا.',
  'en':
      'Planned {direction} range {low}–{high} kg/week at {adherence}% adherence. Estimate, not a guarantee.',
  'fr':
      'Fourchette planifiée de {direction} : {low}–{high} kg/semaine avec {adherence} % d’adhérence. Estimation, sans garantie.',
  'es':
      'Rango planificado de {direction}: {low}–{high} kg/semana con {adherence} % de adherencia. Es una estimación, no una garantía.',
  'tr':
      '%{adherence} uyum varsayımıyla planlanan {direction} aralığı {low}–{high} kg/hafta. Bu bir tahmindir, garanti değildir.',
  'de':
      'Geplanter Bereich für {direction}: {low}–{high} kg/Woche bei {adherence} % Einhaltung. Schätzung, keine Garantie.',
  'it':
      'Intervallo pianificato di {direction}: {low}–{high} kg/settimana con un’aderenza del {adherence}%. È una stima, non una garanzia.',
  'pt-BR':
      'Faixa planejada de {direction}: {low}–{high} kg/semana com {adherence}% de adesão. É uma estimativa, não uma garantia.',
  'pt-PT':
      'Intervalo planeado de {direction}: {low}–{high} kg/semana com {adherence}% de adesão. É uma estimativa, não uma garantia.',
  'ur':
      '{direction} کی منصوبہ بند حد {low}–{high} کلوگرام فی ہفتہ ہے، {adherence}٪ پابندی فرض کرتے ہوئے۔ یہ تخمینہ ہے، ضمانت نہیں۔',
  'fa':
      'بازه برنامه‌ریزی‌شده {direction}، {low} تا {high} کیلوگرم در هفته با فرض پایبندی {adherence}٪ است. این برآورد است، نه تضمین.',
  'hi':
      '{adherence}% पालन मानकर {direction} की नियोजित सीमा {low}–{high} किग्रा/सप्ताह है। यह अनुमान है, गारंटी नहीं।',
  'id':
      'Rentang {direction} yang direncanakan {low}–{high} kg/minggu dengan kepatuhan {adherence}%. Ini perkiraan, bukan jaminan.',
  'ms':
      'Julat {direction} yang dirancang ialah {low}–{high} kg/minggu dengan pematuhan {adherence}%. Ini anggaran, bukan jaminan.',
  'ja':
      '計画上の{direction}幅は、達成率{adherence}%を前提に週{low}〜{high} kgです。これは推定であり、保証ではありません。',
  'ko':
      '준수율 {adherence}%를 가정한 계획 {direction} 범위는 주당 {low}~{high}kg입니다. 이는 예상치이며 보장되지 않습니다.',
  'zh-Hans':
      '按 {adherence}% 的执行率估算，计划{direction}范围为每周 {low}–{high} 公斤。这只是估算，并非保证。',
  'zh-Hant':
      '按 {adherence}% 的執行率估算，計畫{direction}範圍為每週 {low}–{high} 公斤。這只是估算，並非保證。',
  'ru':
      'Плановый диапазон «{direction}»: {low}–{high} кг/неделю при соблюдении плана на {adherence}%. Это оценка, а не гарантия.',
  'bn':
      '{adherence}% অনুসরণ ধরে পরিকল্পিত {direction} সীমা প্রতি সপ্তাহে {low}–{high} কেজি। এটি আনুমানিক হিসাব, নিশ্চয়তা নয়।',
  'vi':
      'Phạm vi {direction} dự kiến là {low}–{high} kg/tuần với mức tuân thủ {adherence}%. Đây là ước tính, không phải cam kết.',
  'th':
      'ช่วง{direction}ที่วางแผนไว้คือ {low}–{high} กก./สัปดาห์ โดยสมมติว่าทำตามแผน {adherence}% นี่เป็นเพียงค่าประมาณ ไม่ใช่การรับประกัน',
  'pl':
      'Planowany zakres {direction}: {low}–{high} kg/tydzień przy przestrzeganiu planu w {adherence}%. To szacunek, nie gwarancja.',
  'nl':
      'Gepland bereik voor {direction}: {low}–{high} kg/week bij {adherence}% naleving. Dit is een schatting, geen garantie.',
  'uk':
      'Запланований діапазон «{direction}»: {low}–{high} кг/тиждень за дотримання плану на {adherence}%. Це оцінка, а не гарантія.',
};

const _authored = <String, Map<String, String>>{
  'Dietary system': {
    'fr': 'Système alimentaire',
    'es': 'Sistema alimentario',
    'tr': 'Beslenme sistemi',
  },
  'Eating pattern': {
    'fr': 'Mode alimentaire',
    'es': 'Patrón alimentario',
    'tr': 'Beslenme düzeni',
  },
  'Plan style': {
    'fr': 'Style du plan',
    'es': 'Estilo del plan',
    'tr': 'Plan stili',
  },
  'Eating pattern controls compatible foods. Plan style shapes meal suggestions; neither changes allergy safeguards.': {
    'fr':
        'Le mode alimentaire détermine les aliments compatibles. Le style du plan oriente les suggestions de repas sans modifier les protections liées aux allergies.',
    'es':
        'El patrón alimentario determina los alimentos compatibles. El estilo del plan orienta las sugerencias sin cambiar las protecciones por alergias.',
    'tr':
        'Beslenme düzeni uyumlu yiyecekleri belirler. Plan stili öğün önerilerini şekillendirir; alerji korumalarını değiştirmez.',
  },
  'Omnivore': {'fr': 'Omnivore', 'es': 'Omnívoro', 'tr': 'Hepçil'},
  'Pescatarian': {
    'fr': 'Pescétarien',
    'es': 'Pescetariano',
    'tr': 'Pesketaryen',
  },
  'Vegetarian': {'fr': 'Végétarien', 'es': 'Vegetariano', 'tr': 'Vejetaryen'},
  'Vegan': {'fr': 'Végane', 'es': 'Vegano', 'tr': 'Vegan'},
  'Balanced': {'fr': 'Équilibré', 'es': 'Equilibrado', 'tr': 'Dengeli'},
  'High protein': {
    'fr': 'Riche en protéines',
    'es': 'Alto en proteínas',
    'tr': 'Yüksek protein',
  },
  'Low carb': {
    'fr': 'Faible en glucides',
    'es': 'Bajo en carbohidratos',
    'tr': 'Düşük karbonhidrat',
  },
  'Plant-forward': {
    'fr': 'À dominante végétale',
    'es': 'Centrado en plantas',
    'tr': 'Bitki ağırlıklı',
  },
  'Goal timeline': {
    'fr': 'Calendrier de l’objectif',
    'es': 'Cronograma del objetivo',
    'tr': 'Hedef zaman çizelgesi',
  },
  'Estimated time to goal': {
    'fr': 'Temps estimé pour atteindre l’objectif',
    'es': 'Tiempo estimado para el objetivo',
    'tr': 'Hedefe tahmini süre',
  },
  'Already at goal': {
    'fr': 'Objectif déjà atteint',
    'es': 'Ya estás en el objetivo',
    'tr': 'Hedefe zaten ulaşıldı',
  },
  'Maintenance plan · no countdown': {
    'fr': 'Plan de maintien · aucun compte à rebours',
    'es': 'Plan de mantenimiento · sin cuenta atrás',
    'tr': 'Koruma planı · geri sayım yok',
  },
  'Current weight is within the goal range. This is an estimate, not a guarantee.': {
    'fr':
        'Le poids actuel est dans la plage cible. Il s’agit d’une estimation, sans garantie.',
    'es':
        'El peso actual está dentro del rango objetivo. Es una estimación, no una garantía.',
    'tr': 'Mevcut kilo hedef aralığında. Bu bir tahmindir, garanti değildir.',
  },
  'Maintenance has no completion date. This is an estimate, not a guarantee.': {
    'fr':
        'Le maintien n’a pas de date de fin. Il s’agit d’une estimation, sans garantie.',
    'es':
        'El mantenimiento no tiene fecha de finalización. Es una estimación, no una garantía.',
    'tr':
        'Korumanın tamamlanma tarihi yoktur. Bu bir tahmindir, garanti değildir.',
  },
  'loss': {'fr': 'perte', 'es': 'pérdida', 'tr': 'kayıp'},
  'gain': {'fr': 'prise', 'es': 'aumento', 'tr': 'artış'},
  'Personal details': {
    'fr': 'Informations personnelles',
    'es': 'Datos personales',
    'tr': 'Kişisel bilgiler',
  },
  'Date of birth': {
    'fr': 'Date de naissance',
    'es': 'Fecha de nacimiento',
    'tr': 'Doğum tarihi',
  },
  'Your height': {'fr': 'Votre taille', 'es': 'Tu estatura', 'tr': 'Boyunuz'},
  'Feet/Inches': {'fr': 'Pieds/pouces', 'es': 'Pies/pulgadas', 'tr': 'Fit/inç'},
  'Centimeters': {'fr': 'Centimètres', 'es': 'Centímetros', 'tr': 'Santimetre'},
  'Goals': {'fr': 'Objectifs', 'es': 'Objetivos', 'tr': 'Hedefler'},
  'Update weight, nutrition, and fitness goals': {
    'fr': 'Modifier les objectifs de poids, nutrition et forme',
    'es': 'Actualiza tus objetivos de peso, nutrición y forma física',
    'tr': 'Kilo, beslenme ve fitness hedeflerini güncelle',
  },
  'Linked to today’s measurement and kept on this device.': {
    'fr': 'Liée à la mesure du jour et conservée sur cet appareil.',
    'es': 'Vinculada a la medición de hoy y guardada en este dispositivo.',
    'tr': 'Bugünkü ölçüme bağlıdır ve bu cihazda saklanır.',
  },
  'After waking': {
    'fr': 'Après le réveil',
    'es': 'Al despertar',
    'tr': 'Uyandıktan sonra',
  },
  'After bathroom': {
    'fr': 'Après les toilettes',
    'es': 'Después de ir al baño',
    'tr': 'Tuvaletten sonra',
  },
  'Different time': {
    'fr': 'Heure différente',
    'es': 'Hora diferente',
    'tr': 'Farklı saat',
  },
  'Discard changes?': {
    'fr': 'Ignorer les modifications ?',
    'es': '¿Descartar los cambios?',
    'tr': 'Değişiklikler silinsin mi?',
  },
  'You have unsaved changes.': {
    'fr': 'Vous avez des modifications non enregistrées.',
    'es': 'Tienes cambios sin guardar.',
    'tr': 'Kaydedilmemiş değişiklikleriniz var.',
  },
  'Keep editing': {
    'fr': 'Continuer la modification',
    'es': 'Seguir editando',
    'tr': 'Düzenlemeye devam et',
  },
  'Discard': {'fr': 'Ignorer', 'es': 'Descartar', 'tr': 'Sil'},
  'Your profile and plan were saved.': {
    'fr': 'Votre profil et votre plan ont été enregistrés.',
    'es': 'Se guardaron tu perfil y tu plan.',
    'tr': 'Profiliniz ve planınız kaydedildi.',
  },
  'My profile & plan': {
    'fr': 'Mon profil et mon plan',
    'es': 'Mi perfil y plan',
    'tr': 'Profilim ve planım',
  },
  'Back to settings': {
    'fr': 'Retour aux paramètres',
    'es': 'Volver a ajustes',
    'tr': 'Ayarlara dön',
  },
  'Try again': {'fr': 'Réessayer', 'es': 'Reintentar', 'tr': 'Tekrar dene'},
  'No local profile.': {
    'fr': 'Aucun profil local.',
    'es': 'No hay perfil local.',
    'tr': 'Yerel profil yok.',
  },
  'Display name': {
    'fr': 'Nom affiché',
    'es': 'Nombre visible',
    'tr': 'Görünen ad',
  },
  'Maximum 60 characters': {
    'fr': '60 caractères maximum',
    'es': 'Máximo 60 caracteres',
    'tr': 'En fazla 60 karakter',
  },
  'Your profile photo can be changed from the account icon on Today.': {
    'fr':
        'Vous pouvez modifier votre photo depuis l’icône du compte sur Aujourd’hui.',
    'es': 'Puedes cambiar tu foto desde el icono de cuenta en Hoy.',
    'tr':
        'Profil fotoğrafınızı Bugün ekranındaki hesap simgesinden değiştirebilirsiniz.',
  },
  'Body profile': {
    'fr': 'Profil corporel',
    'es': 'Perfil corporal',
    'tr': 'Vücut profili',
  },
  'Sex': {'fr': 'Sexe', 'es': 'Sexo', 'tr': 'Cinsiyet'},
  'Male': {'fr': 'Homme', 'es': 'Hombre', 'tr': 'Erkek'},
  'Female': {'fr': 'Femme', 'es': 'Mujer', 'tr': 'Kadın'},
  'Age': {'fr': 'Âge', 'es': 'Edad', 'tr': 'Yaş'},
  'Height (cm)': {'fr': 'Taille (cm)', 'es': 'Altura (cm)', 'tr': 'Boy (cm)'},
  'Current weight (kg)': {
    'fr': 'Poids actuel (kg)',
    'es': 'Peso actual (kg)',
    'tr': 'Mevcut kilo (kg)',
  },
  'Goal & activity': {
    'fr': 'Objectif et activité',
    'es': 'Objetivo y actividad',
    'tr': 'Hedef ve aktivite',
  },
  'Target weight (kg)': {
    'fr': 'Poids cible (kg)',
    'es': 'Peso objetivo (kg)',
    'tr': 'Hedef kilo (kg)',
  },
  'Activity level': {
    'fr': 'Niveau d’activité',
    'es': 'Nivel de actividad',
    'tr': 'Aktivite düzeyi',
  },
  'Low movement': {
    'fr': 'Peu de mouvement',
    'es': 'Poco movimiento',
    'tr': 'Az hareket',
  },
  'Light activity': {
    'fr': 'Activité légère',
    'es': 'Actividad ligera',
    'tr': 'Hafif aktivite',
  },
  'Balanced activity': {
    'fr': 'Activité modérée',
    'es': 'Actividad moderada',
    'tr': 'Dengeli aktivite',
  },
  'High activity': {
    'fr': 'Activité élevée',
    'es': 'Actividad alta',
    'tr': 'Yüksek aktivite',
  },
  'Intense activity': {
    'fr': 'Activité intense',
    'es': 'Actividad intensa',
    'tr': 'Yoğun aktivite',
  },
  'I exercise': {
    'fr': 'Je fais de l’exercice',
    'es': 'Hago ejercicio',
    'tr': 'Egzersiz yapıyorum',
  },
  'Frequency and type improve context without claiming exact calorie burn.': {
    'fr':
        'La fréquence et le type enrichissent le contexte sans prétendre calculer exactement les calories brûlées.',
    'es':
        'La frecuencia y el tipo mejoran el contexto sin afirmar un gasto calórico exacto.',
    'tr':
        'Sıklık ve tür, kesin kalori yakımı iddiası olmadan bağlamı iyileştirir.',
  },
  'Exercise sessions per week': {
    'fr': 'Séances d’exercice par semaine',
    'es': 'Sesiones de ejercicio por semana',
    'tr': 'Haftalık egzersiz seansı',
  },
  'Primary exercise type': {
    'fr': 'Type d’exercice principal',
    'es': 'Tipo de ejercicio principal',
    'tr': 'Ana egzersiz türü',
  },
  'Walking': {'fr': 'Marche', 'es': 'Caminar', 'tr': 'Yürüyüş'},
  'Strength & gym': {
    'fr': 'Musculation et salle',
    'es': 'Fuerza y gimnasio',
    'tr': 'Kuvvet ve spor salonu',
  },
  'Cardio': {'fr': 'Cardio', 'es': 'Cardio', 'tr': 'Kardiyo'},
  'Swimming': {'fr': 'Natation', 'es': 'Natación', 'tr': 'Yüzme'},
  'Cycling': {'fr': 'Cyclisme', 'es': 'Ciclismo', 'tr': 'Bisiklet'},
  'Mixed training': {
    'fr': 'Entraînement mixte',
    'es': 'Entrenamiento mixto',
    'tr': 'Karma antrenman',
  },
  'Nutrition approach': {
    'fr': 'Approche nutritionnelle',
    'es': 'Enfoque nutricional',
    'tr': 'Beslenme yaklaşımı',
  },
  'My plan style': {
    'fr': 'Style de mon plan',
    'es': 'Estilo de mi plan',
    'tr': 'Plan tarzım',
  },
  'This guides presentation and preferences, not core scientific facts.': {
    'fr':
        'Cela guide la présentation et les préférences, sans modifier les principes scientifiques.',
    'es':
        'Esto orienta la presentación y las preferencias, no los principios científicos.',
    'tr':
        'Bu, temel bilimsel gerçekleri değil sunumu ve tercihleri yönlendirir.',
  },
  'Smart Balance': {
    'fr': 'Équilibre intelligent',
    'es': 'Equilibrio inteligente',
    'tr': 'Akıllı Denge',
  },
  'Protein Forward': {
    'fr': 'Priorité aux protéines',
    'es': 'Prioridad proteica',
    'tr': 'Protein Ağırlıklı',
  },
  'Lower Carb': {
    'fr': 'Moins de glucides',
    'es': 'Menos carbohidratos',
    'tr': 'Düşük Karbonhidrat',
  },
  'Keto': {'fr': 'Kéto', 'es': 'Keto', 'tr': 'Keto'},
  'Mediterranean': {
    'fr': 'Méditerranéen',
    'es': 'Mediterránea',
    'tr': 'Akdeniz',
  },
  'Plant Forward': {
    'fr': 'À dominante végétale',
    'es': 'Enfoque vegetal',
    'tr': 'Bitki Ağırlıklı',
  },
  'Save and return to settings': {
    'fr': 'Enregistrer et revenir aux paramètres',
    'es': 'Guardar y volver a ajustes',
    'tr': 'Kaydet ve ayarlara dön',
  },
  'Profile': {'fr': 'Profil', 'es': 'Perfil', 'tr': 'Profil'},
  'Choose an image smaller than 5 MB.': {
    'fr': 'Choisissez une image de moins de 5 Mo.',
    'es': 'Elige una imagen de menos de 5 MB.',
    'tr': '5 MB’den küçük bir görsel seçin.',
  },
  'Complete your profile first.': {
    'fr': 'Complétez d’abord votre profil.',
    'es': 'Completa primero tu perfil.',
    'tr': 'Önce profilinizi tamamlayın.',
  },
  'Personal identity': {
    'fr': 'Identité personnelle',
    'es': 'Identidad personal',
    'tr': 'Kişisel kimlik',
  },
  'Profile photo': {
    'fr': 'Photo de profil',
    'es': 'Foto de perfil',
    'tr': 'Profil fotoğrafı',
  },
  'Change photo': {
    'fr': 'Modifier la photo',
    'es': 'Cambiar foto',
    'tr': 'Fotoğrafı değiştir',
  },
  'Email address': {
    'fr': 'Adresse e-mail',
    'es': 'Correo electrónico',
    'tr': 'E-posta adresi',
  },
  'Not added': {'fr': 'Non ajouté', 'es': 'No añadido', 'tr': 'Eklenmedi'},
  'Body details': {
    'fr': 'Données corporelles',
    'es': 'Datos corporales',
    'tr': 'Vücut bilgileri',
  },
  'Height': {'fr': 'Taille', 'es': 'Altura', 'tr': 'Boy'},
  'Height in cm': {
    'fr': 'Taille en cm',
    'es': 'Altura en cm',
    'tr': 'Santimetre cinsinden boy',
  },
  'years': {'fr': 'ans', 'es': 'años', 'tr': 'yaş'},
  'Location & preferences': {
    'fr': 'Lieu et préférences',
    'es': 'Ubicación y preferencias',
    'tr': 'Konum ve tercihler',
  },
  'Location': {'fr': 'Lieu', 'es': 'Ubicación', 'tr': 'Konum'},
  'Country or city': {
    'fr': 'Pays ou ville',
    'es': 'País o ciudad',
    'tr': 'Ülke veya şehir',
  },
  'Postal code': {
    'fr': 'Code postal',
    'es': 'Código postal',
    'tr': 'Posta kodu',
  },
  'Time zone': {
    'fr': 'Fuseau horaire',
    'es': 'Zona horaria',
    'tr': 'Saat dilimi',
  },
  'Units': {'fr': 'Unités', 'es': 'Unidades', 'tr': 'Birimler'},
  'Unit system': {
    'fr': 'Système d’unités',
    'es': 'Sistema de unidades',
    'tr': 'Birim sistemi',
  },
  'Metric · kg, cm, ml': {
    'fr': 'Métrique · kg, cm, ml',
    'es': 'Métrico · kg, cm, ml',
    'tr': 'Metrik · kg, cm, ml',
  },
  'Imperial · lb, ft': {
    'fr': 'Impérial · lb, ft',
    'es': 'Imperial · lb, ft',
    'tr': 'İngiliz · lb, ft',
  },
  'Health goals': {
    'fr': 'Objectifs de santé',
    'es': 'Objetivos de salud',
    'tr': 'Sağlık hedefleri',
  },
  'Current weight': {
    'fr': 'Poids actuel',
    'es': 'Peso actual',
    'tr': 'Mevcut kilo',
  },
  'Goal weight': {
    'fr': 'Poids cible',
    'es': 'Peso objetivo',
    'tr': 'Hedef kilo',
  },
  'Sedentary': {'fr': 'Sédentaire', 'es': 'Sedentario', 'tr': 'Hareketsiz'},
  'Lightly active': {
    'fr': 'Légèrement actif',
    'es': 'Actividad ligera',
    'tr': 'Hafif aktif',
  },
  'Moderately active': {
    'fr': 'Modérément actif',
    'es': 'Actividad moderada',
    'tr': 'Orta aktif',
  },
  'Active': {'fr': 'Actif', 'es': 'Activo', 'tr': 'Aktif'},
  'Very active': {'fr': 'Très actif', 'es': 'Muy activo', 'tr': 'Çok aktif'},
  'Calories & macro plan': {
    'fr': 'Plan calories et macros',
    'es': 'Plan de calorías y macros',
    'tr': 'Kalori ve makro planı',
  },
  'Plan details & recommendations': {
    'fr': 'Détails et recommandations du plan',
    'es': 'Detalles y recomendaciones del plan',
    'tr': 'Plan ayrıntıları ve öneriler',
  },
  'Advanced body measurements': {
    'fr': 'Mesures corporelles avancées',
    'es': 'Medidas corporales avanzadas',
    'tr': 'Gelişmiş vücut ölçümleri',
  },
  'Save health profile': {
    'fr': 'Enregistrer le profil santé',
    'es': 'Guardar perfil de salud',
    'tr': 'Sağlık profilini kaydet',
  },
  'Not set': {'fr': 'Non défini', 'es': 'Sin definir', 'tr': 'Ayarlanmadı'},
  'Edit profile and photo': {
    'fr': 'Modifier le profil et la photo',
    'es': 'Editar perfil y foto',
    'tr': 'Profil ve fotoğrafı düzenle',
  },
  'Your health profile is updated.': {
    'fr': 'Votre profil santé est à jour.',
    'es': 'Tu perfil de salud está actualizado.',
    'tr': 'Sağlık profiliniz güncellendi.',
  },
  'Daily check-in': {
    'fr': 'Bilan quotidien',
    'es': 'Registro diario',
    'tr': 'Günlük kontrol',
  },
  'Cancel': {'fr': 'Annuler', 'es': 'Cancelar', 'tr': 'İptal'},
  'Not now': {'fr': 'Pas maintenant', 'es': 'Ahora no', 'tr': 'Şimdi değil'},
  'Enter a valid weight.': {
    'fr': 'Saisissez un poids valide.',
    'es': 'Introduce un peso válido.',
    'tr': 'Geçerli bir kilo girin.',
  },
  'Use the value shown on your scale.': {
    'fr': 'Utilisez la valeur affichée sur votre balance.',
    'es': 'Usa el valor que muestra tu báscula.',
    'tr': 'Tartınızda görünen değeri kullanın.',
  },
  'Camera is unavailable here. Choose a photo from the device.': {
    'fr':
        'La caméra n’est pas disponible ici. Choisissez une photo sur l’appareil.',
    'es': 'La cámara no está disponible aquí. Elige una foto del dispositivo.',
    'tr': 'Kamera burada kullanılamıyor. Cihazdan bir fotoğraf seçin.',
  },
  'Check-in saved. Consistent conditions make your trend clearer.': {
    'fr':
        'Bilan enregistré. Des conditions constantes rendent votre tendance plus claire.',
    'es':
        'Registro guardado. Mantener condiciones constantes aclara tu tendencia.',
    'tr': 'Kontrol kaydedildi. Tutarlı koşullar eğiliminizi netleştirir.',
  },
  "Delete today's weight?": {
    'fr': 'Supprimer le poids du jour ?',
    'es': '¿Eliminar el peso de hoy?',
    'tr': 'Bugünkü kilo silinsin mi?',
  },
  'This removes today’s check-in from trend calculations.': {
    'fr': 'Cela retire le bilan du jour des calculs de tendance.',
    'es': 'Esto elimina el registro de hoy de los cálculos de tendencia.',
    'tr': 'Bu işlem bugünkü kontrolü eğilim hesaplarından çıkarır.',
  },
  'The check-in could not be changed on this device. Try again.': {
    'fr': 'Le bilan n’a pas pu être modifié sur cet appareil. Réessayez.',
    'es':
        'No se pudo cambiar el registro en este dispositivo. Inténtalo de nuevo.',
    'tr': 'Kontrol bu cihazda değiştirilemedi. Tekrar deneyin.',
  },
  'A quick check-in for a clearer trend.': {
    'fr': 'Un bilan rapide pour une tendance plus claire.',
    'es': 'Un registro rápido para una tendencia más clara.',
    'tr': 'Daha net bir eğilim için hızlı kontrol.',
  },
  'Last measurement': {
    'fr': 'Dernière mesure',
    'es': 'Última medición',
    'tr': 'Son ölçüm',
  },
  'tap to enter': {
    'fr': 'toucher pour saisir',
    'es': 'toca para introducir',
    'tr': 'girmek için dokun',
  },
  'Record': {'fr': 'Enregistrer', 'es': 'Registrar', 'tr': 'Kaydet'},
  "Update today's weight": {
    'fr': 'Mettre à jour le poids du jour',
    'es': 'Actualizar el peso de hoy',
    'tr': 'Bugünkü kiloyu güncelle',
  },
  "Delete today's weight": {
    'fr': 'Supprimer le poids du jour',
    'es': 'Eliminar el peso de hoy',
    'tr': 'Bugünkü kiloyu sil',
  },
  'Progress photo': {
    'fr': 'Photo de progression',
    'es': 'Foto de progreso',
    'tr': 'İlerleme fotoğrafı',
  },
  'Take a private photo': {
    'fr': 'Prendre une photo privée',
    'es': 'Tomar una foto privada',
    'tr': 'Özel fotoğraf çek',
  },
  'Choose from device': {
    'fr': 'Choisir sur l’appareil',
    'es': 'Elegir del dispositivo',
    'tr': 'Cihazdan seç',
  },
  'Enter weight': {
    'fr': 'Saisir le poids',
    'es': 'Introducir peso',
    'tr': 'Kilo gir',
  },
  'Apply': {'fr': 'Appliquer', 'es': 'Aplicar', 'tr': 'Uygula'},
  'Delete': {'fr': 'Supprimer', 'es': 'Eliminar', 'tr': 'Sil'},
  'Later': {'fr': 'Plus tard', 'es': 'Más tarde', 'tr': 'Daha sonra'},
  'Good morning': {'fr': 'Bonjour', 'es': 'Buenos días', 'tr': 'Günaydın'},
  'Shall we log your weight?': {
    'fr': 'Enregistrons-nous votre poids ?',
    'es': '¿Registramos tu peso?',
    'tr': 'Kilonuzu kaydedelim mi?',
  },
  'Private progress photo': {
    'fr': 'Photo de progression privée',
    'es': 'Foto de progreso privada',
    'tr': 'Özel ilerleme fotoğrafı',
  },
  'Change': {'fr': 'Modifier', 'es': 'Cambiar', 'tr': 'Değiştir'},
  'Add photo': {
    'fr': 'Ajouter une photo',
    'es': 'Añadir foto',
    'tr': 'Fotoğraf ekle',
  },
  'Remove photo': {
    'fr': 'Supprimer la photo',
    'es': 'Eliminar foto',
    'tr': 'Fotoğrafı kaldır',
  },
  'Activity factor': {
    'fr': 'Facteur d’activité',
    'es': 'Factor de actividad',
    'tr': 'Aktivite katsayısı',
  },
  'Goal direction': {
    'fr': 'Orientation de l’objectif',
    'es': 'Dirección del objetivo',
    'tr': 'Hedef yönü',
  },
  'Mifflin–St Jeor BMR using the saved age, sex, height, and current weight': {
    'fr':
        'Métabolisme basal de Mifflin–St Jeor calculé avec l’âge, le sexe, la taille et le poids actuel enregistrés',
    'es':
        'TMB de Mifflin–St Jeor usando la edad, el sexo, la altura y el peso actual guardados',
    'tr':
        'Kaydedilen yaş, cinsiyet, boy ve mevcut kilo kullanılarak Mifflin–St Jeor BMH hesabı',
  },
  'Logged scale weight cannot distinguish fat from muscle': {
    'fr':
        'Le poids enregistré par la balance ne distingue pas la graisse du muscle',
    'es': 'El peso registrado por la báscula no distingue grasa de músculo',
    'tr': 'Kaydedilen tartı kilosu yağ ile kası ayırt edemez',
  },
  'Review draft only. Clinician review is required before activation.': {
    'fr':
        'Brouillon à examiner uniquement. L’avis d’un professionnel est requis avant activation.',
    'es':
        'Borrador solo para revisión. Se requiere revisión clínica antes de activarlo.',
    'tr':
        'Yalnızca inceleme taslağıdır. Etkinleştirmeden önce klinisyen incelemesi gerekir.',
  },
  'Selecting a pathway does not change your targets. No values apply until you save the plan.': {
    'fr':
        'Choisir un parcours ne modifie pas vos objectifs. Aucune valeur ne s’applique avant l’enregistrement du plan.',
    'es':
        'Seleccionar una ruta no cambia tus objetivos. Ningún valor se aplica hasta guardar el plan.',
    'tr':
        'Bir yol seçmek hedeflerinizi değiştirmez. Planı kaydedene kadar hiçbir değer uygulanmaz.',
  },
  'Body measurements': {
    'fr': 'Mensurations',
    'es': 'Medidas corporales',
    'tr': 'Vücut ölçümleri',
  },
  'Optional. Saving creates or updates today’s private measurement record.': {
    'fr':
        'Facultatif. L’enregistrement crée ou actualise les mensurations privées du jour.',
    'es':
        'Opcional. Al guardar se crea o actualiza el registro privado de hoy.',
    'tr':
        'İsteğe bağlıdır. Kaydetmek bugünün özel ölçüm kaydını oluşturur veya günceller.',
  },
  'Neck': {'fr': 'Cou', 'es': 'Cuello', 'tr': 'Boyun'},
  'Waist': {'fr': 'Tour de taille', 'es': 'Cintura', 'tr': 'Bel'},
  'Hips': {'fr': 'Hanches', 'es': 'Caderas', 'tr': 'Kalça'},
  'Chest': {'fr': 'Poitrine', 'es': 'Pecho', 'tr': 'Göğüs'},
  'Arm': {'fr': 'Bras', 'es': 'Brazo', 'tr': 'Kol'},
  'Thigh': {'fr': 'Cuisse', 'es': 'Muslo', 'tr': 'Uyluk'},
};
