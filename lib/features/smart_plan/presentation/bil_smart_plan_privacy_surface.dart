part of 'bil_smart_plan_page.dart';

extension _BilSmartPlanPrivacySurface on _BilSmartPlanPageState {
  Widget _privacySurface() => Scaffold(
    key: const ValueKey('bil-smart-plan-data-management'),
    appBar: AppBar(title: Text(_t('Plan data', 'بيانات الخطة'))),
    body: BilPearlBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_busy && _reviewDepth == 0) const BilFeatureWelcomeStatus(),
                _panel(
                  child: Text(
                    _t(
                      'Manage your saved plan data without a subscription. Export or delete the local schedule and its receipts. Stop backup removes the remote plan; complete that step before uninstalling to remove an existing cloud copy. Actual diary entries stay in your activity history.',
                      'أدر بيانات خطتك دون اشتراك. صدّر الجدول المحلي وإيصالاته أو احذفها. إيقاف النسخ يمحو الخطة السحابية؛ أكمل هذه الخطوة قبل إزالة التطبيق لحذف نسخة سحابية موجودة. تبقى الأنشطة الفعلية في دفتر الأنشطة.',
                    ),
                  ),
                ),
                if (_error != null)
                  _panel(
                    child: Text(
                      _t(
                        'Could not complete the request. Your remaining data is kept. Retry safely.',
                        'تعذر إكمال الطلب. احتُفظ ببياناتك المتبقية. يمكنك إعادة المحاولة بأمان.',
                      ),
                    ),
                  ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _smartPlanActionInk(context),
                  ),
                  onPressed: _busy ? null : _showPreviousPlans,
                  child: Text(
                    _t(
                      'Previous plans on this device',
                      'الخطط السابقة على هذا الجهاز',
                    ),
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _smartPlanActionInk(context),
                  ),
                  onPressed: _busy ? null : _clearLocalPreviousPlans,
                  child: Text(
                    _t(
                      'Delete previous plans and pending draft?',
                      'حذف الخطط السابقة والمسودة المعلقة؟',
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _smartPlanActionInk(context),
                  ),
                  onPressed: _busy ? null : _exportPlan,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(_t('Export plan', 'تصدير الخطة')),
                ),
                if (_plan != null) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _smartPlanActionInk(context),
                    ),
                    onPressed: _busy ? null : _deletePlan,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(_t('Delete plan', 'حذف الخطة')),
                  ),
                ],
                if (const bool.fromEnvironment('BIL_SMART_PLAN_CLOUD_ENABLED'))
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _smartPlanActionInk(context),
                    ),
                    onPressed: _busy || _owner == null
                        ? null
                        : () => _syncPlan(revoke: true),
                    icon: const Icon(Icons.cloud_off_outlined),
                    label: Text(_t('Stop backup', 'إيقاف النسخ')),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
