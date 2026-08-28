import '../diet_macro_plan.dart';
import '../nutrition_pathway.dart';

const plantForwardPathway = NutritionPathway(
  id: 'plant-forward',
  arTitle: 'نباتي مرن',
  enTitle: 'Plant forward',
  arSubtitle: 'نباتات أكثر مع بروتين وعناصر دقيقة مخططة',
  enSubtitle: 'More plants with planned protein and micronutrients',
  asset: 'assets/images/nutrition_plans/plant_forward_lifestyle_v1.webp',
  arTags: ['نباتي مرن', 'ألياف', 'تنوع'],
  enTags: ['Plant forward', 'Fibre', 'Variety'],
  arApproach: [
    'زد النباتات تدريجيًا',
    'خطط للبروتين بدل افتراضه',
    'راجع العناصر الدقيقة عند التقييد',
  ],
  enApproach: [
    'Increase plants gradually',
    'Plan protein rather than assuming it',
    'Review micronutrients when restrictive',
  ],
  arTracking: ['تنوع النباتات', 'البروتين', 'العناصر الدقيقة'],
  enTracking: ['Plant variety', 'Protein', 'Micronutrients'],
);

final plantForwardPreset = DietPreset(
  pathwayId: 'plant-forward',
  calories: 2000,
  fatLevel: DietFatLevel.lighter,
  carbsByWeekday: uniformWeeklyCarbs(250),
);
