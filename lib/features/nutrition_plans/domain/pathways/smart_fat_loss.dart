import '../diet_macro_plan.dart';
import '../nutrition_pathway.dart';

const smartFatLossPathway = NutritionPathway(
  id: 'cutting',
  arTitle: 'خفض الدهون الذكي',
  enTitle: 'Smart fat loss',
  arSubtitle: 'عجز محسوب مع حماية الكتلة العضلية',
  enSubtitle: 'A measured deficit designed to preserve lean mass',
  asset: 'assets/images/nutrition_plans/balanced_market_lifestyle_v1.webp',
  arTags: ['بروتين مرتفع', 'عجز معتدل', 'قابل للمراجعة'],
  enTags: ['Higher protein', 'Moderate deficit', 'Reviewable'],
  arApproach: [
    'حدد العجز من بياناتك الفعلية',
    'وزّع البروتين على الوجبات',
    'راجع اتجاه الوزن والأداء',
  ],
  enApproach: [
    'Set the deficit from measured data',
    'Distribute protein across meals',
    'Review weight trend and performance',
  ],
  arTracking: ['اتجاه الوزن', 'القوة والتعافي', 'الجوع والالتزام'],
  enTracking: ['Weight trend', 'Strength and recovery', 'Hunger and adherence'],
);

final smartFatLossPreset = DietPreset(
  pathwayId: 'cutting',
  calories: 1800,
  fatLevel: DietFatLevel.lighter,
  carbsByWeekday: uniformWeeklyCarbs(160),
);
