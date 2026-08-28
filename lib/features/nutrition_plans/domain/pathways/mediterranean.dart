import '../diet_macro_plan.dart';
import '../nutrition_pathway.dart';

const mediterraneanPathway = NutritionPathway(
  id: 'mediterranean',
  arTitle: 'النمط المتوسطي',
  enTitle: 'Mediterranean',
  arSubtitle: 'نمط مرن غني بالخضار والبقول والدهون غير المشبعة',
  enSubtitle:
      'Flexible whole foods with vegetables, legumes and unsaturated fats',
  asset: 'assets/images/nutrition_plans/mediterranean_coast_lifestyle_v1.webp',
  arTags: ['صحة القلب', 'مرن', 'ألياف'],
  enTags: ['Heart health', 'Flexible', 'Fibre'],
  arApproach: [
    'اجعل النباتات والبقول أساسًا',
    'فضّل الدهون غير المشبعة',
    'حافظ على مرونة اجتماعية واقعية',
  ],
  enApproach: [
    'Build around plants and legumes',
    'Prefer unsaturated fats',
    'Keep the pattern socially flexible',
  ],
  arTracking: ['الألياف', 'تنوع الغذاء', 'الاتساق الأسبوعي'],
  enTracking: ['Fibre', 'Food variety', 'Weekly consistency'],
);

final mediterraneanPreset = DietPreset(
  pathwayId: 'mediterranean',
  calories: 2000,
  fatLevel: DietFatLevel.medium,
  carbsByWeekday: uniformWeeklyCarbs(250),
);
