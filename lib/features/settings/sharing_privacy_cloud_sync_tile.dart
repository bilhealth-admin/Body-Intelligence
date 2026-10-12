part of 'sharing_privacy_settings_page.dart';

class _CloudSyncConsentTile extends ConsumerStatefulWidget {
  const _CloudSyncConsentTile();

  @override
  ConsumerState<_CloudSyncConsentTile> createState() =>
      _CloudSyncConsentTileState();
}

class _CloudSyncConsentTileState extends ConsumerState<_CloudSyncConsentTile> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cloudSyncConsentStateProvider);
    final syncStatus = ref.watch(cloudManualSyncStatusProvider);
    final syncing = syncStatus.isSyncing;
    return state.when(
      loading: () => SwitchListTile.adaptive(
        value: false,
        onChanged: null,
        title: Text(context.strings.text(CloudSyncConsentCopy.settingsTitle)),
        subtitle: Text(_privacyText(context, 'Checking cloud sync…')),
        secondary: const BilSemanticIconBadge(
          kind: BilSemanticIconKind.cloudSync,
        ),
      ),
      error: (_, _) => SwitchListTile.adaptive(
        value: false,
        onChanged: null,
        title: Text(context.strings.text(CloudSyncConsentCopy.settingsTitle)),
        subtitle: Text(
          _privacyText(context, 'Cloud sync is temporarily unavailable.'),
        ),
        secondary: const BilSemanticIconBadge(
          kind: BilSemanticIconKind.cloudSync,
        ),
      ),
      data: (value) {
        final subtitle = switch (value.availability) {
          CloudSyncConsentAvailability.signedOut => _privacyText(
            context,
            'Sign in to manage cloud sync.',
          ),
          CloudSyncConsentAvailability.unavailable => _privacyText(
            context,
            'Cloud sync is temporarily unavailable.',
          ),
          CloudSyncConsentAvailability.available => _privacyText(
            context,
            CloudSyncConsentCopy.settingsSubtitle,
          ),
        };
        return Column(
          children: [
            SwitchListTile.adaptive(
              key: const Key('encrypted-cloud-sync-consent'),
              value: value.granted,
              onChanged: !_saving && !syncing && value.canChange
                  ? (next) => _setConsent(next, value)
                  : null,
              title: Text(
                context.strings.text(CloudSyncConsentCopy.settingsTitle),
              ),
              subtitle: Text(subtitle),
              secondary: _saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const BilSemanticIconBadge(
                      kind: BilSemanticIconKind.cloudSync,
                    ),
            ),
            if (value.granted &&
                value.availability == CloudSyncConsentAvailability.available)
              ListTile(
                key: const Key('encrypted-cloud-sync-now'),
                leading: syncing
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const BilSemanticIconBadge(
                        kind: BilSemanticIconKind.synchronization,
                      ),
                title: Text(_privacyText(context, 'Sync now')),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _privacyText(
                        context,
                        'Run a one-time encrypted sync now.',
                      ),
                    ),
                    const SizedBox(height: 4),
                    CloudSyncStatusLine(status: syncStatus),
                  ],
                ),
                enabled: !_saving && !syncing,
                onTap: !_saving && !syncing ? _runManualSync : null,
              ),
          ],
        );
      },
    );
  }

  Future<void> _runManualSync() async {
    if (_saving || ref.read(cloudManualSyncStatusProvider).isSyncing) return;
    try {
      final result = await ref
          .read(cloudManualSyncStatusProvider.notifier)
          .runOnce();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _privacyText(
              context,
              result.completed
                  ? 'Encrypted cloud sync completed.'
                  : 'Cloud sync could not run. Check consent and internet.',
            ),
          ),
        ),
      );
      ref.invalidate(cloudRuntimePreparationProvider);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _privacyText(
              context,
              'Cloud sync could not run. Check consent and internet.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _setConsent(bool granted, CloudSyncConsentState current) async {
    if (_saving) return;
    if (granted && !current.canEnable) return;
    if (!granted && !current.canDisable) return;

    if (granted) {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(
                dialogContext.strings.text(CloudSyncConsentCopy.title),
              ),
              content: const SingleChildScrollView(
                child: CloudSyncConsentSummary(showDeletionControl: true),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    dialogContext.strings.text(
                      CloudSyncConsentCopy.localAction,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    dialogContext.strings.text(
                      CloudSyncConsentCopy.primaryAction,
                    ),
                  ),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(cloudSyncConsentRepositoryProvider).setGranted(granted);
      ref.invalidate(cloudSyncConsentStateProvider);
      ref.invalidate(cloudRuntimePreparationProvider);
      await ref.read(cloudSyncConsentStateProvider.future);
      CloudManualSyncResult? syncResult;
      if (granted) {
        syncResult = await ref
            .read(cloudManualSyncStatusProvider.notifier)
            .runOnce();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _privacyText(
              context,
              !granted
                  ? 'Cloud sync preference updated.'
                  : syncResult?.completed == true
                  ? 'Encrypted cloud sync completed.'
                  : 'Cloud sync could not run. Check consent and internet.',
            ),
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _privacyText(context, 'Could not update cloud sync. Try again.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
