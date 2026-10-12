import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Presentation only. No motion, consent, navigation or persistence ownership.
abstract final class BilPearlFinish {
  static const lightCanvas = Color(0xFFF0F5FA);
  static const lightSurface = Color(0xFFFCFDFE);
  static const lightInset = Color(0xFFE8F0F7);
  static const lightInk = Color(0xFF172A3A);
  static const lightSecondary = Color(0xFF4F6274);
  static const lightEdge = Color(0xFFC4D3E0);
  static const darkCanvas = Color(0xFF101B28);
  static const darkSurface = Color(0xFF1A2B3B);
  static const darkInset = Color(0xFF22384A);
  static const darkInk = Color(0xFFE3ECF4);
  static const darkSecondary = Color(0xFFB5C8D8);
  static const darkEdge = Color(0xFF526B80);

  static LinearGradient background(BuildContext context) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: const [0, .48, 1],
    colors: Theme.of(context).brightness == Brightness.dark
        ? const [Color(0xFF21384C), darkCanvas, Color(0xFF142B3A)]
        : const [Color(0xFFFBFDFF), lightCanvas, Color(0xFFE0ECF6)],
  );

  static BoxDecoration panel(
    BuildContext context, {
    BorderRadius radius = const BorderRadius.all(Radius.circular(20)),
    bool translucent = false,
    bool shadow = true,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final contrast = MediaQuery.highContrastOf(context);
    final alpha = translucent && !contrast ? .94 : 1.0;
    return BoxDecoration(
      borderRadius: radius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0, .44, 1],
        colors:
            (dark
                    ? const [Color(0xFF30485C), darkSurface, Color(0xFF203545)]
                    : const [Colors.white, lightSurface, Color(0xFFEBF3FA)])
                .map((color) => color.withValues(alpha: alpha))
                .toList(),
      ),
      border: Border.all(
        color: contrast
            ? Theme.of(context).colorScheme.onSurface
            : (dark ? darkEdge : lightEdge),
        width: contrast ? 1.5 : .8,
      ),
      boxShadow: shadow && !contrast
          ? [
              BoxShadow(
                color: Color(dark ? 0x3306111C : 0x14223F58),
                blurRadius: 24,
                spreadRadius: -8,
                offset: const Offset(0, 10),
              ),
            ]
          : const [],
    );
  }
}

/// Opaque pearl backdrop: underlying route text never bleeds into page content.
class BilPearlBackdrop extends StatelessWidget {
  const BilPearlBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: BilPearlFinish.background(context)),
    child: child,
  );
}

/// List/card elevation without allocating a backdrop filter per scrolling row.
class BilPearlCard extends StatelessWidget {
  const BilPearlCard({super.key, required this.child, this.margin});
  final Widget child;
  final EdgeInsetsGeometry? margin;
  @override
  Widget build(BuildContext context) => Container(
    margin:
        margin ??
        Theme.of(context).cardTheme.margin ??
        const EdgeInsets.symmetric(vertical: 4),
    decoration: BilPearlFinish.panel(context),
    child: Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
}

/// Bounded frost for overlay roots, not for every row of a scrolling feed.
/// A 94% tint plus 16px frost obscures underlying text; high contrast is opaque.
class BilFrostedPanel extends StatelessWidget {
  const BilFrostedPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = const BorderRadius.all(Radius.circular(24)),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  @override
  Widget build(BuildContext context) {
    final contrast = MediaQuery.highContrastOf(context);
    final surface = DecoratedBox(
      decoration: BilPearlFinish.panel(
        context,
        radius: radius,
        translucent: true,
        shadow: false,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
    );
    return ClipRRect(
      borderRadius: radius,
      child: contrast
          ? surface
          : BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: surface,
            ),
    );
  }
}
