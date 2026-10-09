import 'package:flutter/material.dart';

import 'bil_semantic_icons.dart';

/// Flat icons for BIL surfaces outside the protected Home and Log Food pages.
///
/// Keeps a stable layout box and uses synchronous Cupertino/Material fallbacks.
/// No colored badge, gradient, shader, elevation, shadow, network or animation.
/// Protected screens keep their existing BilSemanticIconBadge presentation.
class BilFlatIcon extends StatelessWidget {
  const BilFlatIcon({
    super.key,
    required this.kind,
    this.semanticLabel,
    this.size = 40,
    this.iconSize = 22,
    this.color,
    this.materialIcon,
    this.appleIcon,
  }) : assert(size > 0),
       assert(iconSize > 0);

  final BilSemanticIconKind kind;
  final String? semanticLabel;
  final double size;
  final double iconSize;
  final Color? color;
  final IconData? materialIcon;
  final IconData? appleIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = BilSemanticIcons.spec(kind);
    final glyph = switch (theme.platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => appleIcon ?? spec.appleIcon,
      _ => materialIcon ?? spec.icon,
    };
    final visual = SizedBox.square(
      dimension: size,
      child: Center(
        child: ExcludeSemantics(
          child: Icon(
            glyph,
            size: iconSize,
            color: color ?? spec.accent(theme.brightness),
          ),
        ),
      ),
    );
    final label = semanticLabel?.trim();
    if (label == null || label.isEmpty) return visual;
    return Semantics(label: label, image: true, child: visual);
  }
}
