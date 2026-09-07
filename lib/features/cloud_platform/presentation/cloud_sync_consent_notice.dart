import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/runtime_copy_cloud_sync.dart';
import '../providers/cloud_manual_sync_status_provider.dart';
import '../providers/cloud_sync_providers.dart';
import '../services/cloud_sync_consent_repository.dart';
import 'cloud_sync_consent_summary.dart';

/// One-time, explicit cloud retention choice for authenticated users.
///
/// A declined choice is recorded too, so this is a real consent receipt and
/// not a nag screen. No health record is uploaded before the user chooses the
/// encrypted-backup action.
class CloudSyncConsentNotice extends ConsumerStatefulWidget {
  const CloudSyncConsentNotice({super.key});

  @override
  ConsumerState<CloudSyncConsentNotice> createState() =>
      _CloudSyncConsentNoticeState();
}

class _CloudSyncConsentNoticeState
    extends ConsumerState<CloudSyncConsentNotice> {
  bool _scheduled = false;
  bool _saving = false;
  String? _observedOwnerId;
  String? _autoSyncedOwnerId;

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(cloudSyncConsentStateProvider);
    consent.whenData((state) {
      if (_observedOwnerId != state.ownerId) {
        _observedOwnerId = state.ownerId;
        _scheduled = false;
        _autoSyncedOwnerId = null;
      }
      final needsChoice =
          state.availability == CloudSyncConsentAvailability.available &&
          state.recordedAt == null;
      if (needsChoice && !_scheduled && !_saving) {
        _scheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _presentChoice());
      }
      final hasPriorConsent =
          state.availability == CloudSyncConsentAvailability.available &&
          state.granted &&
          state.ownerId != null;
      if (hasPriorConsent && _autoSyncedOwnerId != state.ownerId && !_saving) {
        _autoSyncedOwnerId = state.ownerId;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _runPreviouslyConsentedSync(state.ownerId!),
        );
      }
    });
    return const SizedBox.shrink();
  }

  Future<void> _presentChoice() async {
    if (!mounted || _saving) return;
    final enable = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => PopScope(
        canPop: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            4,
            24,
            20 + MediaQuery.viewPaddingOf(sheetContext).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.backup_rounded,
                      size: 28,
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  sheetContext.strings.text(CloudSyncConsentCopy.title),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                const CloudSyncConsentSummary(),
                const SizedBox(height: 22),
                FilledButton(
                  key: const Key('cloud-sync-enable-backup'),
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: Text(
                    sheetContext.strings.text(
                      CloudSyncConsentCopy.primaryAction,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('cloud-sync-keep-local'),
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: Text(
                    sheetContext.strings.text(CloudSyncConsentCopy.localAction),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || enable == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(cloudSyncConsentRepositoryProvider).setGranted(enable);
      ref.invalidate(cloudSyncConsentStateProvider);
      ref.invalidate(cloudRuntimePreparationProvider);
      if (enable) {
        // The explicit choice below already starts the first sync. Mark this
        // owner so the post-invalidation build does not start a duplicate.
        _autoSyncedOwnerId = _observedOwnerId;
        final result = await ref
            .read(cloudManualSyncStatusProvider.notifier)
            .runOnce();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.strings.text(
                  result.completed
                      ? 'Encrypted cloud sync completed.'
                      : 'Cloud sync could not run. Check consent and internet.',
                ),
              ),
            ),
          );
        }
      }
    } on Object {
      _scheduled = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.text('Could not update cloud sync. Try again.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runPreviouslyConsentedSync(String ownerId) async {
    if (!mounted || _saving || _observedOwnerId != ownerId) return;
    try {
      await ref.read(cloudManualSyncStatusProvider.notifier).runOnce();
    } on Object {
      // Existing consent must never make the dashboard unusable. The manual
      // Sync now row remains the explicit recovery path for a failed retry.
    }
  }
}
