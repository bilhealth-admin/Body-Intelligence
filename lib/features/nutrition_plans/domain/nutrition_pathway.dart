enum NutritionPathwaySafety { standard, clinicianReview, medicalSupervision }

class NutritionPathway {
  const NutritionPathway({
    required this.id,
    required this.arTitle,
    required this.enTitle,
    required this.arSubtitle,
    required this.enSubtitle,
    required this.asset,
    required this.arTags,
    required this.enTags,
    required this.arApproach,
    required this.enApproach,
    required this.arTracking,
    required this.enTracking,
    this.safety = NutritionPathwaySafety.standard,
  });

  final String id;
  final String arTitle;
  final String enTitle;
  final String arSubtitle;
  final String enSubtitle;
  final String asset;
  final List<String> arTags;
  final List<String> enTags;
  final List<String> arApproach;
  final List<String> enApproach;
  final List<String> arTracking;
  final List<String> enTracking;
  final NutritionPathwaySafety safety;
}

const nutritionPathways = <NutritionPathway>[
  NutritionPathway(
    id: 'cutting',
    arTitle: 'خفض الدهون الذكي',
    enTitle: 'Smart fat loss',
    arSubtitle: 'عجز محسوب مع حماية الكتلة العضلية',
    enSubtitle: 'A measured deficit designed to preserve lean mass',
    asset: 'assets/images/nutrition_plans/cutting.png',
    arTags: ['بروتين مرتفع', 'عجز معتدل', 'قابل للمراجعة'],
    enTags: ['Higher protein', 'Moderate deficit', 'Reviewable'],
    arApproach: [
      'حدد العجز بعد مراجعة بياناتك الفعلية',
      'وزّع البروتين على الوجبات',
      'عدّل المسودة وفق اتجاه الوزن والأداء',
    ],
    enApproach: [
      'Set the deficit from measured data',
      'Distribute protein across meals',
      'Review against weight trend and performance',
    ],
    arTracking: ['اتجاه الوزن', 'القوة والتعافي', 'الجوع والالتزام'],
    enTracking: [
      'Weight trend',
      'Strength and recovery',
      'Hunger and adherence',
    ],
  ),
  NutritionPathway(
    id: 'lean-mass',
    arTitle: 'بناء الكتلة العضلية',
    enTitle: 'Lean mass builder',
    arSubtitle: 'فائض مضبوط يدعم التدريب والتعافي',
    enSubtitle: 'A controlled surplus for training and recovery',
    asset: 'assets/images/nutrition_plans/lean_mass.png',
    arTags: ['أداء', 'تعافٍ', 'فائض مضبوط'],
    enTags: ['Performance', 'Recovery', 'Controlled surplus'],
    arApproach: [
      'ابدأ بفائض صغير قابل للتعديل',
      'اربط الوجبات بحمل التدريب',
      'ارفع الطاقة فقط عند الحاجة',
    ],
    enApproach: [
      'Start with a small reviewable surplus',
      'Match meals to training load',
      'Increase energy only when evidence supports it',
    ],
    arTracking: ['الأداء', 'اتجاه الوزن', 'محيط الخصر والتعافي'],
    enTracking: ['Performance', 'Weight trend', 'Waist trend and recovery'],
  ),
  NutritionPathway(
    id: 'mediterranean',
    arTitle: 'النمط المتوسطي',
    enTitle: 'Mediterranean',
    arSubtitle: 'خضار وحبوب كاملة ودهون غير مشبعة بتوازن مرن',
    enSubtitle: 'Flexible whole foods with unsaturated fats',
    asset: 'assets/images/nutrition_plans/low_carb.png',
    arTags: ['صحة القلب', 'مرن', 'ألياف'],
    enTags: ['Heart health', 'Flexible', 'Fibre'],
    arApproach: [
      'اجعل الخضار والحبوب والبقول أساسًا',
      'استخدم دهونًا غير مشبعة',
      'حافظ على مرونة اجتماعية واقعية',
    ],
    enApproach: [
      'Build around vegetables, whole grains and legumes',
      'Prefer unsaturated fats',
      'Keep the pattern socially flexible',
    ],
    arTracking: ['الألياف', 'تنوع الغذاء', 'الاتساق الأسبوعي'],
    enTracking: ['Fibre', 'Food variety', 'Weekly consistency'],
  ),
  NutritionPathway(
    id: 'high-protein',
    arTitle: 'متوازن عالي البروتين',
    enTitle: 'Balanced high protein',
    arSubtitle: 'شبع أفضل ودعم للعضلات من دون قيود متطرفة',
    enSubtitle: 'Satiety and muscle support without extreme restriction',
    asset: 'assets/images/nutrition_plans/cutting.png',
    arTags: ['متوازن', 'شبع', 'عضلات'],
    enTags: ['Balanced', 'Satiety', 'Muscle support'],
    arApproach: [
      'اختر مصادر بروتين متنوعة',
      'وزعها خلال اليوم',
      'اترك مساحة للكربوهيدرات والدهون عالية الجودة',
    ],
    enApproach: [
      'Use varied protein sources',
      'Distribute them through the day',
      'Keep room for quality carbohydrate and fat',
    ],
    arTracking: ['البروتين المسجل', 'الشبع', 'الأداء'],
    enTracking: ['Logged protein', 'Satiety', 'Performance'],
  ),
  NutritionPathway(
    id: 'plant-forward',
    arTitle: 'نباتي مرن',
    enTitle: 'Plant forward',
    arSubtitle: 'أغذية نباتية أكثر مع بروتين وعناصر دقيقة محسوبة',
    enSubtitle: 'More plants with planned protein and micronutrients',
    asset: 'assets/images/nutrition_plans/pregnancy.png',
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
  ),
  NutritionPathway(
    id: 'dash',
    arTitle: 'نمط DASH',
    enTitle: 'DASH pattern',
    arSubtitle: 'نمط متوازن يركز على جودة الطعام والصوديوم',
    enSubtitle: 'A balanced pattern focused on food quality and sodium',
    asset: 'assets/images/nutrition_plans/low_carb.png',
    arTags: ['صوديوم واعٍ', 'متوازن', 'مراجعة'],
    enTags: ['Sodium aware', 'Balanced', 'Review'],
    arApproach: [
      'ركز على الطعام قليل التصنيع',
      'قارن الصوديوم من الملصقات الموثقة',
      'راجع الخطة مع المختص عند وجود مرض أو دواء',
    ],
    enApproach: [
      'Prefer minimally processed food',
      'Compare sodium from verified labels',
      'Review with a clinician when disease or medication is relevant',
    ],
    arTracking: ['الصوديوم', 'جودة الغذاء', 'القياسات الموثقة'],
    enTracking: ['Sodium', 'Food quality', 'Verified measurements'],
    safety: NutritionPathwaySafety.clinicianReview,
  ),
  NutritionPathway(
    id: 'low-carb',
    arTitle: 'لو كارب متوسطي',
    enTitle: 'Mediterranean low carb',
    arSubtitle: 'كربوهيدرات أقل مع ألياف ودهون غير مشبعة',
    enSubtitle: 'Lower carbohydrate with fibre and unsaturated fats',
    asset: 'assets/images/nutrition_plans/low_carb.png',
    arTags: ['متوسطي', 'مرن', 'ألياف'],
    enTags: ['Mediterranean', 'Flexible', 'Fibre'],
    arApproach: [
      'خفّض الكربوهيدرات دون إلغاء الألياف',
      'اختر مصادر غير مصنعة',
      'عدّل المستوى وفق الاستجابة والالتزام',
    ],
    enApproach: [
      'Lower carbohydrate without removing fibre',
      'Choose minimally processed sources',
      'Adjust to response and adherence',
    ],
    arTracking: ['الألياف', 'الطاقة والجوع', 'اتجاه الوزن'],
    enTracking: ['Fibre', 'Energy and hunger', 'Weight trend'],
  ),
  NutritionPathway(
    id: 'keto',
    arTitle: 'كيتو موجّه',
    enTitle: 'Guided keto',
    arSubtitle: 'كربوهيدرات شديدة الانخفاض ضمن حدود واضحة',
    enSubtitle: 'Very low carbohydrate with explicit boundaries',
    asset: 'assets/images/nutrition_plans/keto.png',
    arTags: ['كربوهيدرات منخفضة', 'إلكتروليتات', 'مراجعة'],
    enTags: ['Very low carb', 'Electrolytes', 'Review'],
    arApproach: [
      'افحص ملاءمة المسار قبل البدء',
      'لا تغيّر الدواء أو السوائل ذاتيًا',
      'ابنِ مسودة غذائية قابلة للإيقاف والمراجعة',
    ],
    enApproach: [
      'Check suitability before starting',
      'Never self-adjust medication or fluids',
      'Use a stoppable, reviewable food draft',
    ],
    arTracking: ['الأعراض', 'الالتزام', 'مراجعة المختص'],
    enTracking: ['Symptoms', 'Adherence', 'Clinician review'],
    safety: NutritionPathwaySafety.clinicianReview,
  ),
  NutritionPathway(
    id: 'pregnancy',
    arTitle: 'تغذية الحمل',
    enTitle: 'Pregnancy nutrition',
    arSubtitle: 'دعم غذائي يحترم المرحلة وتوصيات الطبيب',
    enSubtitle: 'Nutrition support aligned with trimester and clinician advice',
    asset: 'assets/images/nutrition_plans/pregnancy.png',
    arTags: ['عناصر دقيقة', 'سلامة الغذاء', 'مراجعة مختص'],
    enTags: ['Micronutrients', 'Food safety', 'Clinician review'],
    arApproach: [
      'اربط المسودة بمرحلة الحمل وتوجيه الطبيب',
      'أعط الأولوية لسلامة الغذاء',
      'لا تستخدم عجزًا أو مكملات دون مراجعة',
    ],
    enApproach: [
      'Align the draft with trimester and clinician guidance',
      'Prioritize food safety',
      'Do not set deficits or supplements without review',
    ],
    arTracking: ['توجيه الطبيب', 'سلامة الغذاء', 'كفاية التسجيل'],
    enTracking: ['Clinician guidance', 'Food safety', 'Logging sufficiency'],
    safety: NutritionPathwaySafety.clinicianReview,
  ),
  NutritionPathway(
    id: 'psmf',
    arTitle: 'PSMF بإشراف طبي',
    enTitle: 'Clinician-supervised PSMF',
    arSubtitle: 'بروتوكول مقيد لا يُستخدم ذاتياً',
    enSubtitle: 'A restrictive protocol that is not for self-use',
    asset: 'assets/images/nutrition_plans/psmf.png',
    arTags: ['إشراف طبي', 'غير ذاتي', 'متابعة'],
    enTags: ['Medical supervision', 'Not self-directed', 'Monitoring'],
    arApproach: [
      'لا يُنشئ التطبيق بروتوكول PSMF ذاتيًا',
      'يلزم اعتماد ومتابعة سريرية حقيقية',
      'يوقف المسار عند غياب الإشراف',
    ],
    enApproach: [
      'BIL never generates a self-directed PSMF protocol',
      'Real clinical approval and monitoring are required',
      'The pathway remains locked without supervision',
    ],
    arTracking: ['اعتماد المختص', 'المتابعة السريرية', 'حالة الأمان'],
    enTracking: ['Clinician approval', 'Clinical monitoring', 'Safety status'],
    safety: NutritionPathwaySafety.medicalSupervision,
  ),
];
