import '../diet_macro_plan.dart';
import '../nutrition_pathway.dart';

const dashPathway = NutritionPathway(
  id: 'dash',
  arTitle: 'نمط DASH',
  enTitle: 'DASH pattern',
  arSubtitle: 'نمط متوازن يركز على جودة الطعام والصوديوم',
  enSubtitle: 'A balanced pattern focused on food quality and sodium',
  asset: 'assets/images/nutrition_plans/balanced_market_lifestyle_v1.webp',
  arTags: ['صوديوم واعٍ', 'متوازن', 'صحة القلب'],
  enTags: ['Sodium aware', 'Balanced', 'Heart health'],
  arApproach: [
    'فضّل الطعام قليل التصنيع',
    'قارن الصوديوم من الملصقات الموثقة',
    'راجع المختص عند وجود مرض أو دواء',
  ],
  enApproach: [
    'Prefer minimally processed food',
    'Compare sodium from verified labels',
    'Review with a clinician when disease or medication is relevant',
  ],
  arTracking: ['الصوديوم', 'جودة الغذاء', 'القياسات الموثقة'],
  enTracking: ['Sodium', 'Food quality', 'Verified measurements'],
  safety: NutritionPathwaySafety.clinicianReview,
);

final dashPreset = DietPreset(
  pathwayId: 'dash',
  calories: 2000,
  fatLevel: DietFatLevel.lighter,
  carbsByWeekday: uniformWeeklyCarbs(225),
);
