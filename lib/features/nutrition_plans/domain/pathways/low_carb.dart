import '../diet_macro_plan.dart';
import '../nutrition_pathway.dart';

const lowCarbPathway = NutritionPathway(
  id: 'low-carb',
  arTitle: 'لو كارب متوسطي',
  enTitle: 'Mediterranean low carb',
  arSubtitle: 'كربوهيدرات أقل مع ألياف ودهون غير مشبعة',
  enSubtitle: 'Lower carbohydrate with fibre and unsaturated fats',
  asset: 'assets/images/nutrition_plans/low_carb_outdoor_lifestyle_v1.webp',
  arTags: ['متوسطي', 'مرن', 'ألياف'],
  enTags: ['Mediterranean', 'Flexible', 'Fibre'],
  arApproach: [
    'خفّض الكربوهيدرات دون إلغاء الألياف',
    'اختر مصادر قليلة التصنيع',
    'عدّل المستوى وفق الاستجابة',
  ],
  enApproach: [
    'Lower carbohydrate without removing fibre',
    'Choose minimally processed sources',
    'Adjust to response and adherence',
  ],
  arTracking: ['الألياف', 'الطاقة والجوع', 'اتجاه الوزن'],
  enTracking: ['Fibre', 'Energy and hunger', 'Weight trend'],
);

final lowCarbPreset = DietPreset(
  pathwayId: 'low-carb',
  calories: 2000,
  fatLevel: DietFatLevel.richer,
  carbsByWeekday: uniformWeeklyCarbs(100),
);
