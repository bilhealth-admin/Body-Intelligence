import '../diet_macro_plan.dart';
import '../nutrition_pathway.dart';

const pregnancyPathway = NutritionPathway(
  id: 'pregnancy',
  arTitle: 'تغذية الحمل',
  enTitle: 'Pregnancy nutrition',
  arSubtitle: 'أهداف تتكيف مع مرحلة الحمل وتبقى تحت مراجعة الطبيب',
  enSubtitle: 'Targets that adapt by trimester and remain clinician-reviewed',
  asset: 'assets/images/nutrition_plans/pregnancy_lifestyle_v2.webp',
  arTags: ['حسب الثلث', 'عناصر دقيقة', 'مراجعة مختص'],
  enTags: ['By trimester', 'Micronutrients', 'Clinician review'],
  arApproach: [
    'ابدئي من سعرات ما قبل الحمل',
    'طبقي الزيادة حسب الثلث تلقائيًا',
    'أكدي المكملات والجرعات مع طبيب الحمل',
  ],
  enApproach: [
    'Start from pre-pregnancy energy',
    'Apply trimester energy automatically',
    'Confirm supplements and doses with the antenatal clinician',
  ],
  arTracking: ['مرحلة الحمل', 'الحديد والفولات واليود', 'كفاية التسجيل'],
  enTracking: [
    'Pregnancy stage',
    'Iron, folate and iodine',
    'Logging sufficiency',
  ],
  safety: NutritionPathwaySafety.clinicianReview,
);

final pregnancyPreset = DietPreset(
  pathwayId: 'pregnancy',
  calories: 2000,
  fatLevel: DietFatLevel.medium,
  carbsByWeekday: uniformWeeklyCarbs(250),
);
