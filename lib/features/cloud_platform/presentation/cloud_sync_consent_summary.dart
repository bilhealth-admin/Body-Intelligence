import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/runtime_copy_cloud_sync.dart';

/// Shared, scannable explanation used by first-run consent and Settings.
///
/// The three benefits deliberately describe only the selective encrypted
/// backup implemented by BIL: profile, weight, and water. Meal and nutrition
/// records remain private and fast on the current device.
class CloudSyncConsentSummary extends StatelessWidget {
  const CloudSyncConsentSummary({super.key, this.showDeletionControl = false});

  final bool showDeletionControl;

  @override
  Widget build(BuildContext context) {
    final smallStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.35,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConsentBenefitRow(
          key: const Key('cloud-sync-benefit-restore'),
          icon: Icons.restore_rounded,
          text: context.strings.text(CloudSyncConsentCopy.restoreBenefit),
        ),
        const SizedBox(height: 12),
        _ConsentBenefitRow(
          key: const Key('cloud-sync-benefit-continuity'),
          icon: Icons.devices_rounded,
          text: context.strings.text(CloudSyncConsentCopy.continuityBenefit),
        ),
        const SizedBox(height: 12),
        _ConsentBenefitRow(
          key: const Key('cloud-sync-benefit-privacy'),
          icon: Icons.lock_rounded,
          text: context.strings.text(CloudSyncConsentCopy.privacyBenefit),
        ),
        const SizedBox(height: 14),
        Text(
          context.strings.text(CloudSyncConsentCopy.localNutrition),
          key: const Key('cloud-sync-local-nutrition'),
          style: smallStyle,
        ),
        const SizedBox(height: 6),
        Text(
          context.strings.text(CloudSyncConsentCopy.choiceControl),
          key: const Key('cloud-sync-choice-control'),
          style: smallStyle,
        ),
        if (showDeletionControl) ...[
          const SizedBox(height: 6),
          Text(
            context.strings.text(CloudSyncConsentCopy.deletionControl),
            key: const Key('cloud-sync-deletion-control'),
            style: smallStyle,
          ),
        ],
      ],
    );
  }
}

class _ConsentBenefitRow extends StatelessWidget {
  const _ConsentBenefitRow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: colors.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
