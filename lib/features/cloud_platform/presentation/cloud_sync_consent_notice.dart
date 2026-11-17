import '../../../shared/widgets/bil_pearl_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/runtime_copy_cloud_sync.dart';
import '../providers/cloud_manual_sync_status_provider.dart';
import '../providers/cloud_sync_providers.dart';
import '../services/cloud_sync_consent_repository.dart';
import '../services/cloud_manual_sync_service.dart';
import 'cloud_sync_consent_summary.dart';

enum _CloudConsentChoice { enableProgress, keepLocal, manageCategories }

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
      if (needsChoice && state.ownerId != null && !_scheduled && !_saving) {
        _scheduled = true;
        final ownerId = state.ownerId!;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _presentChoice(ownerId),
        );
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

  void _closeChoice(BuildContext sheetContext, _CloudConsentChoice choice) {
    if (sheetContext.mounted &&
        ModalRoute.of(sheetContext)?.isCurrent == true) {
      Navigator.of(sheetContext).pop(choice);
    }
  }

  Future<void> _presentChoice(String ownerId) async {
    if (!mounted || _saving || _observedOwnerId != ownerId) return;
    setState(() => _saving = true);
    var refreshRecordedChoice = false;
    bool Function()? ownerStillCurrent;
    try {
      final repository = ref.read(cloudSyncConsentRepositoryProvider);
      final completed = await repository.runForOwner(
        ownerId: ownerId,
        isCurrentOwner: () => mounted,
        action: (operation) async {
          // Capture this repository's client, including an injected test client.
          // Post-operation refresh is presentation only, with a current-owner
          // check; it never reuses the retired operation as read authority.
          final client = operation.client;
          ownerStillCurrent = () => client.auth.currentUser?.id == ownerId;
          final choice = await showBilPearlBottomSheet<_CloudConsentChoice>(
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
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 18),
                      const CloudSyncConsentSummary(),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('cloud-sync-manage-categories'),
                        onPressed: () => _closeChoice(
                          sheetContext,
                          _CloudConsentChoice.manageCategories,
                        ),
                        child: Text(
                          sheetContext.strings.text(
                            CloudSyncConsentCopy.manageCategoriesAction,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        key: const Key('cloud-sync-enable-backup'),
                        onPressed: () => _closeChoice(
                          sheetContext,
                          _CloudConsentChoice.enableProgress,
                        ),
                        child: Text(
                          sheetContext.strings.text(
                            CloudSyncConsentCopy.primaryAction,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('cloud-sync-keep-local'),
                        onPressed: () => _closeChoice(
                          sheetContext,
                          _CloudConsentChoice.keepLocal,
                        ),
                        child: Text(
                          sheetContext.strings.text(
                            CloudSyncConsentCopy.localAction,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          operation.check();
          if (choice == null) return;
          if (choice == _CloudConsentChoice.manageCategories) {
            // Discovering categories records no choice and starts no sync.
            if (!mounted) return;
            await context.push('/settings/sharing-privacy');
            operation.check();
            return;
          }
          final enable = choice == _CloudConsentChoice.enableProgress;
          await repository.setGranted(enable);
          operation.check();
          refreshRecordedChoice = true;
          if (enable) {
            // The explicit choice below already starts the first sync. Mark
            // its captured owner so invalidation does not start a duplicate.
            _autoSyncedOwnerId = ownerId;
            final result = await _runManualSyncWhileObserved();
            operation.check();
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
        },
      );
      if (!completed) {
        _scheduled = false;
        refreshRecordedChoice = false;
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
      if (mounted) {
        // Riverpod schedules its refresh in the invalidating caller's Zone.
        // Run it only after runForOwner has settled back in this caller, so a
        // retired dialog operation cannot own the subsequent consent read.
        // A recorded choice still refreshes if its explicit sync later fails.
        if (refreshRecordedChoice &&
            _observedOwnerId == ownerId &&
            ownerStillCurrent?.call() == true) {
          ref.invalidate(cloudSyncConsentStateProvider);
          ref.invalidate(cloudRuntimePreparationProvider);
        }
        setState(() => _saving = false);
      }
    }
  }

  Future<CloudManualSyncResult> _runManualSyncWhileObserved() async {
    // A read-only notifier access does not retain an autoDispose provider
    // across hydrate(). Observe only for this run, without starting a poll.
    final observation = ref.listenManual(
      cloudManualSyncStatusProvider,
      (_, _) {},
    );
    try {
      return await ref.read(cloudManualSyncStatusProvider.notifier).runOnce();
    } finally {
      observation.close();
    }
  }

  Future<void> _runPreviouslyConsentedSync(String ownerId) async {
    if (!mounted || _saving || _observedOwnerId != ownerId) return;
    try {
      await _runManualSyncWhileObserved();
    } on Object {
      // Existing consent must never make the dashboard unusable. The manual
      // Sync now row remains the explicit recovery path for a failed retry.
    }
  }
}
