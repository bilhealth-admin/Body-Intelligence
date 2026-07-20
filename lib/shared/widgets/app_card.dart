import 'package:flutter/material.dart';

import 'premium_surface.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) =>
      PremiumSurface(padding: padding, onTap: onTap, child: child);
}
