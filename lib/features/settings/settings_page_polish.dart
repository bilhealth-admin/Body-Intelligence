part of 'settings_page.dart';

class _MorePremiumIcon extends StatelessWidget {
  const _MorePremiumIcon({required this.kind, this.danger = false});

  final BilSemanticIconKind kind;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final healthAccent =
        kind == BilSemanticIconKind.health ||
        kind == BilSemanticIconKind.heartRate;
    final foreground = danger
        ? theme.colorScheme.error
        : healthAccent
        ? (dark ? const Color(0xFFFF8CAD) : const Color(0xFFD91E5B))
        : (dark ? const Color(0xFF8FC2FF) : const Color(0xFF0869E8));
    final background = danger
        ? theme.colorScheme.errorContainer.withValues(alpha: dark ? .36 : .55)
        : healthAccent
        ? (dark ? const Color(0xFF4D1C2D) : const Color(0xFFFFEEF4))
        : (dark ? const Color(0xFF17375F) : const Color(0xFFEAF3FF));
    final spec = BilSemanticIcons.spec(kind);
    return Container(
      key: Key('more-premium-icon-${kind.name}'),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Icon(
        danger ? Icons.delete_outline_rounded : spec.iconFor(theme.platform),
        size: 24,
        color: foreground,
      ),
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
        minTileHeight: 62,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        horizontalTitleGap: 12,
        leading: status.isSyncing
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        title: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        minTileHeight: 54,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        horizontalTitleGap: 12,
        title: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        trailing: Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.chevron_left_rounded
              : Icons.chevron_right_rounded,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
      const Divider(height: 1, indent: 16, endIndent: 16),
    ],
  );
}
