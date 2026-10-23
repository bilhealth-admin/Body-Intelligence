part of 'bil_smart_plan_page.dart';

extension _BilSmartPlanExtendedConsent on _BilSmartPlanPageState {
  Future<void> _shareExtendedPlanContext() async {
    final epoch = _ownerEpoch;
    final owner = _owner;
    final preferences = _repository.preferences;
    const basicKey = 'smartPlan.shareWithCoach.v1';
    const extendedKey = 'smartPlan.shareWithCoach.v2';
    final before = await preferences.get(basicKey);
    final prior = await preferences.get(extendedKey);
    if (!mounted || epoch != _ownerEpoch || owner == null || owner != _owner) {
      return;
    }
    final enabled = prior == 'true';
    final accepted = await _confirmDialog(
      context: context,
      builder: (dialog) => BilPearlMaterialAlertDialog(
        scrollable: true,
        title: Text(
          enabled
              ? _t(
                  'Stop sharing context details?',
                  'إيقاف مشاركة تفاصيل السياق؟',
                )
              : _t('Share more plan context?', 'مشاركة سياق إضافي للخطة؟'),
        ),
        content: Text(
          enabled
              ? _t(
                  'Future requests will omit your weekly schedule, training preferences and revision reasons. Basic plan sharing follows your separate choice.',
                  'لن تتضمن الطلبات التالية الجدول الأسبوعي وتفضيلات التدريب وأسباب التعديلات. تبقى مشاركة الخطة الأساسية وفق اختيارك المنفصل.',
                )
              : _t(
                  'When your question needs them, Coach may use your saved plan, a seven-day training window, confirmed equipment, experience, available time, preferred training time and the five latest revision reasons. With your separate Google Gemini consent and category choices, only the relevant fields may leave this device. No medical history or new permissions are added. You can stop sharing at any time.',
                  'عند الحاجة لسؤالك، يمكن للمدرب استخدام خطتك المحفوظة ونافذة تدريب من سبعة أيام، والمعدات والخبرة والوقت المتاح والوقت المفضل التي أكدتها، وأحدث خمسة أسباب للتعديلات. بموافقة Google Gemini المنفصلة واختيارات فئات البيانات، قد تغادر الجهاز الحقول المرتبطة بالسؤال فقط. لا يُضاف تاريخ طبي أو إذن جديد. يمكنك إيقاف المشاركة في أي وقت.',
                ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _smartPlanActionInk(context),
            ),
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(_t('Cancel', 'إلغاء')),
          ),
          FilledButton(
            key: const ValueKey('bil-smart-plan-extended-context-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(
              enabled
                  ? _t('Stop sharing', 'إيقاف المشاركة')
                  : _t('Allow relevant context', 'السماح بالسياق المرتبط'),
            ),
          ),
        ],
      ),
    );
    if (accepted != true ||
        !mounted ||
        epoch != _ownerEpoch ||
        owner != _owner) {
      return;
    }
    try {
      final saved = await preferences.mutateIfUnchanged(
        expected: {basicKey: before, extendedKey: prior},
        set: enabled
            ? {extendedKey: 'false'}
            : {basicKey: 'true', extendedKey: 'true'},
        isCurrent: () => mounted && epoch == _ownerEpoch && owner == _owner,
      );
      if (!saved) throw StateError('smart_plan_memory_changed');
      ref.invalidate(coachContextSnapshotProvider);
    } on Object {
      if (mounted && epoch == _ownerEpoch) {
        _mutate(() => _error = 'smart_plan_memory_not_saved');
      }
    }
  }
}
