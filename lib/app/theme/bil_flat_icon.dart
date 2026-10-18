import 'package:flutter/material.dart';

import 'bil_semantic_icons.dart';

/// Flat semantic symbols shared with More and all functional entry points.
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
    final visual = BilSemanticIconBadge(
      kind: kind,
      size: size,
      iconSize: iconSize,
      iconOverride: materialIcon,
      appleIconOverride: appleIcon,
      colorOverride: color,
    );
    final label = semanticLabel?.trim();
    if (label == null || label.isEmpty) return visual;
    return Semantics(label: label, image: true, child: visual);
  }
}
