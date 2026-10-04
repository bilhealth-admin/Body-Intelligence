import 'package:flutter/widgets.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';

const dailyBodyContextEnglishCopy = <String, String>{
  'title': 'Body context',
  'poorSleep': 'Less sleep than usual',
  'greatSleep': 'Excellent sleep',
  'travel': 'Travel',
  'fasting': 'Fasting',
  'highSodiumMeal': 'High-sodium meal',
  'hardWorkout': 'Hard workout',
  'psychologicalStress': 'Psychological stress',
  'illnessSymptoms': 'Illness or symptoms',
  'medication': 'Medication',
  'lessWater': 'Less water than usual',
  'moreWater': 'More water than usual',
  'constipation': 'Constipation',
  'nothingNotable': 'Nothing notable',
  'other': 'Other',
};

String dailyBodyContextCopy(BuildContext context, String key) {
  // Today and the focused editor must share the same reviewed authored copy.
  final authored =
      _bodyContextCopy[Localizations.localeOf(context).languageCode]?[key];
  if (authored != null) {
    return authored;
  }
  final english = dailyBodyContextEnglishCopy[key] ?? key;
  return RuntimeCopy.resolve(
        english,
        BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      ) ??
      context.strings.text(english);
}

const _bodyContextCopy = <String, Map<String, String>>{
  'ar': {
    'title': 'سياق الجسم',
    'poorSleep': 'نوم أقل من المعتاد',
    'greatSleep': 'نوم ممتاز',
    'travel': 'سفر',
    'fasting': 'صيام',
    'highSodiumMeal': 'وجبة عالية الصوديوم',
    'hardWorkout': 'تمرين قوي',
    'psychologicalStress': 'إجهاد نفسي',
    'illnessSymptoms': 'مرض أو أعراض',
    'medication': 'تناول دواء',
    'lessWater': 'شرب ماء أقل من المعتاد',
    'moreWater': 'شرب ماء أكثر من المعتاد',
    'constipation': 'إمساك',
    'nothingNotable': 'لا يوجد شيء مميز',
    'other': 'أخرى',
  },
  'fr': {
    'title': 'Contexte corporel',
    'poorSleep': 'Moins dormi que d’habitude',
    'greatSleep': 'Excellent sommeil',
    'travel': 'Voyage',
    'fasting': 'Jeûne',
    'highSodiumMeal': 'Repas riche en sodium',
    'hardWorkout': 'Entraînement intense',
    'psychologicalStress': 'Stress psychologique',
    'illnessSymptoms': 'Maladie ou symptômes',
    'medication': 'Prise de médicament',
    'lessWater': 'Moins d’eau que d’habitude',
    'moreWater': 'Plus d’eau que d’habitude',
    'constipation': 'Constipation',
    'nothingNotable': 'Rien à signaler',
    'other': 'Autre',
  },
  'es': {
    'title': 'Contexto corporal',
    'poorSleep': 'Menos sueño de lo habitual',
    'greatSleep': 'Sueño excelente',
    'travel': 'Viaje',
    'fasting': 'Ayuno',
    'highSodiumMeal': 'Comida alta en sodio',
    'hardWorkout': 'Entrenamiento intenso',
    'psychologicalStress': 'Estrés psicológico',
    'illnessSymptoms': 'Enfermedad o síntomas',
    'medication': 'Medicación',
    'lessWater': 'Menos agua de lo habitual',
    'moreWater': 'Más agua de lo habitual',
    'constipation': 'Estreñimiento',
    'nothingNotable': 'Nada destacable',
    'other': 'Otro',
  },
  'tr': {
    'title': 'Vücut bağlamı',
    'poorSleep': 'Her zamankinden az uyku',
    'greatSleep': 'Mükemmel uyku',
    'travel': 'Seyahat',
    'fasting': 'Oruç',
    'highSodiumMeal': 'Yüksek sodyumlu öğün',
    'hardWorkout': 'Yoğun egzersiz',
    'psychologicalStress': 'Psikolojik stres',
    'illnessSymptoms': 'Hastalık veya belirtiler',
    'medication': 'İlaç kullanımı',
    'lessWater': 'Her zamankinden az su',
    'moreWater': 'Her zamankinden fazla su',
    'constipation': 'Kabızlık',
    'nothingNotable': 'Dikkate değer bir şey yok',
    'other': 'Diğer',
  },
};
