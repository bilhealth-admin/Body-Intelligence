import 'package:flutter/material.dart';

/// White glass presentation for posts, without pearl or chromatic gradients.
class CommunityPostSurface extends StatelessWidget {
  const CommunityPostSurface({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF222222) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highContrast
              ? (dark ? Colors.white : const Color(0xFF555555))
              : (dark ? const Color(0xFF464646) : const Color(0xFFE7E7E7)),
        ),
        boxShadow: highContrast
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .12 : .035),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}
