import '../diet_macro_plan.dart';
import '../nutrition_pathway.dart';

const ketoPathway = NutritionPathway(
  id: 'keto',
  arTitle: 'كيتو موجّه',
  enTitle: 'Guided keto',
  arSubtitle: 'كربوهيدرات شديدة الانخفاض ضمن حدود ومراجعة واضحة',
  enSubtitle: 'Very low carbohydrate with explicit boundaries and review',
  asset: 'assets/images/nutrition_plans/low_carb_outdoor_lifestyle_v1.webp',
  arTags: ['منخفض جدًا', 'إلكتروليتات', 'مراجعة'],
  enTags: ['Very low carb', 'Electrolytes', 'Review'],
  arApproach: [
    'افحص الملاءمة قبل البدء',
    'لا تغيّر الدواء أو السوائل ذاتيًا',
    'استخدم مسودة قابلة للإيقاف والمراجعة',
  ],
  enApproach: [
    'Check suitability before starting',
    'Never self-adjust medication or fluids',
    'Use a stoppable, reviewable draft',
  ],
  arTracking: ['الأعراض', 'الالتزام', 'مراجعة المختص'],
  enTracking: ['Symptoms', 'Adherence', 'Clinician review'],
  safety: NutritionPathwaySafety.clinicianReview,
);

final ketoPreset = DietPreset(
  pathwayId: 'keto',
  calories: 2000,
  fatLevel: DietFatLevel.richer,
  carbsByWeekday: uniformWeeklyCarbs(30),
);
