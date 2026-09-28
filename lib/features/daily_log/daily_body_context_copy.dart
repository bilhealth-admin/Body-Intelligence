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
  final english = dailyBodyContextEnglishCopy[key] ?? key;
  return RuntimeCopy.resolve(
        english,
        BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      ) ??
      context.strings.text(english);
}
