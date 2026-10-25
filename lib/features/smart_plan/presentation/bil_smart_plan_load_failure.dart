/// Write actions require a present plan with verified backing data.
/// A catalog validation block is read-only even when no exception is shown.
bool shouldBlockUnverifiedSmartPlanWrites({
  required bool hasPlan,
  required bool catalogBlocked,
}) => hasPlan && catalogBlocked;

/// Classifies loading failures without leaking storage details or identifiers.
///
/// Stage separation matters: reading the local plan is independent from
/// validating its supporting catalog and dietary preferences.
String classifySmartPlanLoadFailure(
  Object error, {
  required bool duringCatalog,
}) {
  final description = error.toString();
  if (description.contains('smart_plan_foreign_owner')) {
    return 'smart_plan_owner_mismatch';
  }
  if (description.contains('smart_plan_owner_changed')) {
    return 'smart_plan_owner_changed';
  }
  if (description.contains('smart_plan_revision_conflict')) {
    return 'smart_plan_revision_conflict';
  }
  if (duringCatalog) {
    return 'smart_plan_catalog_unavailable';
  }
  if (error is FormatException) {
    return 'smart_plan_saved_data_invalid';
  }
  return 'smart_plan_storage_unavailable';
}

/// Presentation-only recovery copy. This function never returns a raw error,
/// storage path, account identifier, or underlying exception message.
/// Keeping the mapping separate preserves the 700-line page architecture gate.
String smartPlanLoadFailureMessage(
  String code,
  String Function(String, String) t,
) {
  if (code == 'sign_in_required') {
    return t(
      'Sign in to access your saved plan. No plan data has been deleted.',
      'سجّل الدخول لعرض خطتك المحفوظة. لم تُحذف بيانات الخطة.',
    );
  }
  if (code == 'smart_plan_owner_mismatch' ||
      code == 'smart_plan_owner_changed') {
    return t(
      'The active account changed. Reopen My Plan to view the correct account.',
      'تغيّر الحساب النشط. افتح خطتي مجددًا لعرض بيانات الحساب الصحيح.',
    );
  }
  if (code == 'smart_plan_storage_unavailable') {
    return t(
      'Your saved plan could not be read from this device. Retry; an existing plan has not been overwritten.',
      'تعذّرت قراءة خطتك المحفوظة من هذا الجهاز. أعد المحاولة؛ لم تُستبدل الخطة الموجودة.',
    );
  }
  if (code == 'smart_plan_saved_data_invalid') {
    return t(
      'The saved plan data could not be opened safely. Review the issue before changing your plan.',
      'تعذّر فتح بيانات الخطة المحفوظة بأمان. راجع المشكلة قبل تعديل الخطة.',
    );
  }
  if (code == 'smart_plan_catalog_unavailable') {
    return t(
      'Your plan is saved, but its supporting information could not be checked. Retry before editing it.',
      'خطتك محفوظة، لكن تعذّر التحقق من بياناتها المساندة. أعد المحاولة قبل تعديلها.',
    );
  }
  if (code.contains('revision_conflict') ||
      code.contains('sync_conflict') ||
      code.contains('during_sync')) {
    return t(
      'Your plan changed. Refresh and review it before trying again.',
      'تغيّرت الخطة. حدّثها وراجعها قبل إعادة المحاولة.',
    );
  }
  if (code.contains('reopen_day_first')) {
    return t(
      'Reopen this day in your diary before recording activity.',
      'أعد فتح هذا اليوم في دفتر الأنشطة قبل تسجيل التمرين.',
    );
  }
  if (code.contains('workout_receipt') || code.contains('undo_conflict')) {
    return t(
      'This activity cannot be undone here because its original record is unavailable or has changed. Review your activity diary.',
      'لا يمكن التراجع هنا لأن السجل الأصلي غير متاح أو تغيّر. راجع دفتر الأنشطة.',
    );
  }
  if (code.contains('report_not_sent')) {
    return t(
      'The report was not sent. Please try again.',
      'لم يُرسل البلاغ. حاول مجددًا.',
    );
  }
  if (code.contains('export_failed')) {
    return t(
      'The export could not be opened. Please try again.',
      'تعذّر فتح التصدير. حاول مجددًا.',
    );
  }
  if (code.contains('verified_subscription_required')) {
    return t(
      'Your subscription could not be verified. Refresh your access and try again.',
      'تعذّر التحقق من الاشتراك. حدّث حالة وصولك وحاول مجددًا.',
    );
  }
  if (code.contains('no_verified_workout')) {
    return t(
      'No source-backed session fits these choices. Allow more session time or review your equipment and experience. Your saved plan has not changed.',
      'لا توجد جلسة موثقة تناسب هذه الخيارات. أتح وقتًا أطول أو راجع المعدات والخبرة. لم تتغير خطتك المحفوظة.',
    );
  }
  if (code.contains('home_strength_recovery_days_required')) {
    return t(
      'Home strength sessions need recovery days. Choose up to 3 sessions per week and review the draft.',
      'تحتاج جلسات القوة المنزلية إلى أيام للتعافي. اختر حتى 3 جلسات أسبوعيًا وراجع المسودة.',
    );
  }
  if (code.contains('requires_review')) {
    return t(
      'This plan needs a safety review. Review your age, dietary restrictions and training availability before continuing.',
      'تحتاج هذه الخطة لمراجعة السلامة. راجع العمر وقيود الطعام وتوفر التدريب قبل المتابعة.',
    );
  }
  return t(
    'Action not completed. Please review saved data and retry.',
    'لم تكتمل العملية. راجع البيانات المحفوظة وحاول مجددًا.',
  );
}
