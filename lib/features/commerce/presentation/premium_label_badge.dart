import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';

/// A compact, text-first Premium marker for locked collection items.
///
/// It deliberately avoids lock/crown imagery so a paid item remains visually
/// calm and the marker does not imply that an entire free collection is
/// unavailable.
class PremiumLabelBadge extends StatelessWidget {
  const PremiumLabelBadge({super.key, this.semanticLabel, this.large = false});

  final String? semanticLabel;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final strings = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final label = semanticLabel ?? strings?.text('Premium') ?? 'Premium';
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.surface, scheme.surfaceContainerLow],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'BILDisplay',
                fontFamilyFallback: const ['BILArabic'],
                color: scheme.onSurface,
                fontSize: large ? 16 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
