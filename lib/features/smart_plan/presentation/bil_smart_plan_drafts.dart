part of 'bil_smart_plan_page.dart';

extension _BilSmartPlanDrafts on _BilSmartPlanPageState {
  Future<void> _clearLocalPreviousPlans() async {
    final owner = _owner;
    final epoch = _ownerEpoch;
    if (_busy || owner == null) return;
    final repository = _repository;
    final archives = await repository.preferences.get(
      repository.archiveKey(owner),
    );
    final draft = await repository.preferences.get(repository.draftKey(owner));
    final conflicts = await repository.preferences.get(
      'bil.smart-plan.conflicts.$owner.v1',
    );
    if (!mounted || epoch != _ownerEpoch) return;
    final confirmed = await _confirmDialog(
      context: context,
      builder: (dialog) => BilPearlMaterialAlertDialog(
        title: Text(
          _t(
            'Delete previous plans and pending draft?',
            'حذف الخطط السابقة والمسودة المعلقة؟',
          ),
        ),
        content: Text(
          _t(
            'Only these local copies and their private receipts will be removed. Your current saved plan and actual diary remain.',
            'ستُحذف هذه النسخ المحلية وإيصالاتها الخاصة فقط. تبقى خطتك الحالية ودفتر الأنشطة الفعلي.',
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
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(_t('Confirm', 'تأكيد')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || epoch != _ownerEpoch) return;
    try {
      await repository.deleteLocalPreviousPlans(
        owner: owner,
        expectedArchives: archives,
        expectedDraft: draft,
        expectedConflicts: conflicts,
      );
      if (mounted && epoch == _ownerEpoch) await _load();
    } on Object catch (error) {
      if (mounted && epoch == _ownerEpoch) {
        _mutate(() => _error = error.toString());
      }
    }
  }

  Widget _draftNotice() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(
            'Your current plan stays active until you approve this draft.',
            'تبقى خطتك الحالية نشطة حتى توافق على هذه المسودة.',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            'Pending drafts and previous plans stay on this device. Cloud backup includes the current saved plan only.',
            'تبقى المسودات المعلقة والخطط السابقة على هذا الجهاز. يشمل النسخ السحابي الخطة المحفوظة الحالية فقط.',
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: _smartPlanActionInk(context),
          ),
          onPressed: _busy ? null : _load,
          child: Text(_t('Current saved plan', 'الخطة المحفوظة الحالية')),
        ),
      ],
    ),
  );

  Future<void> _openDraft() async {
    final epoch = _ownerEpoch;
    final owner = _owner;
    if (_busy || owner == null) return;
    _mutate(() => _busy = true);
    try {
      _checkAccess();
      final draft = await _repository.readDraft(owner);
      if (!mounted || epoch != _ownerEpoch) return;
      if (draft == null) {
        _mutate(() => _busy = false);
        return;
      }
      final dietary = await ref
          .read(dietaryPreferencesRepositoryProvider)
          .read();
      await const BilSmartPlanCatalog().validate(draft, dietary);
      _checkAccess();
      if (!mounted || epoch != _ownerEpoch) return;
      _mutate(() {
        _plan = draft;
        _reviewingDraft = true;
        _busy = false;
        _catalogBlocked = false;
        _error = null;
      });
    } on Object catch (error) {
      if (mounted && epoch == _ownerEpoch) {
        _mutate(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _discardDraft() async {
    final draft = _plan;
    final epoch = _ownerEpoch;
    if (draft == null || !_reviewingDraft || _busy) return;
    final confirmed = await _confirmDialog(
      context: context,
      builder: (dialog) => BilPearlMaterialAlertDialog(
        title: Text(_t('Discard pending draft?', 'حذف المسودة المعلقة؟')),
        content: Text(
          _t(
            'Your current saved plan and diary will stay unchanged.',
            'ستبقى خطتك المحفوظة الحالية ودفترك دون تغيير.',
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
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(_t('Confirm', 'تأكيد')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || epoch != _ownerEpoch) return;
    try {
      _checkAccess();
      await _repository.discardDraft(draft);
      if (mounted && epoch == _ownerEpoch) await _load();
    } on Object catch (error) {
      if (mounted && epoch == _ownerEpoch) {
        _mutate(() => _error = error.toString());
      }
    }
  }

  Future<void> _showPreviousPlans() async {
    final owner = _owner;
    final epoch = _ownerEpoch;
    if (_busy || owner == null) return;
    try {
      final previous = await _repository.readArchives(owner);
      if (!mounted || epoch != _ownerEpoch) return;
      await _reviewSurface(
        () => showBilModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (sheet) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _t(
                      'Previous plans on this device',
                      'الخطط السابقة على هذا الجهاز',
                    ),
                    style: Theme.of(sheet).textTheme.headlineSmall,
                  ),
                  Text(
                    _t(
                      'Read only. Export includes these plans. They are not included in active-plan cloud backup.',
                      'للقراءة فقط. يشمل التصدير هذه الخطط، ولا يشملها النسخ السحابي للخطة الحالية.',
                    ),
                  ),
                  for (final plan in previous.reversed)
                    ExpansionTile(
                      title: Text(
                        '${plan.startDate} · ${_horizonName(plan.horizon)}',
                      ),
                      subtitle: Text(
                        '${_statusName(plan.status)} · ${plan.revision}',
                      ),
                      children: [
                        for (final day in plan.days)
                          ListTile(
                            title: Text(day.date),
                            subtitle: Text(
                              day.workout == null
                                  ? _t('Recovery day', 'يوم راحة')
                                  : '${day.workout!.exerciseIds.map(const BilSmartPlanCatalog().exerciseTitle).join(', ')} · ${day.workout!.completed ? _t('Completed', 'مكتمل') : _t('Not confirmed', 'غير مؤكد')}',
                            ),
                          ),
                      ],
                    ),
                  if (previous.isEmpty)
                    Text(_t('No previous plans.', 'لا توجد خطط سابقة.')),
                ],
              ),
            ),
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted && epoch == _ownerEpoch) {
        _mutate(() => _error = error.toString());
      }
    }
  }
}
