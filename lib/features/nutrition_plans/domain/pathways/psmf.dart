import '../nutrition_pathway.dart';

const psmfPathway = NutritionPathway(
  id: 'psmf',
  arTitle: 'PSMF بإشراف طبي',
  enTitle: 'Clinician-supervised PSMF',
  arSubtitle: 'بروتوكول مقيد لا يُستخدم ذاتيًا',
  enSubtitle: 'A restrictive protocol that is not for self-use',
  asset: 'assets/images/nutrition_plans/strength_lifestyle_v1.webp',
  arTags: ['إشراف طبي', 'غير ذاتي', 'متابعة'],
  enTags: ['Medical supervision', 'Not self-directed', 'Monitoring'],
  arApproach: [
    'لا ينشئ BIL بروتوكول PSMF ذاتيًا',
    'يلزم اعتماد ومتابعة سريرية',
    'يبقى المسار مقفلًا دون إشراف',
  ],
  enApproach: [
    'BIL never generates a self-directed PSMF protocol',
    'Real clinical approval and monitoring are required',
    'The pathway remains locked without supervision',
  ],
  arTracking: ['اعتماد المختص', 'المتابعة السريرية', 'حالة الأمان'],
  enTracking: ['Clinician approval', 'Clinical monitoring', 'Safety status'],
  safety: NutritionPathwaySafety.medicalSupervision,
);
