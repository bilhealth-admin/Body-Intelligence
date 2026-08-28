import '../diet_macro_plan.dart';
import '../nutrition_pathway.dart';

const leanMassPathway = NutritionPathway(
  id: 'lean-mass',
  arTitle: 'بناء الكتلة العضلية',
  enTitle: 'Lean mass builder',
  arSubtitle: 'فائض مضبوط يدعم التدريب والتعافي',
  enSubtitle: 'A controlled surplus for training and recovery',
  asset: 'assets/images/nutrition_plans/strength_lifestyle_v1.webp',
  arTags: ['أداء', 'تعافٍ', 'فائض مضبوط'],
  enTags: ['Performance', 'Recovery', 'Controlled surplus'],
  arApproach: [
    'ابدأ بفائض صغير قابل للتعديل',
    'اربط الأيام بحمل التدريب',
    'ارفع الطاقة فقط عند الحاجة',
  ],
  enApproach: [
    'Start with a small reviewable surplus',
    'Match days to training load',
    'Increase energy only when needed',
  ],
  arTracking: ['الأداء', 'اتجاه الوزن', 'محيط الخصر والتعافي'],
  enTracking: ['Performance', 'Weight trend', 'Waist trend and recovery'],
);

final leanMassPreset = DietPreset(
  pathwayId: 'lean-mass',
  calories: 2400,
  fatLevel: DietFatLevel.lighter,
  carbsByWeekday: uniformWeeklyCarbs(280),
);
