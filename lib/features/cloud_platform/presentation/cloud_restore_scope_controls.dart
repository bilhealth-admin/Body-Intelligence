import '../../../shared/widgets/bil_pearl_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/runtime_copy_cloud_restore.dart';
import '../providers/cloud_restore_providers.dart';
import '../services/cloud_restore_consent_repository.dart';

/// Separate, discoverable choices; changing them never starts a sync itself.
class CloudRestoreScopeControls extends ConsumerStatefulWidget {
  const CloudRestoreScopeControls({super.key});

  @override
  ConsumerState<CloudRestoreScopeControls> createState() =>
      _CloudRestoreScopeControlsState();
}

class _CloudRestoreScopeControlsState
    extends ConsumerState<CloudRestoreScopeControls> {
  bool _saving = false;
  bool _confirming = false;
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(cloudRestoreConsentStateProvider);
    final state = asyncState.value;
    String? status;
    if (asyncState.isLoading) {
      status = CloudRestoreCopy.checking;
    } else {
      status = switch (state?.availability) {
        CloudRestoreConsentAvailability.available => null,
        CloudRestoreConsentAvailability.baseConsentRequired =>
          CloudRestoreCopy.baseRequired,
        CloudRestoreConsentAvailability.signedOut => CloudRestoreCopy.signIn,
        _ => CloudRestoreCopy.unavailable,
      };
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final scope in CloudRestoreScope.values)
          SwitchListTile.adaptive(
            key: Key('cloud-restore-${scope.name}-consent'),
            title: Text(CloudRestoreCopy.text(context, _title(scope))),
            subtitle: Text(
              CloudRestoreCopy.text(context, status ?? _details(scope)),
            ),
            value: state?.grantedScopes.contains(scope) ?? false,
            onChanged:
                !_saving && !_confirming && state?.canChange(scope) == true
                ? (granted) => _change(scope, granted, state!)
                : null,
          ),
        if (_saving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(),
          ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              liveRegion: true,
              child: Text(
                CloudRestoreCopy.text(context, CloudRestoreCopy.failed),
              ),
            ),
          ),
        if (state?.availability == CloudRestoreConsentAvailability.unavailable)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('cloud-restore-refresh'),
              onPressed: _saving || _confirming
                  ? null
                  : () => ref.invalidate(cloudRestoreConsentStateProvider),
              child: Text(
                CloudRestoreCopy.text(context, CloudRestoreCopy.retry),
              ),
            ),
          ),
      ],
    );
  }

  String _title(CloudRestoreScope scope) => scope == CloudRestoreScope.nutrition
      ? CloudRestoreCopy.nutrition
      : CloudRestoreCopy.goals;

  String _details(CloudRestoreScope scope) =>
      scope == CloudRestoreScope.nutrition
      ? CloudRestoreCopy.nutritionDetails
      : CloudRestoreCopy.goalsDetails;

  Future<void> _change(
    CloudRestoreScope scope,
    bool granted,
    CloudRestoreConsentState state,
  ) async {
    if (_saving || _confirming) return;
    setState(() {
      _confirming = granted;
      _saving = !granted;
      _failed = false;
    });
    try {
      final repository = ref.read(cloudRestoreConsentRepositoryProvider);
      final session = repository.captureLease(state);
      if (granted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => BilPearlMaterialAlertDialog(
            title: Text(CloudRestoreCopy.text(context, _title(scope))),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(CloudRestoreCopy.text(context, _details(scope))),
                const SizedBox(height: 16),
                Text(CloudRestoreCopy.text(context, CloudRestoreCopy.choice)),
                const SizedBox(height: 12),
                Text(CloudRestoreCopy.text(context, CloudRestoreCopy.disable)),
              ],
            ),
            actionsOverflowDirection: VerticalDirection.down,
            actions: [
              TextButton(
                key: const Key('cloud-restore-consent-cancel'),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  CloudRestoreCopy.text(context, CloudRestoreCopy.cancel),
                ),
              ),
              FilledButton(
                key: const Key('cloud-restore-consent-confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  CloudRestoreCopy.text(context, CloudRestoreCopy.confirm),
                ),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        setState(() {
          _confirming = false;
          _saving = true;
        });
      }
      await repository.setGranted(scope, granted, expectedSession: session);
      if (mounted) ref.invalidate(cloudRestoreConsentStateProvider);
    } on Object {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _confirming = false;
        });
      }
    }
  }
}
