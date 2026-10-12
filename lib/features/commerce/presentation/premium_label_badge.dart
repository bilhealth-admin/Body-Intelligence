import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';

/// A compact, text-first Premium marker for locked collection items.
///
/// It deliberately avoids lock/crown imagery so a paid item remains visually
/// calm and the marker does not imply that an entire free collection is
/// unavailable.
class PremiumLabelBadge extends StatelessWidget {
  const PremiumLabelBadge({
    super.key,
    this.semanticLabel,
    this.large = false,
    this.onTap,
  });

  final String? semanticLabel;
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final strings = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final label = semanticLabel ?? strings?.text('Premium') ?? 'Premium';
    final highContrast = MediaQuery.highContrastOf(context);
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: highContrast ? const Color(0xFFFFD977) : null,
        gradient: highContrast
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE1B04A),
                  Color(0xFFFFE7A5),
                  Color(0xFFF2C45E),
                  Color(0xFFFFF0CA),
                  Color(0xFFE8BB55),
                ],
                stops: [0, .26, .48, .56, 1],
              ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highContrast
              ? const Color(0xFF342309)
              : const Color(0xFFB3852E),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'BILDisplay',
            fontFamilyFallback: const ['BILArabic'],
            color: const Color(0xFF342309),
            fontSize: large ? 16 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Center(widthFactor: 1, child: content),
          ),
        ),
      );
    }
    return Semantics(
      label: label,
      button: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(child: content),
    );
  }
}
