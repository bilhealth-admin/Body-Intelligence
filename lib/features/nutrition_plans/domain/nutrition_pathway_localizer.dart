import '../../../app/localization/runtime_copy.dart';
import 'nutrition_pathway.dart';
import 'nutrition_pathway_translations.dart';

String nutritionPathwayTitle(NutritionPathway plan, String localeTag) =>
    _localized(
      plan,
      localeTag,
      (value) => value.title,
      plan.enTitle,
      plan.arTitle,
    );

String nutritionPathwaySubtitle(NutritionPathway plan, String localeTag) =>
    _localized(
      plan,
      localeTag,
      (value) => value.subtitle,
      plan.enSubtitle,
      plan.arSubtitle,
    );

List<String> nutritionPathwayTags(NutritionPathway plan, String localeTag) =>
    _localizedList(
      plan,
      localeTag,
      (value) => value.tags,
      plan.enTags,
      plan.arTags,
    );

List<String> nutritionPathwayApproach(
  NutritionPathway plan,
  String localeTag,
) => _localizedList(
  plan,
  localeTag,
  (value) => value.approach,
  plan.enApproach,
  plan.arApproach,
);

List<String> nutritionPathwayTracking(
  NutritionPathway plan,
  String localeTag,
) => _localizedList(
  plan,
  localeTag,
  (value) => value.tracking,
  plan.enTracking,
  plan.arTracking,
);

String _localized(
  NutritionPathway plan,
  String localeTag,
  String Function(NutritionPathwayTranslation) pick,
  String english,
  String arabic,
) {
  final normalized = localeTag.replaceAll('_', '-');
  final language = normalized.toLowerCase().split('-').first;
  if (language == 'ar') return arabic;
  if (language == 'en') return english;
  final direct = nutritionPathwayTranslations[language]?[plan.id];
  return direct == null
      ? RuntimeCopy.resolve(english, normalized) ?? english
      : pick(direct);
}

List<String> _localizedList(
  NutritionPathway plan,
  String localeTag,
  List<String> Function(NutritionPathwayTranslation) pick,
  List<String> english,
  List<String> arabic,
) {
  final normalized = localeTag.replaceAll('_', '-');
  final language = normalized.toLowerCase().split('-').first;
  if (language == 'ar') return arabic;
  if (language == 'en') return english;
  final direct = nutritionPathwayTranslations[language]?[plan.id];
  if (direct != null) return pick(direct);
  return english
      .map((value) => RuntimeCopy.resolve(value, normalized) ?? value)
      .toList(growable: false);
}
