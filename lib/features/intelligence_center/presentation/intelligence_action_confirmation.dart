part of 'intelligence_center_page.dart';

extension _IntelligenceActionConfirmation on _IntelligenceCenterPageState {
  bool _allowsCoachAction(
    CoachActionBinding binding,
    CoachActionPermissionMode mode,
  ) {
    if (binding.allows(mode)) return true;
    _appendToolReceipt(
      tr(
        'This action needs write permission. Change the shield setting to continue.',
        'يحتاج هذا الإجراء إلى إذن كتابة. غيّر إعداد الدرع للمتابعة.',
      ),
      verifiedResult: false,
    );
    return false;
  }

  Future<bool> _confirmAction(IntelligenceAction action) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        icon: Icon(
          action.destructive
              ? BilSemanticIcons.deleteAccount
              : _iconForAction(action.type),
          color: action.destructive
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
        title: Text(tr('Confirm action', 'تأكيد الإجراء')),
        content: Text(_coachActionConfirmationText(action)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Continue', 'متابعة')),
          ),
        ],
      ),
    );
    if (accepted != true) return false;
    if (!action.destructive || !mounted) return true;
    return _confirmDestructiveAction(action);
  }

  String _coachActionConfirmationText(IntelligenceAction action) {
    if (action.type != IntelligenceActionType.moveMealItem ||
        action.payload['date'] == null) {
      return action.label;
    }
    final meal = switch (action.payload['mealType']) {
      'breakfast' => tr('Breakfast', 'الإفطار'),
      'lunch' => tr('Lunch', 'الغداء'),
      'dinner' => tr('Dinner', 'العشاء'),
      'snack' => tr('Snack', 'وجبة خفيفة'),
      _ => null,
    };
    return [
      action.label,
      _coachDateLabel(DateTime.parse(action.payload['date']! as String)),
      if (meal != null) '${tr('Meal', 'الوجبة')}: $meal',
    ].join('\n');
  }

  Future<bool> _confirmDestructiveAction(IntelligenceAction action) async {
    final controller = TextEditingController();
    try {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              scrollable: true,
              icon: Icon(
                BilSemanticIcons.deleteAccount,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(tr('Final confirmation', 'التأكيد النهائي')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.label),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      'Type DELETE to continue. This confirmation cannot be supplied by AI Coach.',
                      'اكتب حذف للمتابعة. لا يستطيع المدرب الذكي تقديم هذا التأكيد نيابةً عنك.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: tr('Confirmation word', 'كلمة التأكيد'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(tr('Cancel', 'إلغاء')),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    Navigator.pop(
                      dialogContext,
                      value == 'DELETE' || value == 'حذف',
                    );
                  },
                  child: Text(tr('Confirm', 'تأكيد')),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      controller.dispose();
    }
  }
}
