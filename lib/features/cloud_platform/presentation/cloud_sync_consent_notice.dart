import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../providers/cloud_manual_sync_status_provider.dart';
import '../providers/cloud_sync_providers.dart';
import '../services/cloud_sync_consent_repository.dart';

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

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(cloudSyncConsentStateProvider);
    consent.whenData((state) {
      final needsChoice =
          state.availability == CloudSyncConsentAvailability.available &&
          state.recordedAt == null;
      if (needsChoice && !_scheduled && !_saving) {
        _scheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _presentChoice());
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
                const Icon(Icons.cloud_done_outlined, size: 40),
                const SizedBox(height: 12),
                Text(
                  context.strings.text('Keep your BIL data safe?'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.strings.text(
                    'Encrypted backup stores your profile, weight and water so BIL can restore them after reinstalling or changing devices. Nutrition stays on this device.',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.strings.text(
                    'If you later turn sync off, future uploads stop. An existing cloud copy is retained until you delete your account or request data deletion in Privacy.',
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  key: const Key('cloud-sync-enable-backup'),
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: Text(context.strings.text('Enable encrypted backup')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('cloud-sync-keep-local'),
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: Text(context.strings.text('Keep only on this device')),
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
}
