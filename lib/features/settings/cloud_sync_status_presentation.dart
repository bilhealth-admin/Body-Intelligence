import 'package:flutter/material.dart';

import '../cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import '../connected_health/connected_health_copy.dart';

class CloudSyncStatusLine extends StatelessWidget {
  const CloudSyncStatusLine({required this.status, super.key});

  final CloudManualSyncStatus status;

  String _tr(BuildContext context, String en, String ar) =>
      connectedHealthText(context, en, ar);

  @override
  Widget build(BuildContext context) {
    final latest = _tr(context, 'Latest synchronization', 'آخر مزامنة');
    final last = status.lastSuccessfulSyncAt;
    final phaseText = switch (status.phase) {
      CloudManualSyncPhase.loading => latest,
      CloudManualSyncPhase.never => _tr(
        context,
        'Waiting for first sync',
        'بانتظار أول مزامنة',
      ),
      CloudManualSyncPhase.idle => null,
      CloudManualSyncPhase.syncing => _tr(
        context,
        'Synchronizing',
        'تتم المزامنة',
      ),
      CloudManualSyncPhase.unavailable => _tr(
        context,
        'Unavailable',
        'غير متاح',
      ),
    };
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.35,
    );
    return Column(
      key: const Key('cloud-sync-status-line'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (phaseText != null)
          Text(
            phaseText,
            key: ValueKey('cloud-sync-phase-${status.phase.name}'),
            style: style,
          ),
        if (last != null)
          Wrap(
            spacing: 4,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('$latest:', style: style),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  _formatTimestamp(context, last),
                  key: const Key('cloud-last-successful-sync-value'),
                  style: style?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _formatTimestamp(BuildContext context, DateTime utc) {
    final local = utc.toLocal();
    final material = MaterialLocalizations.of(context);
    final date = material.formatMediumDate(local);
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date · $time';
  }
}
