import 'package:flutter/widgets.dart';

import '../repositories/recipe_release_repository.dart';
import 'wellness_copy.dart';

const recipeCuisineOrder = <String>[
  'global',
  'egypt',
  'levant',
  'palestine',
  'gulf',
  'iraq',
  'maghreb',
  'algeria',
  'morocco',
  'tunisia',
  'turkey',
  'spain',
  'mexico',
  'central-america',
  'costa-rica',
  'honduras',
  'south-america',
  'caribbean',
  'united-states',
  'canada',
  'united-kingdom',
  'ireland',
  'australia',
  'new-zealand',
  'france',
  'quebec',
  'west-africa',
];

String recipeCuisineKey(RecipeCatalogSummary recipe) {
  // The Turkish catalog uses verified regional tags (Aegean, Black Sea,
  // Anatolia, Marmara). They all belong under one country-level cuisine page.
  if (recipe.cuisine != null) return recipe.cuisine!;
  if (recipe.primaryLocale == 'tr' && recipe.region != 'global') {
    return 'turkey';
  }
  return recipe.region;
}

String recipeCuisineLabel(BuildContext context, String key) {
  final value = _labels[key] ?? _labels['global']!;
  return wellnessCopy(context, value.$1, value.$2);
}

const _labels = <String, (String, String)>{
  'all': ('All cuisines', 'جميع المطابخ'),
  'global': ('Global recipes', 'وصفات عالمية'),
  'egypt': ('Egyptian cuisine', 'المطبخ المصري'),
  'levant': ('Levantine cuisine', 'المطبخ الشامي'),
  'palestine': ('Palestinian cuisine', 'المطبخ الفلسطيني'),
  'gulf': ('Gulf cuisine', 'المطبخ الخليجي'),
  'iraq': ('Iraqi cuisine', 'المطبخ العراقي'),
  'maghreb': ('Maghrebi cuisine', 'المطبخ المغاربي'),
  'algeria': ('Algerian cuisine', 'المطبخ الجزائري'),
  'morocco': ('Moroccan cuisine', 'المطبخ المغربي'),
  'tunisia': ('Tunisian cuisine', 'المطبخ التونسي'),
  'turkey': ('Turkish cuisine', 'المطبخ التركي'),
  'spain': ('Spanish cuisine', 'المطبخ الإسباني'),
  'mexico': ('Mexican cuisine', 'المطبخ المكسيكي'),
  'central-america': ('Central American cuisine', 'مطبخ أمريكا الوسطى'),
  'costa-rica': ('Costa Rican cuisine', 'المطبخ الكوستاريكي'),
  'honduras': ('Honduran cuisine', 'المطبخ الهندوراسي'),
  'south-america': ('South American cuisine', 'مطبخ أمريكا الجنوبية'),
  'caribbean': ('Caribbean cuisine', 'المطبخ الكاريبي'),
  'united-states': ('American cuisine', 'المطبخ الأمريكي'),
  'canada': ('Canadian cuisine', 'المطبخ الكندي'),
  'united-kingdom': ('British cuisine', 'المطبخ البريطاني'),
  'ireland': ('Irish cuisine', 'المطبخ الأيرلندي'),
  'australia': ('Australian cuisine', 'المطبخ الأسترالي'),
  'new-zealand': ('New Zealand cuisine', 'مطبخ نيوزيلندا'),
  'france': ('French cuisine', 'المطبخ الفرنسي'),
  'quebec': ('Québécois cuisine', 'مطبخ كيبيك'),
  'west-africa': ('West African cuisine', 'مطبخ غرب أفريقيا'),
};
