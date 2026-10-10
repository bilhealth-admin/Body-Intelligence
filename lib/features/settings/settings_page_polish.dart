part of 'settings_page.dart';

class _MorePremiumIcon extends StatelessWidget {
  const _MorePremiumIcon({required this.kind, this.danger = false});

  final BilSemanticIconKind kind;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = danger
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return BilFlatIcon(
      key: Key('more-premium-icon-${kind.name}'),
      kind: kind,
      size: 34,
      iconSize: 20,
      color: foreground,
      materialIcon: danger ? Icons.delete_outline_rounded : null,
      appleIcon: danger ? Icons.delete_outline_rounded : null,
    );
  }
}

class _CloudSyncRow extends ConsumerWidget {
  const _CloudSyncRow({required this.label, required this.status});

  final String label;
  final CloudManualSyncStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      ListTile(
        key: const Key('settings-cloud-sync-status-row'),
        minTileHeight: 70,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        horizontalTitleGap: 8,
        leading: status.isSyncing
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const _MorePremiumIcon(kind: BilSemanticIconKind.cloudSync),
        title: Text(
          label,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w400),
        ),
        subtitle: CloudSyncStatusLine(status: status),
        onTap: status.isSyncing ? null : () => _runSync(context, ref),
      ),
    ],
  );

  Future<void> _runSync(BuildContext context, WidgetRef ref) async {
    if (ref.read(cloudManualSyncStatusProvider).isSyncing) return;
    try {
      final result = await ref
          .read(cloudManualSyncStatusProvider.notifier)
          .runOnce();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text(
              result.completed
                  ? 'Encrypted cloud sync completed.'
                  : 'Cloud sync could not run. Check Premium, consent, and internet.',
            ),
          ),
        ),
      );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text(
              'Cloud sync could not run. Check Premium, consent, and internet.',
            ),
          ),
        ),
      );
    }
  }
}

class _MoreActionRow extends StatelessWidget {
  const _MoreActionRow({
    required this.label,
    required this.kind,
    required this.onTap,
    super.key,
  });

  final String label;
  final BilSemanticIconKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        minTileHeight: 54,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        horizontalTitleGap: 8,
        leading: _MorePremiumIcon(kind: kind),
        title: Text(
          label,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w400),
        ),
        trailing: Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.chevron_left_rounded
              : Icons.chevron_right_rounded,
          size: 22,
          color: const Color(0xFF61738D),
        ),
        onTap: onTap,
      ),
      const Divider(height: 1, indent: 58, endIndent: 16),
    ],
  );
}
