part of 'dashboard_preferences_page.dart';

extension _DashboardPreferencesDoneAction on _DashboardPreferencesPageState {
  Widget _buildDoneEditingAction(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
    child: FilledButton(
      key: const Key('dashboard-preferences-done'),
      onPressed: _savingLayout && !_restoringDefaults ? null : _finishEditing,
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        disabledBackgroundColor: Theme.of(context).colorScheme.primary,
        disabledForegroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      child: Text(_sectionCopy(context, 'Done editing', 'إنهاء التعديل')),
    ),
  );
}
