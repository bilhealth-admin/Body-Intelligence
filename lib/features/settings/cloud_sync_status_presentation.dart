import 'package:flutter/material.dart';

import '../cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import '../cloud_platform/services/cloud_manual_sync_service.dart';
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
        if (status.reason != null && !status.isSyncing)
          Text(
            _tr(
              context,
              status.reason == 'conflict_review_required'
                  ? 'Review backup conflicts to finish synchronization.'
                  : status.reason == 'server_unsupported' ||
                        status.reason == 'server_or_consent_unavailable'
                  ? 'This server cannot currently restore the selected data.'
                  : 'Some data is still pending. Retry synchronization.',
              status.reason == 'conflict_review_required'
                  ? 'راجع تعارضات النسخة الاحتياطية لإكمال المزامنة.'
                  : status.reason == 'server_unsupported' ||
                        status.reason == 'server_or_consent_unavailable'
                  ? 'الخادم لا يتيح حاليًا استعادة البيانات المختارة.'
                  : 'بعض البيانات ما زالت معلقة. أعد محاولة المزامنة.',
            ),
            key: const Key('cloud-sync-partial-reason'),
            style: style,
          ),
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

/// Same truthful result message across More and Sharing & Privacy.
/// This maps known *outcome categories*, never echoes a server exception or
/// a health record. A failed/partial run never claims completed backup.
String cloudManualSyncOutcomeText(
  BuildContext context,
  CloudManualSyncResult result,
) {
  String tr(String en, String ar) => connectedHealthText(context, en, ar);
  if (result.completed) {
    return tr(
      'Encrypted cloud sync completed.',
      'اكتملت المزامنة السحابية المشفّرة.',
    );
  }
  switch (result.disposition) {
    case CloudManualSyncDisposition.completed:
      // A completion without an authoritative timestamp is never accepted by
      // CloudManualSyncResult, so this branch is only defensive.
      return tr(
        'Sync status needs verification. Try again.',
        'تحتاج حالة المزامنة إلى تحقق؛ حاول مجددًا.',
      );
    case CloudManualSyncDisposition.offline:
      return tr(
        'Your device is offline. Connect and retry the encrypted sync.',
        'الجهاز غير متصل بالإنترنت؛ اتصل بالشبكة ثم أعد المزامنة المشفّرة.',
      );
    case CloudManualSyncDisposition.notAuthenticated:
      return tr(
        'Sign in again before synchronizing this account.',
        'سجّل الدخول مجددًا قبل مزامنة هذا الحساب.',
      );
    case CloudManualSyncDisposition.localOwnerMismatch:
      return tr(
        'This device has data from another account. Check the account before syncing.',
        'توجد بيانات محلية مرتبطة بحساب آخر؛ تحقق من الحساب قبل المزامنة.',
      );
    case CloudManualSyncDisposition.entitlementMissing:
      return tr(
        'Encrypted cloud sync requires an active eligible subscription.',
        'تتطلب المزامنة السحابية المشفّرة اشتراكًا مؤهلًا ونشطًا.',
      );
    case CloudManualSyncDisposition.consentMissing:
      return tr(
        'Enable encrypted cloud sync consent first; no data was uploaded.',
        'فعّل موافقة المزامنة السحابية المشفّرة أولًا؛ لم تُرفع بيانات.',
      );
    case CloudManualSyncDisposition.unavailable:
      return tr(
        'Cloud sync is temporarily unavailable. Your local data remains on this device.',
        'المزامنة السحابية غير متاحة مؤقتًا؛ تبقى بياناتك المحلية على هذا الجهاز.',
      );
    case CloudManualSyncDisposition.partial:
      if (result.reason == 'conflict_review_required') {
        return tr(
          'Some records conflict. Review backup conflicts to finish syncing.',
          'توجد سجلات متعارضة؛ راجع تعارضات النسخة الاحتياطية لإكمال المزامنة.',
        );
      }
      if (result.reason == 'server_unsupported' ||
          result.reason == 'server_or_consent_unavailable') {
        return tr(
          'Some selected data cannot be restored by this server yet.',
          'لا يستطيع الخادم استعادة بعض البيانات المحددة حاليًا.',
        );
      }
      if (result.reason == 'record_unsupported') {
        return tr(
          'Some records are not supported for cloud restoration yet.',
          'بعض السجلات غير مدعومة بعد للاستعادة السحابية.',
        );
      }
      if (result.pending > 0) {
        return tr(
          'Sync is incomplete: ${result.pending} record(s) are still pending.',
          'المزامنة غير مكتملة: ما زال هناك ${result.pending} سجلًا معلقًا.',
        );
      }
      return tr(
        'Sync is partially complete. Retry and check backup status.',
        'اكتمل جزء من المزامنة؛ أعد المحاولة وراجع حالة النسخة الاحتياطية.',
      );
  }
}
