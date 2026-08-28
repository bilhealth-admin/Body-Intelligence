part of 'settings_page.dart';

String _settingsActionText(BuildContext context, String key) {
  final english = switch (key) {
    'review_title' => 'Review your initial setup?',
    'review_body' =>
      'Onboarding will open while keeping your profile, weight records, meals, and all local data. Nothing will be deleted or uploaded.',
    'cancel' => 'Cancel',
    'open_setup' => 'Open setup',
    'setup_failed' =>
      'Initial setup could not be opened. Your data was unchanged.',
    _ => throw ArgumentError.value(key, 'key', 'Unknown settings action copy'),
  };
  return context.strings.text(english);
}

extension _SettingsPageActions on SettingsPage {
  Future<void> _reviewSetupAgain(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_settingsActionText(context, 'review_title')),
        content: Text(_settingsActionText(context, 'review_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_settingsActionText(context, 'cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.tune_rounded),
            label: Text(_settingsActionText(context, 'open_setup')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .set('forceOnboarding', 'true');
      if (context.mounted) context.go('/onboarding');
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_settingsActionText(context, 'setup_failed'))),
      );
    }
  }
}
