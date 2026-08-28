import '../diet_macro_plan.dart';
import '../nutrition_pathway.dart';

const highProteinPathway = NutritionPathway(
  id: 'high-protein',
  arTitle: 'متوازن عالي البروتين',
  enTitle: 'Balanced high protein',
  arSubtitle: 'شبع ودعم للعضلات من دون تقييد متطرف',
  enSubtitle: 'Satiety and muscle support without extreme restriction',
  asset: 'assets/images/nutrition_plans/strength_lifestyle_v1.webp',
  arTags: ['متوازن', 'شبع', 'عضلات'],
  enTags: ['Balanced', 'Satiety', 'Muscle support'],
  arApproach: [
    'اختر مصادر بروتين متنوعة',
    'وزعها خلال اليوم',
    'اترك مساحة للكربوهيدرات والدهون الجيدة',
  ],
  enApproach: [
    'Use varied protein sources',
    'Distribute them through the day',
    'Keep room for quality carbohydrate and fat',
  ],
  arTracking: ['البروتين المسجل', 'الشبع', 'الأداء'],
  enTracking: ['Logged protein', 'Satiety', 'Performance'],
);

final highProteinPreset = DietPreset(
  pathwayId: 'high-protein',
  calories: 2000,
  fatLevel: DietFatLevel.lighter,
  carbsByWeekday: uniformWeeklyCarbs(175),
);
