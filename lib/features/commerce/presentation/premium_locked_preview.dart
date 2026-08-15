import 'dart:ui';

import 'package:flutter/material.dart';

enum BilPaidContentTier { premium, premiumAiCoach }

/// Unified visual preview. Authorization must come from trusted server/store
/// state. The full payload builder is never invoked while access is denied.
class PremiumLockedPreview extends StatelessWidget {
  const PremiumLockedPreview({
    required this.requiredTier,
    required this.hasEntitlement,
    required this.preview,
    required this.fullContentBuilder,
    required this.lockedTitle,
    required this.upgradeLabel,
    required this.onUpgrade,
    super.key,
  });

  final BilPaidContentTier requiredTier;
  final bool hasEntitlement;
  final Widget preview;
  final WidgetBuilder fullContentBuilder;
  final String lockedTitle;
  final String upgradeLabel;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    if (hasEntitlement) return fullContentBuilder(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: IgnorePointer(child: preview),
          ),
        ),
        Semantics(
          container: true,
          label: lockedTitle,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded),
                  const SizedBox(height: 8),
                  Text(lockedTitle, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: onUpgrade, child: Text(upgradeLabel)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
