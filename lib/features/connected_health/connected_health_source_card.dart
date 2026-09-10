part of 'connected_health_page.dart';

/// Keep status and the explicit import action visible. Secondary permission
/// controls expand separately and never squeeze long translations into columns.
class _HealthSourceCard extends ConsumerWidget {
  const _HealthSourceCard({
    required this.snapshot,
    required this.onOpenSettings,
    required this.title,
  });

  final ConnectedHealthSnapshot snapshot;
  final VoidCallback onOpenSettings;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String tr(String en, String ar) => connectedHealthText(context, en, ar);
    final controller = ref.read(connectedHealthProvider.notifier);
    final canSync = switch (snapshot.status) {
      ConnectedHealthStatus.ready ||
      ConnectedHealthStatus.syncing ||
      ConnectedHealthStatus.synchronized ||
      ConnectedHealthStatus.authorizationRequested ||
      ConnectedHealthStatus.degraded => true,
      _ => false,
    };
    return PremiumSurface(
      key: const Key('connected-health-source-card'),
      dashboardGlass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: tr('Connection status', 'حالة الاتصال'),
            child: Text(
              connectedHealthStatusText(context, snapshot.status),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (canSync)
            FilledButton.icon(
              key: const Key('connected-health-sync-now'),
              onPressed: snapshot.isBusy ? null : controller.synchronize,
              icon: snapshot.isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(
                snapshot.isBusy
                    ? tr('Synchronizing…', 'تتم المزامنة…')
                    : tr('Sync now', 'تحديث الساعة'),
                textAlign: TextAlign.center,
              ),
            ),
          if (connectedHealthCanRequestPermissions(snapshot.status))
            FilledButton.icon(
              onPressed: snapshot.isBusy
                  ? null
                  : () async {
                      await controller.requestPermissions();
                      if (context.mounted &&
                          ref
                                  .read(connectedHealthProvider)
                                  .value
                                  ?.failureCode ==
                              'health_permissions_review_required') {
                        await showAppleHealthPermissionReview(
                          context,
                          onOpenSettings: controller.openSystemSettings,
                        );
                      }
                    },
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(
                tr('Grant health access', 'منح إذن الصحة'),
                textAlign: TextAlign.center,
              ),
            ),
          if (snapshot.status == ConnectedHealthStatus.updateRequired ||
              snapshot.status == ConnectedHealthStatus.permissionDenied ||
              snapshot.failureCode == 'revoke_in_system_settings_required')
            OutlinedButton.icon(
              onPressed: snapshot.isBusy ? null : onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: Text(
                tr('Open system settings', 'فتح إعدادات النظام'),
                textAlign: TextAlign.center,
              ),
            ),
          ExpansionTile(
            key: const Key('connected-health-source-settings'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(tr('Manage fitness sources', 'إدارة مصادر اللياقة')),
            children: [
              if (!kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.iOS &&
                  snapshot.status ==
                      ConnectedHealthStatus.authorizationRequested &&
                  snapshot.signals.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    tr(
                      'Apple Health does not reveal read permission status. Open the Health app, check BIL under Apps, then return and tap Sync now. Only records actually provided by Apple Health will appear.',
                      'لا تكشف Apple Health حالة إذن القراءة. افتح تطبيق الصحة، تحقق من BIL ضمن التطبيقات، ثم عد واضغط «تحديث الساعة». ستظهر فقط السجلات التي يوفرها Apple Health فعليًا.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('connected-health-refresh-status'),
                  onPressed: snapshot.isBusy ? null : controller.refresh,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(
                    tr('Refresh status', 'فحص الاتصال'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (snapshot.deviceVerified) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('connected-health-weight-export'),
                    onPressed: snapshot.isBusy
                        ? null
                        : controller.requestWeightWritePermission,
                    icon: const Icon(Icons.monitor_weight_outlined),
                    label: Text(
                      defaultTargetPlatform == TargetPlatform.iOS
                          ? tr('Allow weight export', 'السماح بتصدير الوزن')
                          : tr(
                              'Allow weight and nutrition export',
                              'السماح بتصدير الوزن والتغذية',
                            ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: snapshot.isBusy
                      ? null
                      : controller.revokePermissions,
                  icon: const Icon(Icons.link_off_rounded),
                  label: Text(
                    tr('Disconnect health source', 'فصل مصدر الصحة'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
