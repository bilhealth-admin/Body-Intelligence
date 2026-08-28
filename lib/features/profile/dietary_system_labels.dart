import 'package:flutter/widgets.dart';

import '../nutrition/domain/dietary_preferences.dart';
import 'profile_locale_copy.dart';

String dietaryPatternLabel(BuildContext context, DietaryPattern value) =>
    switch (value) {
      DietaryPattern.omnivore => profileLocaleText(
        context,
        'Omnivore',
        'نظام متنوع',
      ),
      DietaryPattern.pescatarian => profileLocaleText(
        context,
        'Pescatarian',
        'نباتي مع الأسماك',
      ),
      DietaryPattern.vegetarian => profileLocaleText(
        context,
        'Vegetarian',
        'نباتي',
      ),
      DietaryPattern.vegan => profileLocaleText(context, 'Vegan', 'نباتي صرف'),
    };

String dietaryApproachLabel(
  BuildContext context,
  String value,
) => switch (value) {
  'high_protein' => profileLocaleText(context, 'High protein', 'عالي البروتين'),
  'low_carb' => profileLocaleText(context, 'Low carb', 'منخفض الكربوهيدرات'),
  'keto' => profileLocaleText(context, 'Keto', 'كيتو'),
  'mediterranean' => profileLocaleText(context, 'Mediterranean', 'متوسطي'),
  'plant_forward' => profileLocaleText(
    context,
    'Plant-forward',
    'يركز على النباتات',
  ),
  _ => profileLocaleText(context, 'Balanced', 'متوازن'),
};

String dietarySystemSummary(
  BuildContext context,
  DietaryPreferences preferences,
) =>
    '${dietaryPatternLabel(context, preferences.pattern)} · '
    '${dietaryApproachLabel(context, preferences.approach)}';
