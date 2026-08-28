import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';

/// A compact, text-first Premium marker for locked collection items.
///
/// It deliberately avoids lock/crown imagery so a paid item remains visually
/// calm and the marker does not imply that an entire free collection is
/// unavailable.
class PremiumLabelBadge extends StatelessWidget {
  const PremiumLabelBadge({super.key, this.semanticLabel});

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel ?? context.strings.text('Premium'),
    child: ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE7A0), Color(0xFFF4C451)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFF8D878)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2ED69B27),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            context.strings.text('Premium'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF332300),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
            ),
          ),
        ),
      ),
    ),
  );
}
