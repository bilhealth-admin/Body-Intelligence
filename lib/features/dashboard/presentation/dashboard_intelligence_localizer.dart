import '../../../engine/body_composition_engine.dart';
import '../../../engine/one_best_action_engine.dart';
import '../../../engine/what_changed_engine.dart';
import '../../../app/localization/runtime_copy.dart';

class DashboardIntelligenceLocalizer {
  const DashboardIntelligenceLocalizer({bool? arabic, String? localeTag})
    : localeTag = localeTag ?? (arabic == true ? 'ar' : 'en');

  final String localeTag;

  DashboardIntelligenceLocalizer forLocale(String tag) =>
      DashboardIntelligenceLocalizer(localeTag: tag);

  bool get arabic =>
      localeTag.toLowerCase().split(RegExp('[-_]')).first == 'ar';

  String _localized(String english) {
    final protein = RegExp(r'^Add about (\d+) g protein$').firstMatch(english);
    if (protein != null) {
      return (RuntimeCopy.resolve('Add about {count} g protein', localeTag) ??
              english)
          .replaceFirst('{count}', protein.group(1)!);
    }
    final hydration = RegExp(r'^Drink (\d+) ml gradually$').firstMatch(english);
    if (hydration != null) {
      return (RuntimeCopy.resolve('Drink {count} ml gradually', localeTag) ??
              english)
          .replaceFirst('{count}', hydration.group(1)!);
    }
    return RuntimeCopy.resolve(english, localeTag) ?? english;
  }

  String compositionValue(
    BodyCompositionMetric metric, {
    required String unit,
  }) {
    if (!metric.isAvailable) return compositionIssue(metric.issue);
    return '${metric.value!.toStringAsFixed(1)}$unit';
  }

  String compositionIssue(BodyCompositionIssue? issue) {
    final english = switch (issue) {
      BodyCompositionIssue.missingGender => 'Gender is not recorded',
      BodyCompositionIssue.unsupportedGender => 'Gender value is unsupported',
      BodyCompositionIssue.missingAge => 'Age is not recorded',
      BodyCompositionIssue.invalidAge => 'Age value is invalid',
      BodyCompositionIssue.missingHeight => 'Height is not recorded',
      BodyCompositionIssue.invalidHeight => 'Height value is invalid',
      BodyCompositionIssue.missingWeight => 'Current weight is not recorded',
      BodyCompositionIssue.invalidWeight => 'Current weight is invalid',
      BodyCompositionIssue.missingNeck => 'Neck circumference is not recorded',
      BodyCompositionIssue.invalidNeck => 'Neck circumference is invalid',
      BodyCompositionIssue.missingWaist =>
        'Waist circumference is not recorded',
      BodyCompositionIssue.invalidWaist => 'Waist circumference is invalid',
      BodyCompositionIssue.missingHip => 'Hip circumference is not recorded',
      BodyCompositionIssue.invalidHip => 'Hip circumference is invalid',
      BodyCompositionIssue.invalidBodyFat => 'Body fat estimate is invalid',
      null => 'Unavailable',
    };
    if (!arabic) return _localized(english);
    return switch (issue) {
      BodyCompositionIssue.missingGender => 'الجنس غير مسجل',
      BodyCompositionIssue.unsupportedGender => 'قيمة الجنس غير مدعومة',
      BodyCompositionIssue.missingAge => 'العمر غير مسجل',
      BodyCompositionIssue.invalidAge => 'قيمة العمر غير صالحة',
      BodyCompositionIssue.missingHeight => 'الطول غير مسجل',
      BodyCompositionIssue.invalidHeight => 'قيمة الطول غير صالحة',
      BodyCompositionIssue.missingWeight => 'الوزن الحالي غير مسجل',
      BodyCompositionIssue.invalidWeight => 'الوزن الحالي غير صالح',
      BodyCompositionIssue.missingNeck => 'محيط الرقبة غير مسجل',
      BodyCompositionIssue.invalidNeck => 'محيط الرقبة غير صالح',
      BodyCompositionIssue.missingWaist => 'محيط الخصر غير مسجل',
      BodyCompositionIssue.invalidWaist => 'محيط الخصر غير صالح',
      BodyCompositionIssue.missingHip => 'محيط الورك غير مسجل',
      BodyCompositionIssue.invalidHip => 'محيط الورك غير صالح',
      BodyCompositionIssue.invalidBodyFat => 'تقدير دهون الجسم غير صالح',
      null => 'غير متاح',
    };
  }

  String bestActionTitle(BestAction action) {
    if (!arabic) return _localized(action.title);
    return switch (action.type) {
      BestActionType.weighIn => 'سجّل وزن اليوم',
      BestActionType.completeLogging => 'أكمل تسجيل وجبة واحدة',
      BestActionType.protein => 'أضف مصدر بروتين مناسبًا اليوم',
      BestActionType.hydration => 'اشرب الماء تدريجيًا',
      BestActionType.holdPlan => 'حافظ على الخطة دون تغيير اليوم',
      BestActionType.none => 'لا حاجة لتغيير الخطة',
    };
  }

  String bestActionReason(BestAction action) {
    if (!arabic) return _localized(action.reason);
    return switch (action.type) {
      BestActionType.weighIn => 'القياس اليومي المتقارب يحسن ثقة الاتجاه.',
      BestActionType.completeLogging =>
        'نقص تسجيل الوجبات يضعف تفسير بيانات المدخول.',
      BestActionType.protein => 'البروتين هو أكبر فجوة قابلة للتنفيذ اليوم.',
      BestActionType.hydration => 'الماء المسجل أقل بوضوح من هدف اليوم.',
      BestActionType.holdPlan =>
        'جمع ملاحظات أكثر اتساقًا أكثر أمانًا من التغيير المبكر.',
      BestActionType.none => 'الأولويات المسجلة اليوم مغطاة بصورة عامة.',
    };
  }

  String changedSummary(WhatChangedReport changed) {
    if (!arabic) return _localized(changed.summary);
    return switch (changed.interpretation) {
      ChangeInterpretation.insufficient =>
        'نحتاج قياس وزن آخر في ظروف متقاربة لوصف التغير.',
      ChangeInterpretation.stable =>
        'الوزن مستقر بصورة عامة مقارنة بالقياس السابق.',
      ChangeInterpretation.likelyNoise =>
        'تغير الميزان، لكن قراءة واحدة لا تكفي لتغيير الخطة.',
      ChangeInterpretation.directional =>
        'سُجّل تغير محدود، ويظل الاتجاه عبر عدة أيام أكثر فائدة.',
    };
  }

  String insightTitle(String title) {
    if (!arabic) return _localized(title);
    return switch (title) {
      'Protein below target' => 'البروتين أقل من الهدف',
      'Hydration opportunity' => 'فرصة لتحسين شرب الماء',
      'Possible plateau' => 'ثبات محتمل في الاتجاه',
      'Possible short-term water retention' => 'احتباس ماء قصير المدى محتمل',
      'Build your baseline' => 'ابنِ خطك الأساسي',
      _ => 'الأهداف اليومية متقاربة بصورة عامة',
    };
  }
}
