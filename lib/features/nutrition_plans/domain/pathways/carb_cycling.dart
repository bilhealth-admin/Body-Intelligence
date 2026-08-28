import '../diet_macro_plan.dart';
import '../nutrition_pathway.dart';

const carbCyclingPathway = NutritionPathway(
  id: 'carb-cycling',
  access: NutritionPathwayAccess.free,
  arTitle: 'تدوير الكربوهيدرات',
  enTitle: 'Carb cycling',
  arSubtitle:
      'كربوهيدرات مختلفة لكل يوم مع سعرات ثابتة وتوزيع حي للبروتين والدهون',
  enSubtitle:
      'Different carbs each day with fixed calories and live protein-fat balancing',
  asset: 'assets/images/nutrition_plans/carb_cycling_lifestyle_v1.webp',
  arTags: ['جدول أسبوعي', 'سعرات ثابتة', 'قابل للتعديل'],
  enTags: ['Weekly cycle', 'Fixed calories', 'Editable'],
  arApproach: [
    'اربط الأيام الأعلى بالتدريب الأعلى عند الحاجة',
    'عدّل كل يوم من الاثنين إلى الأحد',
    'ثبّت السعرات ودع BIL يعيد توزيع البروتين والدهون',
  ],
  enApproach: [
    'Match higher-carb days to harder training when useful',
    'Edit every day from Monday through Sunday',
    'Keep calories fixed while BIL rebalances protein and fat',
  ],
  arTracking: ['كربوهيدرات اليوم', 'الأداء والتعافي', 'الالتزام الأسبوعي'],
  enTracking: [
    'Daily carbohydrate',
    'Performance and recovery',
    'Weekly adherence',
  ],
);

const carbCyclingPreset = DietPreset(
  pathwayId: 'carb-cycling',
  calories: 2000,
  fatLevel: DietFatLevel.medium,
  carbsByWeekday: {1: 20, 2: 50, 3: 200, 4: 20, 5: 50, 6: 100, 7: 200},
);
